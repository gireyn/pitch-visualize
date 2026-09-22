import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/wave_data.dart';
import 'pcm_resampler.dart';
import 'pitch_analyzer.dart';
import 'pitch_worker.dart';

/// Analyzes every interval in a file without the live worker's dropping queue.
class RecordingAnalyzer {
  const RecordingAnalyzer();

  Future<List<PitchFrame>> analyze(
    WaveData wave, {
    required double threshold,
  }) => Isolate.run(() => _analyze(wave, threshold));
}

List<PitchFrame> _analyze(WaveData wave, double threshold) {
  final analyzer = PitchAnalyzer(threshold: threshold);
  final resampler = StreamingPcmResampler(wave.sampleRate);
  final frames = <PitchFrame>[];
  var count = 0;
  void addSample(int sample) {
    count++;
    if (analyzer.addSample(sample)) {
      frames.add(
        PitchFrame(
          frequency: analyzer.peakFrequency,
          level: analyzer.level,
          timeSeconds: math.min(
            count / PitchAnalyzer.sampleRate,
            wave.durationSeconds,
          ),
          spectrum: analyzer.spectrum,
        ),
      );
    }
  }

  for (var offset = 0; offset < wave.pcm.length; offset += 32768) {
    final end = math.min(offset + 32768, wave.pcm.length);
    for (final sample in resampler.addPcm(
      Uint8List.sublistView(wave.pcm, offset, end),
    )) {
      addSample(sample);
    }
  }
  // Include a partial final interval (also covers clips shorter than 1/30 s).
  // Padding belongs to the FFT window only, never to the file's timeline.
  while (count % PitchAnalyzer.analyzeInterval != 0) {
    addSample(0);
  }
  return frames;
}
