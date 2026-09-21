import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';

double absCent(double frequency) =>
    (math.log(frequency) - math.log(ScaleConfig.c1Frequency)) / math.ln2 * 1200;

void main() {
  group('pitch tokens', () {
    final tokens = <String, double>{
      '204.15565774574566c': 204.15565774574566,
      '(1*1200*Math.log(3)/Math.LN2)c': 1901.9550008653873,
      '3/2': 701.9550008653873,
      '-3/2': -701.9550008653873,
      '2187/2048': 113.68500605771193,
      r'5\53': 5 * 1200 / 53,
      r'7\186ed6': 7 * 1200 * math.log(6) / math.ln2 / 186,
      r'72\186ed6': 1200.7567745285369,
      '5ed53': 5 * 1200 / 53,
      r'5\53ed': 5 * 1200 / 53,
      '1000me': 1000 / math.ln2 * 1.2,
      'ie2': 500 / math.ln2 * 1.2,
      '0': 0,
      '1': 0,
    };
    for (final entry in tokens.entries) {
      test(entry.key, () {
        expect(
          ScaleConfig.parseCentsOrRatio(entry.key),
          closeTo(entry.value, 1e-9),
        );
      });
    }
    test('invalid or non-finite token returns null', () {
      for (final token in <String?>[
        null,
        '',
        '5ed',
        r'1\0',
        r'1\12ed0',
        r'1\12ed-2',
        r'1\12ed2ed3',
        r'\12',
        'ie0',
        'ie1/2',
        '1/0c',
        'Math.sqrt(-1)c',
        '1e309',
        'unknown',
      ]) {
        expect(ScaleConfig.parseCentsOrRatio(token), isNull, reason: token);
      }
    });
  });

  group('tuning configurations', () {
    late ScaleConfig tiangan;
    late ScaleConfig seven;
    setUp(() {
      tiangan = ScaleConfig.parse(
        File('assets/tunings/tiangan.txt').readAsStringSync(),
        '天干音阶',
      );
      seven = ScaleConfig.parse(
        File('assets/tunings/seven_ed2_on_c.txt').readAsStringSync(),
        '7ed2 on C',
      );
    });

    test(
      'bundled Tiangan tuning retains all ten notes and its non-octave equave',
      () {
        expect(tiangan.names, [
          '甲',
          '乙',
          '丙',
          '丁',
          '戊',
          '己',
          '庚',
          '辛',
          '壬',
          '癸',
        ]);
        expect(tiangan.referenceIndex, 0);
        expect(tiangan.periodCents, closeTo(1200.7567745285369, 1e-9));
        expect(tiangan.noteAt(0, 4).frequency, 320);
        expect(
          tiangan.noteAt(1, 4).frequency,
          closeTo(342.3223386242056, 1e-9),
        );
        expect(
          tiangan.noteAt(0, 5).frequency,
          closeTo(640.2798244251317, 1e-9),
        );
        expect(tiangan.nearestNote(absCent(320)).label, '甲4');
        expect(tiangan.nearestNote(absCent(342.3223386242056)).label, '乙4');
        expect(tiangan.nearestNote(absCent(640.2798244251317)).label, '甲5');
        expect(tiangan.colors!.length, 10);
        expect(tiangan.colorFor(0), 0xff888888);
        expect(tiangan.colorFor(1), 0xff545454);
        expect(tiangan.colorFor(10), 0xff888888);
      },
    );

    test('bundled seven equal division labels and colors survive', () {
      expect(seven.names, ['C', 'D', 'E', 'F', 'G', 'A', 'B']);
      expect(seven.cents.length, 7);
      expect(seven.periodCents, 1200);
      expect(seven.colors!.length, 7);
      expect(seven.noteAt(0, 4).frequency, closeTo(261.6255653005986, 1e-10));
      expect(seven.colorFor(7), 0xff888888);
    });

    test('name match takes precedence over standard letter fallback', () {
      final scale = ScaleConfig.parse(
        'E4: 330\n1/1 9/8 5/4 4/3 3/2 5/3 15/8 2/1\nC D E F G A B',
        'Just intonation',
      );
      expect(scale.referenceIndex, 2);
      expect(scale.noteAt(2, 4).frequency, 330);
      expect(scale.noteAt(0, 4).frequency, closeTo(264, 1e-10));
      expect(scale.colors, isNull);
      expect(scale.colorFor(0), 0xff888888);
      expect(scale.colorFor(1), 0xff545454);
    });

    test('standard letter fallback anchors first nominal', () {
      final scale = ScaleConfig.parse(
        'E4: 320\n0c 100c 1200c\n甲 乙',
        'Fallback',
      );
      expect(scale.referenceIndex, 0);
      expect(scale.noteAt(0, 4).frequency, 320);
    });

    test(
      'BOM, comments, CRLF, expression frequencies and repeated names/colors',
      () {
        final scale = ScaleConfig.parse(
          '\uFEFF // comment\r\n A4: 220*2 // ref\r\n0c 100c 200c 300c 1200c\r\nA B\r\n136 84',
          'Wrapped',
        );
        expect(scale.referenceFrequency, 440);
        expect(scale.names, ['A', 'B', 'A', 'B']);
        expect(scale.colors!.length, 2);
        expect(scale.colorFor(2), 0xff888888);
        expect(scale.colorFor(3), 0xff545454);
      },
    );

    test('missing names default to degree numbers', () {
      final scale = ScaleConfig.parse('A4: 440\n0c 200c 1200c', 'Numbered');
      expect(scale.names, ['1', '2']);
      expect(scale.referenceIndex, 0);
    });

    test('invalid optional color row remains a name row', () {
      final scale = ScaleConfig.parse('A4: 440\n0c 1200c\n256', 'Names');
      expect(scale.names, ['256']);
      expect(scale.colors, isNull);
    });

    test('cent values remain continuous across a non-octave period', () {
      final scale = ScaleConfig.parse('A4: 440\n0c 600c 3\nA B', 'Tritave');
      final note4 = scale.noteAt(0, 4);
      final note5 = scale.noteAt(0, 5);
      expect(note5.cents - note4.cents, closeTo(1901.9550008653873, 1e-9));
      expect(note5.frequency, closeTo(1320, 1e-9));
      for (final detuning in [-0.001, 0.0, 0.001]) {
        final nearest = scale.nearestNote(note5.cents + detuning);
        expect(nearest.label, 'A5');
        expect(nearest.cents, note5.cents);
      }
    });

    test(
      'negative equaves and periods below reference register remain valid',
      () {
        final scale = ScaleConfig.parse(
          'A4: 440\n0c -100c -1200c\nA B',
          'Descending',
        );
        expect(scale.noteAt(0, 5).frequency, closeTo(220, 1e-10));
        expect(scale.nearestNote(absCent(220)).label, 'A5');
        expect(scale.notesBetween(absCent(219), absCent(881)).length, 5);
      },
    );

    test('nearest register midpoint ties match Java Math.round', () {
      final scale = ScaleConfig.parse('A4: 440\n0c 1200c\nA', 'One note');
      expect(scale.nearestNote(scale.noteAt(0, 4).cents - 600).register, 4);
      expect(scale.nearestNote(scale.noteAt(0, 4).cents - 600.001).register, 3);
    });

    test(
      'grid covers visible cents in pitch order without flattening names',
      () {
        final min = tiangan.noteAt(0, 3).cents - 0.001;
        final max = tiangan.noteAt(0, 5).cents + 0.001;
        final notes = tiangan.notesBetween(min, max);
        expect(notes.length, 21);
        expect(notes.first.label, '甲3');
        expect(notes.last.label, '甲5');
        for (var i = 1; i < notes.length; i++) {
          expect(notes[i].cents, greaterThanOrEqualTo(notes[i - 1].cents));
        }
        expect(tiangan.notesBetween(100, 0), isEmpty);
      },
    );

    test('cache round trip preserves tuning and optional grayscale colors', () {
      for (final original in [tiangan, seven]) {
        final restored = ScaleConfig.fromPayload(original.toPayload())!;
        expect(restored.name, original.name);
        expect(restored.names, original.names);
        expect(restored.cents, original.cents);
        expect(restored.colors, original.colors);
        expect(restored.referenceIndex, original.referenceIndex);
        expect(restored.referenceOctave, original.referenceOctave);
        expect(restored.periodCents, original.periodCents);
        expect(restored.noteAt(1, 6).cents, original.noteAt(1, 6).cents);
      }
    });

    test('old cache without names gets fallback degree names', () {
      final restored = ScaleConfig.fromPayload(
        'XENCFG1\nOld\nA\n0\n4\n440.0\n1200.0\n2\n0.0 100.0',
      )!;
      expect(restored.names, ['1', '2']);
      expect(restored.colors, isNull);
    });

    test('invalid configs throw actionable format errors', () {
      for (final text in [
        '',
        '// only a comment',
        'A4 440\n0c 1200c',
        'A4: -1\n0c 1200c',
        'A4: 1/0\n0c 1200c',
        'A4: 440\n1200c',
        'A4: 440\n0c 0c',
        'A4: 440\n0c nonsense',
        '甲4: 320\n0c 1200c\n乙',
        'A4: 440\n0c 1/0c',
      ]) {
        expect(
          () => ScaleConfig.parse(text, 'Invalid'),
          throwsFormatException,
          reason: text,
        );
      }
    });

    test('corrupt caches fail safely', () {
      for (final payload in <String?>[
        null,
        '',
        'XENCFG2',
        'XENCFG1',
        tiangan.toPayload().replaceFirst('\n320.0\n', '\nNaN\n'),
        tiangan.toPayload().replaceFirst('\n10\n', '\n-1\n'),
        tiangan.toPayload().replaceFirst('colors 136', 'colors 999'),
        'XENCFG1\nOld\nA\n-1\n4\n440.0\n1200.0\n2\n0.0 100.0',
        'XENCFG1\nOld\nA\n0\n4\n440.0\n1200.0\n2\n0.0 Infinity',
      ]) {
        expect(ScaleConfig.fromPayload(payload), isNull, reason: payload);
      }
    });

    test('published note collections cannot be changed by callers', () {
      expect(() => tiangan.names[0] = 'Changed', throwsUnsupportedError);
      expect(() => tiangan.cents[0] = 100, throwsUnsupportedError);
      expect(() => tiangan.colors![0] = 0, throwsUnsupportedError);
    });
  });
}
