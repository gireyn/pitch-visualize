import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/domain/audio/log_spectrum.dart';
import 'package:pitch_visual/domain/audio/pitch_analyzer.dart';
import 'package:pitch_visual/domain/audio/real_fft.dart';
import 'package:pitch_visual/domain/pitch_math.dart';

void main() {
  test('each octave occupies the same 72 rows on the logarithmic axis', () {
    for (var band = 0; band < LogSpectrum.bands - 72; band++) {
      expect(
        LogSpectrum.frequencyAt(band + 72) /
            LogSpectrum.frequencyAt(band.toDouble()),
        closeTo(2, 1e-12),
      );
    }
    expect(LogSpectrum.frequencyAt(-.5), closeTo(c1Frequency, 1e-9));
    expect(
      LogSpectrum.frequencyAt(LogSpectrum.bands - .5),
      closeTo(c1Frequency * 256, 1e-9),
    );
  });

  test('Hann amplitude calibration: full-scale and half-scale sinusoids', () {
    for (final amplitude in [1.0, .5, .01]) {
      final packed = Float64List.fromList(
        List.generate(
          4096,
          (i) =>
              amplitude *
              math.sin(2 * math.pi * 100 * i / 4096) *
              (.5 - .5 * math.cos(2 * math.pi * i / 4096)),
        ),
      );
      RealFft(4096).forward(packed);
      final spectrum = LogSpectrum.fromFft(packed, 44100);
      final peak = spectrum.reduce(math.max);
      final db = LogSpectrum.floorDb + peak / 255 * -LogSpectrum.floorDb;
      expect(db, closeTo(20 * math.log(amplitude) / math.ln10, .4));
      final peakRow = spectrum.indexOf(peak);
      expect(
        frequencyToCents(LogSpectrum.frequencyAt(peakRow.toDouble())),
        closeTo(frequencyToCents(100 * 44100 / 4096), 25),
      );
    }
  });

  test('silence and DC have no visible frequency energy', () {
    for (final dc in [0.0, 1.0]) {
      final packed = Float64List(4096)..[0] = dc;
      expect(LogSpectrum.fromFft(packed, 44100), everyElement(0));
    }
  });

  test(
    'analyzer retains harmonics and old snapshots independently of pitch gate',
    () {
      final analyzer = PitchAnalyzer(threshold: 1e10);
      for (var i = 0; i < 44100 ~/ 3; i++) {
        final phase = 2 * math.pi * 220 * i / 44100;
        analyzer.addSample(
          (9000 * math.sin(phase) +
                  6000 * math.sin(phase * 2) +
                  3000 * math.sin(phase * 4))
              .round(),
        );
      }
      expect(analyzer.peakFrequency, -1);
      final snapshot = analyzer.spectrum;
      for (final frequency in [220.0, 440.0, 880.0]) {
        final row = (frequencyToCents(frequency) / LogSpectrum.centsPerBand)
            .floor();
        expect(
          snapshot.sublist(row - 2, row + 3).reduce(math.max),
          greaterThan(175),
        );
      }
      expect(() => snapshot[0] = 255, throwsUnsupportedError);
      analyzer.reset();
      expect(analyzer.spectrum, everyElement(0));
      expect(snapshot.any((value) => value > 175), isTrue);
    },
  );
}
