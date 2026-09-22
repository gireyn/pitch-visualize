import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/ui/features/monitor/edo_scale_guide.dart';

void main() {
  List<EdoScaleLine> octave(int edo, {double start = 0}) {
    return EdoScaleGuide.linesForRange(
      edo: edo,
      minimumPitch: start,
      maximumPitch: start + 12,
    ).where((line) => line.pitch >= start && line.pitch < start + 12).toList();
  }

  group('XenSynth EDO patterns', () {
    test('supports every built-in division and omits unsupported scales', () {
      for (var edo = 0; edo <= 72; edo++) {
        expect(EdoScaleGuide.hasScale(edo), isTrue, reason: '$edo EDO');
        final lines = octave(edo);
        expect(lines, isNotEmpty, reason: '$edo EDO');
        expect(lines.first.pitch, 0);
        expect(lines.first.ratio, 1);
        expect(lines.first.isAnchor, isTrue);
        expect(lines.map((line) => line.pitch).toSet().length, lines.length);
        expect(
          lines.every((line) => line.ratio > 0 && line.ratio <= 1),
          isTrue,
        );
      }
      expect(EdoScaleGuide.hasScale(73), isFalse);
      expect(
        EdoScaleGuide.linesForRange(edo: 73, minimumPitch: 0, maximumPitch: 12),
        isEmpty,
      );
    });

    test('12 EDO retains natural and accidental tick emphasis', () {
      final lines = octave(12);
      expect(lines.map((line) => line.pitch), List.generate(12, (i) => i));
      expect(lines.map((line) => line.ratio), [
        1,
        0.6,
        0.8,
        0.6,
        0.8,
        0.8,
        0.6,
        0.8,
        0.6,
        0.8,
        0.6,
        0.8,
      ]);
    });

    test('19 EDO uses equal spacing and its original emphasis pattern', () {
      final lines = octave(19);
      expect(lines, hasLength(19));
      for (var i = 0; i < lines.length; i++) {
        expect(lines[i].pitch, closeTo(i * 12 / 19, 0.000001));
      }
      expect(lines.map((line) => line.ratio), [
        1,
        0.6,
        0.6,
        0.8,
        0.6,
        0.6,
        0.8,
        0.6,
        0.8,
        0.6,
        0.6,
        0.8,
        0.6,
        0.6,
        0.8,
        0.6,
        0.6,
        0.8,
        0.6,
      ]);
    });

    test('72 EDO includes the weakest visible tick level', () {
      final lines = octave(72);
      expect(lines, hasLength(72));
      expect(lines[1].pitch, closeTo(1 / 6, 0.000001));
      expect(lines[1].ratio, 0.2);
      expect(lines[3].ratio, 0.4);
      expect(lines[6].ratio, 0.6);
      expect(lines[12].ratio, 0.8);
    });

    test('0 and 1 EDO omit hidden marks and show only octave anchors', () {
      for (final edo in [-1, 0, 1]) {
        final lines = EdoScaleGuide.linesForRange(
          edo: edo,
          minimumPitch: 0,
          maximumPitch: 36,
        ).toList();
        expect(lines.map((line) => line.pitch), [-12, 0, 12, 24, 36, 48]);
        expect(lines.every((line) => line.isAnchor && line.ratio == 1), isTrue);
      }
    });

    test('negative pitches repeat the same octave pattern', () {
      final positive = octave(19);
      final negative = octave(19, start: -12);
      expect(negative, hasLength(positive.length));
      for (var i = 0; i < positive.length; i++) {
        expect(negative[i].pitch, closeTo(positive[i].pitch - 12, 0.000001));
        expect(negative[i].ratio, positive[i].ratio);
        expect(negative[i].isAnchor, positive[i].isAnchor);
      }
    });

    test('octave anchors remain visible and only middle C gets a label', () {
      final lines = EdoScaleGuide.linesForRange(
        edo: 72,
        minimumPitch: 48,
        maximumPitch: 84,
        minimumPitchSpacing: 100,
      ).toList();
      final anchors = lines.where((line) => line.isAnchor);
      expect(anchors.map((line) => line.pitch), [48, 60, 72, 84]);
      expect(anchors.every((line) => line.ratio == 1), isTrue);
      final labeled = lines.where((line) => line.label != null).toList();
      expect(labeled, hasLength(1));
      expect(labeled.single.pitch, 60);
      expect(labeled.single.label, 'C4');
    });

    test('reversed ranges do not produce guide lines', () {
      expect(
        EdoScaleGuide.linesForRange(
          edo: 12,
          minimumPitch: 72,
          maximumPitch: 60,
        ),
        isEmpty,
      );
    });
  });

  group('dense line visibility', () {
    double visibility(int index, double spacing, {bool anchor = false}) {
      return DenseLineVisibility.ratioForStep(
        stepIndex: index,
        step: 1,
        minimumPitchSpacing: spacing,
        isAnchor: anchor,
      );
    }

    test('fades minor lines before hiding them at the next stride', () {
      expect(visibility(1, 1), 1);
      expect(visibility(1, 1.25), closeTo(0.84375, 0.000001));
      expect(visibility(1, 1.5), 0.5);
      expect(visibility(1, 1.75), closeTo(0.15625, 0.000001));
      expect(visibility(1, 1.99), 0);
      expect(visibility(1, 2), 0);
      expect(visibility(2, 2), 1);
      expect(visibility(1, 100, anchor: true), 1);
    });

    test('thinning stays symmetric across negative and positive pitches', () {
      for (var i = 1; i < 20; i++) {
        for (final spacing in [2.0, 2.5, 3.0, 4.2]) {
          expect(visibility(-i, spacing), visibility(i, spacing));
        }
      }
    });

    test('combines density fading with the original tick emphasis', () {
      final lines = EdoScaleGuide.linesForRange(
        edo: 12,
        minimumPitch: 0,
        maximumPitch: 12,
        minimumPitchSpacing: 1.5,
      ).toList();
      expect(lines.singleWhere((line) => line.pitch == 0).ratio, 1);
      expect(lines.singleWhere((line) => line.pitch == 1).ratio, 0.3);
      expect(lines.singleWhere((line) => line.pitch == 2).ratio, 0.4);
    });
  });
}
