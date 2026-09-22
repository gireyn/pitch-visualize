import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/domain/audio/log_spectrum.dart';
import 'package:pitch_visual/domain/audio/recording_analyzer.dart';
import 'package:pitch_visual/domain/models/wave_data.dart';

WaveData tone(int rate, double duration, double frequency) {
  final pcm = Uint8List((rate * duration).round() * 2);
  final data = ByteData.sublistView(pcm);
  for (var i = 0; i < pcm.length ~/ 2; i++) {
    data.setInt16(
      i * 2,
      (12000 * math.sin(2 * math.pi * frequency * i / rate)).round(),
      Endian.little,
    );
  }
  return WaveData(pcm: pcm, sampleRate: rate);
}

void main() {
  const analyzer = RecordingAnalyzer();
  for (final rate in [8000, 44100, 48000, 192000]) {
    test('whole-file analysis retains pitch and FFT at $rate Hz', () async {
      final frames = await analyzer.analyze(tone(rate, 1, 440), threshold: 2);
      expect(frames, hasLength(30));
      expect(frames.first.timeSeconds, closeTo(1 / 30, 1e-9));
      expect(frames.last.timeSeconds, 1);
      for (var i = 3; i < frames.length; i++) {
        expect(frames[i].timeSeconds, closeTo((i + 1) / 30, 1e-9));
        expect(frames[i].frequency, closeTo(440, 2));
        final spectrum = frames[i].spectrum!;
        final peak = spectrum.indexOf(spectrum.reduce(math.max));
        expect(LogSpectrum.frequencyAt(peak.toDouble()), closeTo(440, 12));
      }
    });
  }

  test('retains all five minutes beyond the live history limit', () async {
    final wave = WaveData(pcm: Uint8List(8000 * 2 * 300), sampleRate: 8000);
    final frames = await analyzer.analyze(wave, threshold: 2);
    expect(frames, hasLength(9000));
    expect(frames.first.timeSeconds, closeTo(1 / 30, 1e-9));
    expect(frames.last.timeSeconds, 300);
    expect(frames.every((frame) => frame.frequency < 0), isTrue);
    expect(
      frames.every((frame) => frame.spectrum!.every((v) => v == 0)),
      isTrue,
    );
  });

  test(
    'short clips and partial tails end at the actual file duration',
    () async {
      for (final duration in [.009, .107]) {
        final wave = tone(44100, duration, 440);
        final frames = await analyzer.analyze(wave, threshold: 2);
        expect(frames, hasLength((wave.durationSeconds * 30).ceil()));
        expect(frames.last.timeSeconds, wave.durationSeconds);
        expect(frames.last.spectrum, hasLength(LogSpectrum.bands));
      }
    },
  );

  test('a pitch gate never removes the FFT', () async {
    final frames = await analyzer.analyze(tone(48000, .2, 440), threshold: 1e9);
    expect(frames.every((frame) => frame.frequency < 0), isTrue);
    expect(frames.last.spectrum!.reduce(math.max), greaterThan(100));
  });
}
