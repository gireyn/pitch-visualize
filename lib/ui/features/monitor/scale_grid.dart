import 'dart:math' as math;

import '../../../domain/tuning/scale_config.dart';

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
