import 'dart:typed_data';

/// Phase-preserving linear interpolation of a stream of PCM16 LE chunks.
///
/// Integer phase accumulation avoids drift and produces the same samples
/// regardless of chunk boundaries. At most one previous input sample is held.
class StreamingPcmResampler {
  StreamingPcmResampler(this.inputSampleRate, {this.outputSampleRate = 44100}) {
    _validateSampleRate(inputSampleRate);
    if (outputSampleRate != 44100) {
      throw ArgumentError('The analysis output sample rate must be 44100 Hz');
    }
  }

  static const maxChunkBytes = 192000;
  static const minInputSampleRate = 8000;
  static const maxInputSampleRate = 192000;
  final int inputSampleRate;
  final int outputSampleRate;
  int _inputSamples = 0;
  int _nextOutputNumerator = 0;
  int _previous = 0;

  Int16List addPcm(Uint8List pcm) {
    validatePcm(pcm, inputSampleRate);
    final input = ByteData.sublistView(pcm);
    final capacity =
        (pcm.length ~/ 2 * outputSampleRate / inputSampleRate).ceil() + 1;
    final output = Int16List(capacity);
    var count = 0;
    for (var offset = 0; offset < pcm.length; offset += 2) {
      final sample = input.getInt16(offset, Endian.little);
      final index = _inputSamples++;
      final endNumerator = index * outputSampleRate;
      while (_nextOutputNumerator <= endNumerator) {
        if (index == 0) {
          output[count++] = sample;
        } else {
          final fraction =
              (_nextOutputNumerator - (index - 1) * outputSampleRate) /
              outputSampleRate;
          output[count++] = (_previous + (sample - _previous) * fraction)
              .round()
              .clamp(-32768, 32767);
        }
        _nextOutputNumerator += inputSampleRate;
      }
      _previous = sample;
    }
    return Int16List.sublistView(output, 0, count);
  }

  void reset() {
    _inputSamples = 0;
    _nextOutputNumerator = 0;
    _previous = 0;
  }

  static void validatePcm(Uint8List pcm, int sampleRate) {
    _validateSampleRate(sampleRate);
    if (pcm.length.isOdd || pcm.length > maxChunkBytes) {
      throw ArgumentError(
        'PCM must be aligned PCM16 and <= $maxChunkBytes bytes',
      );
    }
  }

  static void _validateSampleRate(int sampleRate) {
    if (sampleRate < minInputSampleRate || sampleRate > maxInputSampleRate) {
      throw RangeError.range(
        sampleRate,
        minInputSampleRate,
        maxInputSampleRate,
        'sampleRate',
      );
    }
  }
}
