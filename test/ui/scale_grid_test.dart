import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';
import 'package:pitch_visual/ui/features/monitor/scale_grid.dart';

void main() {
  for (final edo in [12, 31]) {
    test('$edo EDO maps one octave to the C1-relative cent axis', () {
      final lines = visibleScaleLines(
        ScaleConfig.equalDivision(edo),
        3600,
        4800,
      );

      expect(lines, hasLength(edo + 1));
      for (var i = 0; i <= edo; i++) {
        expect(lines[i].cents, closeTo(3600 + 1200 * i / edo, .000001));
      }
      expect(lines.first.label, 'C4');
      expect(lines.last.label, 'C5');
      expect(lines.where((line) => line.isAnchor), hasLength(2));
      expect(
        lines.skip(1).take(edo - 1).every((line) => line.label == null),
        isTrue,
      );
    });
  }

  test('0 EDO retains only octave anchors from C1 through C9', () {
    final lines = visibleScaleLines(ScaleConfig.equalDivision(0), 0, 9600);

    expect(lines.map((line) => line.cents), List.generate(9, (i) => i * 1200));
    expect(
      lines.map((line) => line.label),
      List.generate(9, (i) => 'C${i + 1}'),
    );
    expect(lines.every((line) => line.isAnchor && line.ratio == 1), isTrue);
  });

  test('a partial viewport excludes the guide generator neighboring ticks', () {
    final lines = visibleScaleLines(ScaleConfig.equalDivision(12), 3650, 3850);

    expect(lines.map((line) => line.cents), [3700, 3800]);
  });

  test(
    'zooming out thins dense divisions while every octave stays visible',
    () {
      final scale = ScaleConfig.equalDivision(72);
      final detailed = visibleScaleLines(scale, 0, 9600);
      final overview = visibleScaleLines(
        scale,
        0,
        9600,
        minimumCentsSpacing: 160,
      );

      expect(overview.length, lessThan(detailed.length ~/ 2));
      expect(
        overview.where((line) => line.isAnchor).map((line) => line.cents),
        List.generate(9, (i) => i * 1200),
      );
      expect(
        overview
            .where((line) => line.isAnchor)
            .every((line) => line.ratio == 1),
        isTrue,
      );
      expect(
        overview.every((line) => line.ratio > 0 && line.ratio <= 1),
        isTrue,
      );
      expect(overview.any((line) => line.ratio < .2), isTrue);
    },
  );

  for (final restored in [false, true]) {
    test(
      'imported irregular non-octave tuning keeps pitches, names and colors${restored ? ' after restoring its cache' : ''}',
      () {
        final imported = ScaleConfig.parse(
          'A4: 261.6255653005986\n0c 250c 700c 1900c\nA B D\n220 90 150',
          'Custom 1900-cent period',
        );
        final scale = restored
            ? ScaleConfig.fromPayload(imported.toPayload())!
            : imported;
        final lines = visibleScaleLines(
          scale,
          3500,
          6400,
          minimumCentsSpacing: 1000,
        );

        expect(scale.edo, isNull);
        expect(
          lines.map((line) => line.cents),
          orderedEquals([
            closeTo(3600, .000001),
            closeTo(3850, .000001),
            closeTo(4300, .000001),
            closeTo(5500, .000001),
            closeTo(5750, .000001),
            closeTo(6200, .000001),
          ]),
        );
        expect(lines.map((line) => line.label), [
          'A4',
          'B4',
          'D4',
          'A5',
          'B5',
          'D5',
        ]);
        expect(lines.map((line) => line.color), [
          const Color(0xffdcdcdc),
          const Color(0xff5a5a5a),
          const Color(0xff969696),
          const Color(0xffdcdcdc),
          const Color(0xff5a5a5a),
          const Color(0xff969696),
        ]);
        expect(lines.map((line) => line.isAnchor), [
          true,
          false,
          false,
          true,
          false,
          false,
        ]);
      },
    );
  }
}
