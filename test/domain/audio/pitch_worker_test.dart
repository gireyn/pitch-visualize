import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/domain/audio/pcm_resampler.dart';
import 'package:pitch_visual/domain/audio/pitch_analyzer.dart';
import 'package:pitch_visual/domain/audio/pitch_worker.dart';
import 'package:pitch_visual/domain/audio/log_spectrum.dart';

void main() {
  group('StreamingPcmResampler', () {
    for (final rate in [8000, 16000, 22050, 96000, 192000]) {
      test('$rate Hz sine retains pitch and phase across arbitrary chunks', () {
        final sampleCount = math.min(rate, 96000);
        final pcm = _sinePcm(rate, 440, sampleCount);
        final contiguous = StreamingPcmResampler(rate).addPcm(pcm);
        final chunked = StreamingPcmResampler(rate);
        final collected = <int>[];
        final random = math.Random(517);
        var position = 0;
        while (position < pcm.length) {
          final end = math.min(
            pcm.length,
            position + 2 * (1 + random.nextInt(999)),
          );
          collected.addAll(
            chunked.addPcm(Uint8List.sublistView(pcm, position, end)),
          );
          position = end;
        }
        expect(contiguous.length, ((sampleCount - 1) * 44100 ~/ rate) + 1);
        expect(collected, contiguous);
        final analyzer = PitchAnalyzer();
        var squaredError = 0.0;
        for (var i = 0; i < contiguous.length; i++) {
          final ideal = 8000 * math.sin(2 * math.pi * 440 * i / 44100);
          squaredError += math.pow(contiguous[i] - ideal, 2);
          analyzer.addSample(contiguous[i]);
        }
        // Linear interpolation has bounded curvature error, plus PCM rounding.
        final interpolationBound =
            8000 * math.pow(2 * math.pi * 440 / rate, 2) / 8 + 1;
        expect(
          math.sqrt(squaredError / contiguous.length),
          lessThan(interpolationBound),
        );
        expect(analyzer.peakFrequency, closeTo(440, 0.5));
      });
    }

    test('48 kHz produces 44100 samples with identical arbitrary chunks', () {
      final pcm = _sinePcm(48000, 440, 48000);
      final contiguous = StreamingPcmResampler(48000).addPcm(pcm);
      final chunked = StreamingPcmResampler(48000);
      final collected = <int>[];
      var position = 0;
      final random = math.Random(517);
      while (position < pcm.length) {
        final end = math.min(
          pcm.length,
          position + 2 * (1 + random.nextInt(999)),
        );
        collected.addAll(
          chunked.addPcm(Uint8List.sublistView(pcm, position, end)),
        );
        position = end;
      }
      expect(contiguous.length, 44100);
      expect(collected, contiguous);
      var squaredError = 0.0;
      for (var i = 0; i < contiguous.length; i++) {
        final ideal = 8000 * math.sin(2 * math.pi * 440 * i / 44100);
        squaredError += math.pow(contiguous[i] - ideal, 2);
      }
      expect(math.sqrt(squaredError / contiguous.length), lessThan(3));
    });

    test(
      '44.1 kHz passes PCM16 signed LE unchanged, including view offsets',
      () {
        final buffer = Uint8List(14);
        final pcm = ByteData.sublistView(buffer, 2, 12);
        const samples = [-32768, -12345, 0, 12345, 32767];
        for (var i = 0; i < samples.length; i++) {
          pcm.setInt16(i * 2, samples[i], Endian.little);
        }
        final resampler = StreamingPcmResampler(44100);
        expect(resampler.addPcm(Uint8List.sublistView(buffer, 2, 12)), samples);
        resampler.reset();
        expect(resampler.addPcm(Uint8List(0)), isEmpty);
        expect(resampler.addPcm(Uint8List.fromList([0, 128])), [-32768]);
      },
    );

    test(
      'rejects unsupported rates, odd PCM and excessively large buffers',
      () {
        expect(() => StreamingPcmResampler(7999), throwsRangeError);
        expect(() => StreamingPcmResampler(192001), throwsRangeError);
        expect(
          () => StreamingPcmResampler(22050, outputSampleRate: 48000),
          throwsArgumentError,
        );
        final resampler = StreamingPcmResampler(48000);
        expect(() => resampler.addPcm(Uint8List(3)), throwsArgumentError);
        expect(() => resampler.addPcm(Uint8List(192002)), throwsArgumentError);
      },
    );
  });

  group('PitchWorker isolate', () {
    for (final rate in [16000, 22050, 96000]) {
      test(
        '$rate Hz WAV PCM reaches the isolate without rate errors',
        () async {
          final worker = PitchWorker();
          addTearDown(worker.dispose);
          final output = worker.frames.take(14).toList();
          await worker.start();
          worker.addPcm(_sinePcm(rate, 440, rate ~/ 2), rate);
          final frames = await output.timeout(const Duration(seconds: 10));
          expect(frames.last.frequency, closeTo(440, 0.5));
          expect(frames.last.timeSeconds, closeTo(14 / 30, 1e-12));
        },
      );
    }

    test(
      '48 kHz PCM produces 30 accurately timed frames and expected RMS',
      () async {
        final worker = PitchWorker();
        addTearDown(worker.dispose);
        final output = worker.frames.take(30).toList();
        await worker.start();
        await worker.start();
        worker.addPcm(_sinePcm(48000, 342.3223386242056, 48000), 48000);
        final frames = await output.timeout(const Duration(seconds: 10));
        expect(frames.length, 30);
        expect(frames.last.timeSeconds, 1);
        expect(frames.last.spectrum, hasLength(LogSpectrum.bands));
        expect(frames.last.spectrum!.any((value) => value > 150), isTrue);
        expect(frames.last.frequency, closeTo(342.3223386242056, 0.5));
        expect(frames.last.level, closeTo(8000 / 32768 / math.sqrt(2), 0.005));
        for (var i = 0; i < frames.length; i++) {
          expect(frames[i].timeSeconds, closeTo((i + 1) / 30, 1e-12));
        }
      },
    );

    test(
      'reset drops pending and in-flight old audio before the next source',
      () async {
        final worker = PitchWorker();
        addTearDown(worker.dispose);
        final output = worker.frames.take(3).toList();
        await worker.start();
        worker.addPcm(_sinePcm(44100, 440, 44100), 44100);
        worker.addPcm(_sinePcm(44100, 440, 44100), 44100);
        worker.reset();
        worker.addPcm(Uint8List(8820), 44100);
        final frames = await output.timeout(const Duration(seconds: 10));
        expect(frames.map((f) => f.frequency), everyElement(-1));
        expect(frames.map((f) => f.level), everyElement(0));
        for (final frame in frames) {
          expect(frame.spectrum, everyElement(0));
        }
        expect(frames.last.timeSeconds, 0.1);
      },
    );

    test(
      'reset during frame delivery filters already queued old frames',
      () async {
        final worker = PitchWorker();
        addTearDown(worker.dispose);
        final completion = Completer<void>();
        final frames = <PitchFrame>[];
        final subscription = worker.frames.listen((frame) {
          frames.add(frame);
          if (frames.length == 1) {
            worker.reset();
            worker.addPcm(Uint8List(2940), 44100);
          } else if (frames.length == 2) {
            completion.complete();
          }
        });
        addTearDown(subscription.cancel);
        await worker.start();
        worker.addPcm(_sinePcm(44100, 440, 44100), 44100);
        await completion.future.timeout(const Duration(seconds: 10));
        expect(frames.length, 2);
        expect(frames.last.frequency, -1);
        expect(frames.last.level, 0);
        expect(frames.last.timeSeconds, closeTo(1 / 30, 1e-12));
      },
    );

    test(
      'burst input stays bounded and does not retain a stale backlog',
      () async {
        final worker = PitchWorker();
        addTearDown(worker.dispose);
        await worker.start();
        final block = Uint8List(2940);
        for (var i = 0; i < 100; i++) {
          worker.addPcm(block, 44100);
        }
        expect(worker.droppedChunks, greaterThan(80));
        worker.reset();
        final output = worker.frames.first;
        worker.addPcm(block, 44100);
        expect(
          (await output.timeout(const Duration(seconds: 10))).frequency,
          -1,
        );
      },
    );

    test('overflow timestamps retain the duration of dropped PCM', () async {
      final worker = PitchWorker();
      addTearDown(worker.dispose);
      final output = worker.frames.take(4).toList();
      await worker.start();
      final block = Uint8List(2940);
      // No isolate response can be handled until this synchronous burst ends.
      // One block is in flight; 96 old queued blocks are dropped; 3 remain.
      for (var i = 0; i < 100; i++) {
        worker.addPcm(block, 44100);
      }
      expect(worker.droppedChunks, 96);
      final frames = await output.timeout(const Duration(seconds: 10));
      expect(frames[0].timeSeconds, closeTo(1 / 30, 1e-10));
      expect(frames[1].timeSeconds, closeTo(98 / 30, 1e-10));
      expect(frames[2].timeSeconds, closeTo(99 / 30, 1e-10));
      expect(frames[3].timeSeconds, closeTo(100 / 30, 1e-10));
    });

    test(
      'rate changes preserve the source timeline until explicit reset',
      () async {
        final worker = PitchWorker();
        addTearDown(worker.dispose);
        final output = worker.frames.take(6).toList();
        await worker.start();
        worker.addPcm(Uint8List(8820), 44100);
        worker.addPcm(Uint8List(19200), 96000);
        final frames = await output.timeout(const Duration(seconds: 10));
        for (var i = 0; i < frames.length; i++) {
          expect(frames[i].timeSeconds, closeTo((i + 1) / 30, 1e-10));
        }
        worker.reset();
        final next = worker.frames.first;
        worker.addPcm(Uint8List(2940), 44100);
        expect(
          (await next.timeout(const Duration(seconds: 10))).timeSeconds,
          closeTo(1 / 30, 1e-10),
        );
      },
    );

    test(
      'threshold changes apply to later chunks and disposal is idempotent',
      () async {
        final worker = PitchWorker();
        expect(() => worker.addPcm(Uint8List(2), 44100), throwsStateError);
        await worker.start();
        worker.threshold = 1e10;
        final output = worker.frames.take(3).toList();
        worker.addPcm(_sinePcm(44100, 440, 4410), 44100);
        final frames = await output.timeout(const Duration(seconds: 10));
        expect(frames.map((f) => f.frequency), everyElement(-1));
        expect(frames.last.level, greaterThan(0));
        expect(frames.last.spectrum!.any((value) => value > 150), isTrue);
        await worker.dispose();
        await worker.dispose();
        expect(worker.start(), throwsStateError);
        expect(() => worker.addPcm(Uint8List(2), 44100), throwsStateError);
      },
    );
  });
}

Uint8List _sinePcm(int sampleRate, double frequency, int sampleCount) {
  final pcm = Uint8List(sampleCount * 2);
  final data = ByteData.sublistView(pcm);
  for (var i = 0; i < sampleCount; i++) {
    data.setInt16(
      i * 2,
      (8000 * math.sin(2 * math.pi * frequency * i / sampleRate)).toInt(),
      Endian.little,
    );
  }
  return pcm;
}
