import 'package:flutter/material.dart';

/// File labels show elapsed time instead of time relative to live input.
String recordingTimeLabel(double seconds) {
  final digits = seconds.abs() < 1 && seconds != 0 ? 2 : 1;
  return '${seconds.toStringAsFixed(digits)} s';
}

void drawPlaybackCursor(
  Canvas canvas,
  Rect plot, {
  required double? position,
  required double duration,
}) {
  if (position == null || duration <= 0) return;
  final x = plot.left + (position / duration).clamp(0.0, 1.0) * plot.width;
  // A dark outline keeps the cursor readable over bright FFT harmonics.
  for (final (color, width) in [(Colors.black, 3.0), (Colors.white, 1.0)]) {
    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }
}
