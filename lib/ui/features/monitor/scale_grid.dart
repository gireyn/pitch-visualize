import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/tuning/scale_config.dart';
import '../../core/app_theme.dart';
import 'edo_scale_guide.dart';

/// A ruler mark in the monitor's C1-relative cent coordinate system.
class ScaleGridLine {
  const ScaleGridLine({
    required this.cents,
    required this.color,
    this.label,
    this.ratio = 1,
    this.isAnchor = false,
  });

  final double cents;
  final Color color;
  final String? label;
  final double ratio;
  final bool isAnchor;
}

List<ScaleGridLine> visibleScaleLines(
  ScaleConfig scale,
  double min,
  double max, {
  double minimumCentsSpacing = 0,
}) {
  final edo = scale.edo;
  // Parsed and cached tuning files always retain their own pitches and colors.
  if (edo == null) {
    return [
      for (final note in visibleScaleNotes(scale, min, max))
        ScaleGridLine(
          cents: note.cents,
          color: Color(scale.colorFor(note.index)),
          label: note.label,
          isAnchor: note.index == 0,
        ),
    ];
  }
  return [
    for (final line in EdoScaleGuide.linesForRange(
      edo: edo,
      minimumPitch: min / 100 + 24,
      maximumPitch: max / 100 + 24,
      minimumPitchSpacing: minimumCentsSpacing / 100,
    ))
      if (line.pitch >= min / 100 + 24 - .000001 &&
          line.pitch <= max / 100 + 24 + .000001)
        ScaleGridLine(
          cents: (line.pitch - 24) * 100,
          color: AppColors.muted,
          ratio: line.ratio,
          isAnchor: line.isAnchor,
          // Label each octave on a vertical monitor, including XenSynth's C4.
          label: line.isAnchor ? 'C${(line.pitch / 12).round() - 1}' : null,
        ),
  ];
}

void drawScaleGridLine(
  Canvas canvas,
  Rect plot,
  double y,
  ScaleGridLine line, {
  required bool edo,
  bool spectrum = false,
}) {
  canvas.drawLine(
    Offset(plot.left, y),
    Offset(plot.right, y),
    Paint()
      ..color = line.color.withValues(
        alpha: (edo ? 96 / 255 : (spectrum ? .22 : .58)) * line.ratio,
      )
      ..strokeWidth = edo ? (line.isAnchor ? 1.5 : 1) : .7,
  );
  if (edo) {
    canvas.drawLine(
      Offset(plot.left, y),
      Offset(plot.left + 20 * line.ratio, y),
      Paint()
        ..color = line.color.withValues(alpha: 184 / 255 * line.ratio)
        ..strokeWidth = line.isAnchor ? 1.4 : 1,
    );
  }
}

// Very small equaves can contain more notes than pixels. Sample real notes
// across the viewport instead of letting a dense imported scale break painting.
List<ScaleNote> visibleScaleNotes(ScaleConfig scale, double min, double max) {
  try {
    final notes = scale.notesBetween(min, max);
    final stride = math.max(1, (notes.length / 200).ceil());
    return [for (var i = 0; i < notes.length; i += stride) notes[i]];
  } on RangeError {
    final notes = <String, ScaleNote>{};
    for (var i = 0; i <= 24; i++) {
      final note = scale.nearestNote(min + (max - min) * i / 24);
      if (note.cents >= min && note.cents <= max) {
        notes['${note.index}:${note.register}'] = note;
      }
    }
    return notes.values.toList()..sort((a, b) => a.cents.compareTo(b.cents));
  }
}
