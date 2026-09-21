import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/domain/models/wave_data.dart';

Uint8List pcm16(List<int> samples) {
  final bytes = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes;
}

Uint8List chunk(String id, Uint8List contents, {bool pad = true}) {
  final bytes = Uint8List(
    8 + contents.length + (pad ? contents.length % 2 : 0),
  );
  bytes.setRange(0, 4, id.codeUnits);
  ByteData.sublistView(bytes).setUint32(4, contents.length, Endian.little);
  bytes.setRange(8, 8 + contents.length, contents);
  return bytes;
}

Uint8List wav({
  int channels = 1,
  int rate = 44100,
  int format = 1,
  int bits = 16,
  int? alignment,
  Uint8List? samples,
  List<Uint8List> extras = const [],
}) {
  final fmt = Uint8List(16);
  final data = ByteData.sublistView(fmt);
  data.setUint16(0, format, Endian.little);
  data.setUint16(2, channels, Endian.little);
  data.setUint32(4, rate, Endian.little);
  data.setUint32(8, rate * channels * 2, Endian.little);
  data.setUint16(12, alignment ?? channels * 2, Endian.little);
  data.setUint16(14, bits, Endian.little);
  final body = BytesBuilder()
    ..add('WAVE'.codeUnits)
    ..add(chunk('fmt ', fmt))
    ..add(chunk('data', samples ?? pcm16([0, 2000, -2000, 0])));
  for (final extra in extras) {
    body.add(extra);
  }
  final contents = body.takeBytes();
  final bytes = Uint8List(contents.length + 8);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  ByteData.sublistView(bytes).setUint32(4, contents.length, Endian.little);
  bytes.setRange(8, bytes.length, contents);
  return bytes;
}

void main() {
  group('WaveData', () {
    test(
      'PCM16 mono encode/decode preserves boundaries, rate and duration',
      () {
        final pcm = pcm16([-32768, -1, 0, 1, 32767]);
        final original = WaveData(pcm: pcm, sampleRate: 48000);
        final encoded = original.encode();
        final result = WaveData.decode(encoded);
        expect(result.pcm, pcm);
        expect(result.sampleRate, 48000);
        expect(result.durationSeconds, 5 / 48000);
        encoded[44] = 0;
        expect(result.pcm, pcm, reason: 'Decode must not alias mutable input');
      },
    );
    test(
      'stereo mixes channels with truncation and without int16 overflow',
      () {
        final result = WaveData.decode(
          wav(
            channels: 2,
            samples: pcm16([32767, 32767, -32768, -32768, 1000, -1000, -1, 0]),
          ),
        );
        expect(result.pcm, pcm16([32767, -32768, 0, 0]));
        expect(result.durationSeconds, 4 / 44100);
      },
    );
    test('unknown chunks and odd chunk padding are skipped', () {
      final bytes = wav(
        extras: [
          chunk('LIST', Uint8List.fromList([1, 2, 3])),
          chunk('JUNK', Uint8List.fromList([1, 2])),
        ],
      );
      expect(WaveData.decode(bytes).pcm, pcm16([0, 2000, -2000, 0]));
    });
    test('truncated RIFF and oversized chunk fail as FormatException', () {
      final truncated = wav();
      final badChunk = wav();
      ByteData.sublistView(badChunk).setUint32(40, 0xffffffff, Endian.little);
      for (final bytes in [
        Uint8List(0),
        Uint8List(43),
        Uint8List.sublistView(truncated, 0, truncated.length - 1),
        badChunk,
      ]) {
        expect(() => WaveData.decode(bytes), throwsFormatException);
      }
    });
    test('missing odd-sized chunk padding is rejected', () {
      final bytes = wav(
        extras: [
          chunk('JUNK', Uint8List.fromList([1]), pad: false),
        ],
      );
      expect(() => WaveData.decode(bytes), throwsFormatException);
    });
    test('partial chunk header inside declared RIFF is rejected', () {
      final original = wav();
      final bytes = Uint8List(original.length + 4)
        ..setRange(0, original.length, original);
      bytes.setRange(original.length, bytes.length, 'JUNK'.codeUnits);
      ByteData.sublistView(bytes).setUint32(4, bytes.length - 8, Endian.little);
      expect(() => WaveData.decode(bytes), throwsFormatException);
    });
    test(
      'compressed, floating, multichannel and invalid sample layouts fail',
      () {
        for (final bytes in [
          wav(format: 3),
          wav(format: 6),
          wav(bits: 8),
          wav(channels: 3),
          wav(rate: 0),
          wav(rate: 7999),
          wav(rate: 192001),
          wav(alignment: 4),
          wav(channels: 2, samples: pcm16([1])),
          wav(samples: Uint8List(0)),
          wav(samples: Uint8List(3)),
        ]) {
          expect(() => WaveData.decode(bytes), throwsFormatException);
        }
      },
    );
    test(
      'duration allows exactly five minutes and rejects the next sample',
      () {
        final max = Uint8List(WaveData.maxSeconds * 8000 * 2);
        expect(
          WaveData.decode(wav(rate: 8000, samples: max)).durationSeconds,
          300,
        );
        expect(
          () => WaveData.decode(
            wav(rate: 8000, samples: Uint8List(max.length + 2)),
          ),
          throwsFormatException,
        );
      },
    );
  });
}
