import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/domain/audio/pitch_analyzer.dart';
import 'package:pitch_visual/domain/audio/real_fft.dart';
import 'package:pitch_visual/domain/pitch_math.dart';

void main() {
  group('RealFft', () {
    test('packed FFT agrees with direct DFT and inverse scales by N/2', () {
      const size = 16;
      final original = List<double>.generate(
        size,
        (i) => math.sin(i * 0.7) + 0.3 * math.cos(i * 2.1),
      );
      final packed = Float64List.fromList(original);
      final fft = RealFft(size)..forward(packed);
      for (var k = 0; k <= size ~/ 2; k++) {
        var real = 0.0;
        var imaginary = 0.0;
        for (var i = 0; i < size; i++) {
          real += original[i] * math.cos(2 * math.pi * k * i / size);
          imaginary += original[i] * math.sin(2 * math.pi * k * i / size);
        }
        expect(packed[k == size ~/ 2 ? 1 : 2 * k], closeTo(real, 1e-12));
        if (k > 0 && k < size ~/ 2) {
          expect(packed[2 * k + 1], closeTo(imaginary, 1e-12));
        }
      }
      fft.inverse(packed);
      for (var i = 0; i < size; i++) {
        expect(packed[i], closeTo(original[i] * size / 2, 1e-12));
      }
    });
  });

  group('pitch math', () {
    test(
      'C1 reference, A4 and conversions preserve microtonal frequencies',
      () {
        expect(frequencyToCents(c1Frequency), closeTo(0, 1e-10));
        expect(frequencyToCents(440), closeTo(4500, 1e-10));
        for (final hz in [
          15.0,
          110.0,
          261.6255653,
          320.0,
          342.3223386,
          440.0,
        ]) {
          expect(centsToFrequency(frequencyToCents(hz)), closeTo(hz, 1e-10));
        }
        expect(frequencyToCents(-1), -1);
        expect(frequencyToCents(0), -1);
        expect(frequencyToCents(double.nan), -1);
      },
    );
  });

  final golden =
      jsonDecode(
            File(
              'test/domain/audio/legacy_pitch_golden.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  group('legacy pitch behavior with corrected FFT', () {
    for (final value in golden['sines'] as List<dynamic>) {
      final entry = value as Map<String, dynamic>;
      final frequency = (entry['frequency'] as num).toDouble();
      test('90 frames for $frequency Hz retain stable pitch', () {
        final actual = _analyze(frequency);
        expect(actual.length, 90);
        // The first two windows are incomplete. Legacy FFT4g fails a direct
        // DFT/round-trip comparison, so its startup artifacts are not goldens.
        // Both detectors must converge on the same note after the FFT fills.
        final legacy = entry['frames'] as List<dynamic>;
        for (var i = 2; i < actual.length; i++) {
          expect(actual[i], closeTo(frequency, frequency * 0.005));
          expect(actual[i], closeTo((legacy[i] as num).toDouble(), 0.5));
        }
      });
    }
    test('weak 110 Hz fundamental survives a dominant second harmonic', () {
      final actual = _analyze(110, harmonics: true);
      expect(actual.length, 90);
      expect(actual.skip(2), everyElement(closeTo(110, 1)));
    });
    test('seeded broadband noise is unvoiced and matches Java', () {
      final actual = _analyze(0, noise: true);
      _expectGolden(actual, golden['noise'] as List<dynamic>);
      expect(actual, everyElement(-1));
    });
  });

  group('PitchAnalyzer state', () {
    test('silence, exact frame cadence, normalized level and threshold', () {
      final analyzer = PitchAnalyzer();
      for (var i = 0; i < PitchAnalyzer.analyzeInterval - 1; i++) {
        expect(analyzer.addSample(0), isFalse);
      }
      expect(analyzer.addSample(0), isTrue);
      expect(analyzer.peakFrequency, -1);
      expect(analyzer.level, 0);
      expect(analyzer.totalFrames, 1);
      analyzer.threshold = 1e10;
      for (var i = 0; i < 4410; i++) {
        analyzer.addSample(
          (8000 * math.sin(2 * math.pi * 440 * i / 44100)).toInt(),
        );
      }
      expect(analyzer.totalFrames, 4);
      expect(analyzer.peakFrequency, -1);
      expect(analyzer.level, closeTo(8000 / 32768 / math.sqrt(2), 0.005));
      expect(() => analyzer.threshold = double.nan, throwsArgumentError);
      expect(() => analyzer.addSample(40000), throwsRangeError);
    });
    test('reset clears old samples, level and 800-value pitch history', () {
      final analyzer = PitchAnalyzer();
      for (var i = 0; i < 5000; i++) {
        analyzer.addSample(
          (8000 * math.sin(2 * math.pi * 440 * i / 44100)).toInt(),
        );
      }
      expect(analyzer.peakFrequency, greaterThan(0));
      expect(analyzer.pitchHistory.length, 800);
      analyzer.reset();
      expect(analyzer.totalFrames, 0);
      expect(analyzer.historyPosition, 0);
      expect(analyzer.peakFrequency, -1);
      expect(analyzer.level, 0);
      expect(analyzer.pitchHistory, everyElement(-1));
      for (var i = 0; i < 1470; i++) {
        analyzer.addSample(0);
      }
      expect(analyzer.peakFrequency, -1);
    });
  });
}

List<double> _analyze(
  double frequency, {
  bool harmonics = false,
  bool noise = false,
}) {
  final analyzer = PitchAnalyzer();
  final frames = <double>[];
  var state = 123456789;
  for (var i = 0; i < 44100 * 3; i++) {
    final phase = 2 * math.pi * frequency * i / 44100;
    final wave = harmonics
        ? 0.2 * math.sin(phase) +
              0.7 * math.sin(phase * 2) +
              0.25 * math.sin(phase * 3)
        : math.sin(phase);
    state = (1664525 * state + 1013904223) & 0xffffffff;
    final sample = noise
        ? (((state >> 16) & 65535) - 32768) ~/ 4
        : (8000 * wave).toInt();
    if (analyzer.addSample(sample)) frames.add(analyzer.peakFrequency);
  }
  return frames;
}

void _expectGolden(List<double> actual, List<dynamic> expected) {
  expect(actual.length, expected.length);
  for (var i = 0; i < actual.length; i++) {
    expect(
      actual[i],
      closeTo((expected[i] as num).toDouble(), 1e-6),
      reason: 'frame $i',
    );
  }
}
