import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../domain/audio/log_spectrum.dart';
import '../../../domain/audio/pitch_analyzer.dart';
import '../../../domain/models/monitor_settings.dart';
import '../../../domain/tuning/scale_config.dart';
import '../../core/app_theme.dart';
import 'monitor_controller.dart';
import 'pitch_range_gesture.dart';
import 'scale_grid.dart';
import 'spectrum_palette.dart';

class SpectrumGraph extends StatefulWidget {
  const SpectrumGraph({super.key, required this.controller});
  final MonitorController controller;

  @override
  State<SpectrumGraph> createState() => _SpectrumGraphState();
}

class _SpectrumGraphState extends State<SpectrumGraph> {
  final Map<int, _SpectrumTile> _tiles = {};

  @override
  void initState() {
    super.initState();
    _syncTiles();
  }

  @override
  void didUpdateWidget(covariant SpectrumGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      for (final tile in _tiles.values) {
        tile.dispose();
      }
      _tiles.clear();
    }
    _syncTiles();
  }

  void _syncTiles() {
    final groups = <int, List<SpectrumPoint>>{};
    for (final point in widget.controller.spectra) {
      final key = point.sequence ~/ _SpectrumTile.columns;
      (groups[key] ??= []).add(point);
    }
    for (final key in _tiles.keys.toList()) {
      if (!groups.containsKey(key)) _tiles.remove(key)!.dispose();
    }
    for (final entry in groups.entries) {
      final tile = _tiles.putIfAbsent(entry.key, _SpectrumTile.new);
      tile.update(entry.value, () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (final tile in _tiles.values) {
      tile.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final scale = controller.scale;
    if (scale == null) return const Center(child: CircularProgressIndicator());
    // Keep sampling and label widths anchored while the viewport moves.
    final notes = visibleScaleNotes(
      scale,
      LogSpectrum.minCents,
      LogSpectrum.maxCents,
    );
    return Semantics(
      label:
          'FFT 滚动频谱。纵轴为对数频率，以${scale.name}音高名标注，每个八度等高。'
          '横轴为时间，颜色从暗蓝到橙黄到白表示负90至0 dBFS。',
      child: ColoredBox(
        color: SpectrumPalette.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 4,
                children: [
                  const Text(
                    'FFT · 音高 / log₂',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  Semantics(
                    label: '频谱强度：负90至0 dBFS',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('−90', style: TextStyle(fontSize: 12)),
                        Container(
                          width: 72,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: const BoxDecoration(
                            gradient: SpectrumPalette.gradient,
                          ),
                        ),
                        const Text('0 dBFS', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final range =
                      (LogSpectrum.maxCents / controller.settings.verticalZoom)
                          .clamp(0.0, LogSpectrum.maxCents);
                  final min = (controller.centerCents - range / 2).clamp(
                    LogSpectrum.minCents,
                    LogSpectrum.maxCents - range,
                  );
                  final target = RangeValues(min, min + range);
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: PitchRangeGesture(
                          controller: controller,
                          baseRange: LogSpectrum.maxCents,
                          minCents: LogSpectrum.minCents,
                          maxCents: LogSpectrum.maxCents,
                          plotPadding: EdgeInsets.only(
                            top:
                                MediaQuery.textScalerOf(context).scale(12) *
                                    1.3 /
                                    2 +
                                4,
                            bottom:
                                MediaQuery.textScalerOf(context).scale(12) *
                                    1.3 +
                                12,
                          ),
                          builder: (context, interacting) => RepaintBoundary(
                            child: TweenAnimationBuilder<RangeValues>(
                              tween: _SpectrumRangeTween(
                                begin: target,
                                end: target,
                              ),
                              duration:
                                  interacting ||
                                      MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              builder: (context, viewport, _) => CustomPaint(
                                painter: _SpectrumPainter(
                                  tiles: _tiles.values.toList(),
                                  notes: notes,
                                  settings: controller.settings,
                                  time: controller.graphTime,
                                  seconds: controller.graphSeconds,
                                  viewport: viewport,
                                  textScaler: MediaQuery.textScalerOf(context),
                                  labelStyle: Theme.of(context)
                                      .textTheme
                                      .labelSmall!,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (controller.spectra.isEmpty)
                        const IgnorePointer(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(64, 24, 24, 24),
                              child: Text(
                                '开始监听，观察基频与泛音\n每个八度等高 · 亮度表示强度',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  height: 1.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (controller.held) const Chip(label: Text('已冻结')),
                            if (!controller.settings.autoScroll) ...[
                              IconButton.filledTonal(
                                tooltip: '恢复自动跟随音域',
                                onPressed: () => controller.updateSetting(
                                  'autoScroll',
                                  true,
                                ),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpectrumRangeTween extends Tween<RangeValues> {
  _SpectrumRangeTween({required RangeValues begin, required RangeValues end})
    : super(begin: begin, end: end);

  @override
  RangeValues lerp(double t) => RangeValues(
    ui.lerpDouble(begin!.start, end!.start, t)!,
    ui.lerpDouble(begin!.end, end!.end, t)!,
  );
}

/// Cache small raster strips: only the unfinished strip is encoded per frame.
/// Completed strips are reused for scrolling, zooming and tuning changes.
class _SpectrumTile {
  static const columns = 32;
  ui.Image? image;
  List<SpectrumPoint> frames = [];
  SpectrumPoint? _lastRequested;
  int _version = 0;
  bool _disposed = false;

  void update(List<SpectrumPoint> points, VoidCallback repaint) {
    if (identical(_lastRequested, points.last)) return;
    _lastRequested = points.last;
    final version = ++_version;
    final pixels = Uint8List(columns * LogSpectrum.bands * 4);
    for (var x = 0; x < points.length; x++) {
      final bands = points[x].bands;
      for (var row = 0; row < LogSpectrum.bands; row++) {
        final color = SpectrumPalette.rgba[bands[row]];
        final offset = ((LogSpectrum.bands - 1 - row) * columns + x) * 4;
        pixels[offset] = (color >> 16) & 255;
        pixels[offset + 1] = (color >> 8) & 255;
        pixels[offset + 2] = color & 255;
        pixels[offset + 3] = 255;
      }
    }
    ui.decodeImageFromPixels(
      pixels,
      columns,
      LogSpectrum.bands,
      ui.PixelFormat.rgba8888,
      (next) {
        if (_disposed || version != _version) {
          next.dispose();
          return;
        }
        image?.dispose();
        image = next;
        frames = points;
        repaint();
      },
    );
  }

  void dispose() {
    _disposed = true;
    image?.dispose();
    image = null;
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({
    required this.tiles,
    required this.notes,
    required this.settings,
    required this.time,
    required this.seconds,
    required this.viewport,
    required this.textScaler,
    required this.labelStyle,
  });
  final List<_SpectrumTile> tiles;
  final List<ScaleNote> notes;
  final MonitorSettings settings;
  final double time, seconds;
  final RangeValues viewport;
  final TextScaler textScaler;
  final TextStyle labelStyle;

  TextPainter _text(String value, {Color color = AppColors.muted}) =>
      TextPainter(
        text: TextSpan(
          text: value,
          style: labelStyle.copyWith(color: color, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
        ellipsis: '…',
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Use the same animated bounds for the raster crop and the tuning grid.
    final min = viewport.start, max = viewport.end;
    final range = max - min;
    final labelHeight = textScaler.scale(12) * 1.3;
    var left = 42.0;
    for (final note in notes) {
      final text = _text(note.label)..layout();
      left = math.max(left, text.width + 16);
    }
    left = math.min(left, size.width * .3);
    final plot = Rect.fromLTRB(
      left,
      labelHeight / 2 + 4,
      size.width - 12,
      size.height - labelHeight - 12,
    );
    if (plot.width <= 0 || plot.height <= 0) return;
    double y(double cents) => plot.bottom - (cents - min) / range * plot.height;
    double x(double at) => plot.right - (time - at) / seconds * plot.width;

    canvas.save();
    canvas.clipRect(plot);
    canvas.drawRect(plot, Paint()..color = SpectrumPalette.colors.first);
    const interval = PitchAnalyzer.intervalSeconds;
    final imagePaint = Paint()..filterQuality = FilterQuality.low;
    for (final tile in tiles) {
      final image = tile.image;
      final frames = tile.frames;
      if (image == null ||
          frames.isEmpty ||
          frames.last.seconds < time - seconds ||
          frames.first.seconds - interval > time) {
        continue;
      }
      // Split at source-time gaps so dropped audio is never stretched into data.
      var start = 0;
      for (var end = 1; end <= frames.length; end++) {
        if (end < frames.length &&
            (frames[end].seconds - frames[end - 1].seconds - interval).abs() <
                .0001) {
          continue;
        }
        canvas.drawImageRect(
          image,
          Rect.fromLTRB(
            start.toDouble(),
            (LogSpectrum.maxCents - max) / LogSpectrum.centsPerBand,
            end.toDouble(),
            (LogSpectrum.maxCents - min) / LogSpectrum.centsPerBand,
          ),
          Rect.fromLTRB(
            x(frames[start].seconds - interval),
            plot.top,
            x(frames[end - 1].seconds),
            plot.bottom,
          ),
          imagePaint,
        );
        start = end;
      }
    }
    if (settings.showBeats) {
      final interval = 60 / settings.bpm;
      final start = ((time - seconds) / interval).ceil();
      final end = (time / interval).floor();
      for (var beat = start; beat <= end && beat < start + 1000; beat++) {
        final accented =
            settings.beatsPerBar != 0 && beat % settings.beatsPerBar == 0;
        canvas.drawLine(
          Offset(x(beat * interval), plot.top),
          Offset(x(beat * interval), plot.bottom),
          Paint()
            ..color = Color(settings.beatColor)
                .withValues(alpha: accented ? .6 : .3),
        );
      }
    }
    canvas.restore();

    // Cull labels from a fixed spectrum-wide anchor before clipping, so a note
    // crossing the viewport edge cannot reshuffle the remaining labels.
    var lastLabelY = double.negativeInfinity;
    for (final note in notes.reversed) {
      final yy = y(note.cents);
      final showLabel = yy - lastLabelY >= labelHeight + 5;
      if (showLabel) lastLabelY = yy;
      if (note.cents < min || note.cents > max) continue;
      canvas.drawLine(
        Offset(plot.left, yy),
        Offset(plot.right, yy),
        Paint()
          ..color = AppColors.muted.withValues(alpha: .16)
          ..strokeWidth = .6,
      );
      if (!showLabel) continue;
      final text = _text(note.label)..layout(maxWidth: math.max(1, left - 12));
      text.paint(
        canvas,
        Offset(plot.left - text.width - 8, yy - text.height / 2),
      );
    }
    for (var step = 0; step <= 4; step++) {
      final value = step == 4
          ? '0 s'
          : '−${((1 - step / 4) * seconds).toStringAsFixed(1)}';
      final text = _text(value)..layout();
      final xx = plot.left + plot.width * step / 4;
      text.paint(
        canvas,
        Offset(
          (xx - text.width / 2).clamp(
            0.0,
            math.max(0, size.width - text.width),
          ),
          plot.bottom + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) => true;
}
