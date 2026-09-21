import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/monitor_settings.dart';
import '../../../domain/tuning/scale_config.dart';
import '../../core/app_theme.dart';
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

class _PitchHistoryGraph extends StatelessWidget {
  const _PitchHistoryGraph({required this.controller});
  final MonitorController controller;
  @override
  Widget build(BuildContext context) {
    final scale = controller.scale;
    if (scale == null) return const Center(child: CircularProgressIndicator());
    return Semantics(
      label: '音高历史图。当前${controller.note?.label ?? '无音高'}。纵轴为调律音名，横轴为时间。',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: AppColors.surface,
          child: Stack(
            children: [
              Positioned.fill(
                child: PitchRangeGesture(
                  controller: controller,
                  baseRange: 2400,
                  plotPadding: const EdgeInsets.only(top: 16, bottom: 28),
                  builder: (context, interacting) => CustomPaint(
                    painter: _HistoryPainter(
                      scale: scale,
                      settings: controller.settings,
                      history: controller.history,
                      time: controller.graphTime,
                      seconds: controller.graphSeconds,
                      center: controller.centerCents,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.held) const _Badge('已冻结'),
                    if (!controller.settings.autoScroll) ...[
                      IconButton.filledTonal(
                        tooltip: '恢复自动跟随音域',
                        onPressed: () =>
                            controller.updateSetting('autoScroll', true),
                        icon: const Icon(Icons.my_location),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        tooltip: '音域上移',
                        onPressed: () => controller.panRange(300),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        tooltip: '音域下移',
                        onPressed: () => controller.panRange(-300),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ],
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
    required this.center,
  });
  final ScaleConfig scale;
  final MonitorSettings settings;
  final List<PitchPoint> history;
  final double time, seconds, center;
  void label(
    Canvas canvas,
    String value,
    Offset offset,
    Color color, {
    double size = 12,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: size, fontFamily: 'monospace'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final range = 2400 / settings.verticalZoom;
    final min = center - range / 2, max = center + range / 2;
    final notes = visibleScaleNotes(scale, min, max);
    var left = 48.0;
    for (final note in notes) {
      final text = TextPainter(
        text: TextSpan(text: note.label, style: const TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      left = math.max(left, text.width + 20);
    }
    left = math.min(left, size.width * .32);
    final plot = Rect.fromLTRB(left, 16, size.width - 16, size.height - 28);
    if (plot.width <= 0 || plot.height <= 0) return;
    double y(double cents) => plot.bottom - (cents - min) / range * plot.height;
    for (final note in notes) {
      final gray = scale.colorFor(note.index);
      final lineColor = Color(gray).withValues(alpha: .58);
      canvas.drawLine(
        Offset(plot.left, y(note.cents)),
        Offset(plot.right, y(note.cents)),
        Paint()
          ..color = lineColor
          ..strokeWidth = .7,
      );
      label(canvas, note.label, Offset(10, y(note.cents) - 7), Color(gray));
    }
    canvas.drawLine(
      Offset(plot.left, 0),
      Offset(plot.left, plot.bottom),
      Paint()..color = AppColors.line,
    );
    for (var step = 0; step <= 4; step++) {
      final x = plot.left + plot.width * step / 4;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()..color = AppColors.line.withValues(alpha: .4),
      );
      label(
        canvas,
        '${((step / 4 - 1) * seconds).round()}s',
        Offset(x - 10, plot.bottom + 8),
        AppColors.muted,
        size: 10,
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
      if (point.seconds < time - seconds) continue;
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
    label: '偏差 ${controller.deviation.toStringAsFixed(1)} 音分',
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
