import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/monitor_settings.dart';
import '../../../domain/tuning/scale_config.dart';
import '../../../l10n/l10n.dart';
import '../../core/app_theme.dart';
import 'graph_watermarks.dart';
import 'graph_timeline.dart';
import 'monitor_controller.dart';
import 'pitch_range_gesture.dart';
import 'spectrum_graph.dart';
import 'scale_grid.dart';

class PitchGraph extends StatelessWidget {
  const PitchGraph({super.key, required this.controller});
  final MonitorController controller;
  @override
  Widget build(BuildContext context) => controller.settings.showSpectrum
      ? SpectrumGraph(controller: controller)
      : _PitchHistoryGraph(controller: controller);
}

class _PitchHistoryGraph extends StatefulWidget {
  const _PitchHistoryGraph({required this.controller});
  final MonitorController controller;

  @override
  State<_PitchHistoryGraph> createState() => _PitchHistoryGraphState();
}

class _PitchHistoryGraphState extends State<_PitchHistoryGraph> {
  RangeValues? _paintedViewport;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final scale = controller.scale;
    if (scale == null) return const Center(child: CircularProgressIndicator());
    final target = RangeValues(
      controller.centerCents - controller.historyRange / 2,
      controller.centerCents + controller.historyRange / 2,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final padding = EdgeInsets.only(
      // Keep moving scale labels below the tuning and tempo watermark.
      top: 24 + textScaler.scale(12) * 1.9,
      bottom: math.max(28, textScaler.scale(10) + 16),
    );
    return Semantics(
      label: context.l10n.graphPitchHistoryDescription(
        controller.note?.label ?? context.l10n.graphNoPitch,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: AppColors.surface,
          child: Stack(
            children: [
              Positioned.fill(
                child: PitchRangeGesture(
                  controller: controller,
                  baseRange: controller.historyBaseRange,
                  visibleViewport: () => _paintedViewport ?? target,
                  plotPadding: padding,
                  builder: (context, interacting) => RepaintBoundary(
                    child: TweenAnimationBuilder<RangeValues>(
                      tween: PitchRangeTween(begin: target, end: target),
                      duration:
                          interacting ||
                              !controller.settings.autoScroll ||
                              controller.held ||
                              MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      builder: (context, viewport, _) {
                        _paintedViewport = viewport;
                        return CustomPaint(
                          painter: _HistoryPainter(
                            scale: scale,
                            settings: controller.settings,
                            history: controller.history,
                            time: controller.graphTime,
                            seconds: controller.graphSeconds,
                            playbackTime: controller.graphPlaybackTime,
                            viewport: viewport,
                            textScaler: textScaler,
                            padding: padding,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GraphWatermarks(
                      scaleName: scale.name,
                      bpm: controller.settings.bpm,
                    ),
                    if (controller.held)
                      IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _Badge(context.l10n.graphFrozen),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.raised,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: const TextStyle(color: AppColors.accent)),
  );
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter({
    required this.scale,
    required this.settings,
    required this.history,
    required this.time,
    required this.seconds,
    required this.playbackTime,
    required this.viewport,
    required this.textScaler,
    required this.padding,
  });
  final ScaleConfig scale;
  final MonitorSettings settings;
  final List<PitchPoint> history;
  final double time, seconds;
  final double? playbackTime;
  final RangeValues viewport;
  final TextScaler textScaler;
  final EdgeInsets padding;
  void label(
    Canvas canvas,
    String value,
    Offset offset,
    Color color, {
    double size = 12,
    double maxWidth = double.infinity,
    double? centerWithinWidth,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: size, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    text.paint(
      canvas,
      centerWithinWidth == null
          ? offset
          : Offset(
              (offset.dx - text.width / 2).clamp(
                0.0,
                math.max(0, centerWithinWidth - text.width),
              ),
              offset.dy,
            ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final min = viewport.start, max = viewport.end;
    final range = max - min;
    var lines = visibleScaleLines(scale, min, max);
    var left = 48.0;
    for (final line in lines) {
      if (line.label == null) continue;
      final text = TextPainter(
        text: TextSpan(text: line.label, style: const TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      left = math.max(left, text.width + 20);
    }
    left = math.min(left, size.width * .32);
    final plot = Rect.fromLTRB(
      left,
      padding.top,
      size.width - 16,
      size.height - padding.bottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;
    double y(double cents) => plot.bottom - (cents - min) / range * plot.height;
    final edo = scale.edo != null;
    if (edo) {
      lines = visibleScaleLines(
        scale,
        min,
        max,
        minimumCentsSpacing: range / plot.height * 4,
      );
    }
    var lastLabelY = double.negativeInfinity;
    for (final line in lines.reversed) {
      final yy = y(line.cents);
      drawScaleGridLine(canvas, plot, yy, line, edo: edo);
      if (line.label != null &&
          yy - lastLabelY >= textScaler.scale(12) * 1.3 + 5) {
        lastLabelY = yy;
        label(
          canvas,
          line.label!,
          Offset(10, yy - textScaler.scale(12) * .6),
          line.color,
          maxWidth: math.max(1, left - 18),
        );
      }
    }
    canvas.drawLine(
      Offset(plot.left, 0),
      Offset(plot.left, plot.bottom),
      Paint()..color = AppColors.line,
    );
    final timeSteps = playbackTime == null
        ? 4
        : (plot.width / (textScaler.scale(10) * 7 + 12)).floor().clamp(1, 4);
    for (var step = 0; step <= timeSteps; step++) {
      final x = plot.left + plot.width * step / timeSteps;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()..color = AppColors.line.withValues(alpha: .4),
      );
      label(
        canvas,
        playbackTime == null
            ? '${((step / timeSteps - 1) * seconds).round()}s'
            : recordingTimeLabel(step / timeSteps * seconds),
        Offset(x, plot.bottom + 8),
        AppColors.muted,
        size: 10,
        centerWithinWidth: size.width,
      );
    }
    canvas.save();
    canvas.clipRect(plot);
    if (settings.showBeats) {
      final interval = 60 / settings.bpm;
      final start = ((time - seconds) / interval).floor();
      final end = (time / interval).ceil();
      for (var i = start; i <= end && i < start + 1000; i++) {
        final x = plot.right - (time - i * interval) / seconds * plot.width;
        final accented =
            settings.beatsPerBar != 0 && i % settings.beatsPerBar == 0;
        canvas.drawLine(
          Offset(x, plot.top),
          Offset(x, plot.bottom),
          Paint()
            ..color = Color(settings.beatColor)
                .withValues(alpha: accented ? .9 : .45)
            ..strokeWidth = accented ? 1.5 : .7,
        );
      }
    }
    final path = Path();
    var connected = false;
    double? lastTime, lastCent;
    Offset? last;
    for (final point in history) {
      if (point.seconds < time - seconds || point.seconds > time) continue;
      final cents = point.cents;
      if (cents == null) {
        connected = false;
        continue;
      }
      final x = plot.right - (time - point.seconds) / seconds * plot.width;
      final yy = y(cents);
      if (!connected ||
          (lastTime != null && point.seconds - lastTime > .2) ||
          (lastCent != null && (cents - lastCent).abs() > 650)) {
        path.moveTo(x, yy);
        // A moveTo-only segment has no stroke. Retain isolated notes as dots.
        canvas.drawCircle(
          Offset(x, yy),
          1.1,
          Paint()..color = Color(settings.pitchColor),
        );
      } else {
        path.lineTo(x, yy);
      }
      last = Offset(x, yy);
      lastTime = point.seconds;
      lastCent = cents;
      connected = true;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Color(settings.pitchColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    if (connected && last != null) {
      canvas.drawCircle(last, 4, Paint()..color = Color(settings.pitchColor));
    }
    drawPlaybackCursor(canvas, plot, position: playbackTime, duration: seconds);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) => true;
}

class TunerStrip extends StatelessWidget {
  const TunerStrip({super.key, required this.controller});
  final MonitorController controller;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.graphDeviation(controller.deviation.toStringAsFixed(1)),
    child: SizedBox(
      height: controller.settings.showSpectrum ? 56 : 68,
      width: double.infinity,
      child: CustomPaint(painter: _TunerPainter(controller)),
    ),
  );
}

class _TunerPainter extends CustomPainter {
  _TunerPainter(this.controller);
  final MonitorController controller;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = controller.scale;
    if (scale == null) return;
    const halfWindow = 1200 / 7;
    final center = controller.note == null
        ? controller.centerCents
        : controller.note!.cents + controller.deviation;
    double x(double cent) =>
        size.width / 2 + (cent - center) / halfWindow * (size.width / 2 - 12);
    final notes = visibleScaleNotes(
      scale,
      center - halfWindow * 4,
      center + halfWindow * 4,
    )..sort((a, b) => a.cents.compareTo(b.cents));
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (scale.edo != null) {
      final lines = visibleScaleLines(
        scale,
        center - halfWindow,
        center + halfWindow,
        minimumCentsSpacing: 2 * halfWindow / math.max(1, size.width - 24) * 4,
      );
      var lastLabelRight = double.negativeInfinity;
      for (final line in lines) {
        final xx = x(line.cents);
        canvas.drawLine(
          Offset(xx, 36 - 24 * line.ratio),
          Offset(xx, 36),
          Paint()
            ..color = line.color.withValues(alpha: 184 / 255 * line.ratio)
            ..strokeWidth = line.isAnchor ? 1.4 : 1,
        );
        final text = TextPainter(
          text: TextSpan(
            text: scale.nearestNote(line.cents).label,
            style: TextStyle(color: line.color, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final left = xx - text.width / 2;
        if (left < lastLabelRight + 6) continue;
        text.paint(canvas, Offset(left, 43));
        lastLabelRight = left + text.width;
      }
    } else {
      for (var i = 0; i < notes.length; i++) {
        final note = notes[i];
        final xx = x(note.cents);
        canvas.drawLine(
          Offset(xx, 12),
          Offset(xx, 36),
          Paint()
            ..color = AppColors.muted
            ..strokeWidth = 1,
        );
        final text = TextPainter(
          text: TextSpan(
            text: note.label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(xx - text.width / 2, 43));
        if (i + 1 < notes.length) {
          for (var subdivision = 1; subdivision < 6; subdivision++) {
            final xx = x(
              note.cents + (notes[i + 1].cents - note.cents) * subdivision / 6,
            );
            canvas.drawLine(
              Offset(xx, 23),
              Offset(xx, 35),
              Paint()..color = AppColors.line,
            );
          }
        }
      }
    }
    final marker = Path()
      ..moveTo(size.width / 2 - 5, 2)
      ..lineTo(size.width / 2 + 5, 2)
      ..lineTo(size.width / 2, 10)
      ..close();
    canvas.drawPath(marker, Paint()..color = AppColors.accent);
    canvas.drawLine(
      Offset(size.width / 2, 12),
      Offset(size.width / 2, 36),
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TunerPainter oldDelegate) => true;
}
