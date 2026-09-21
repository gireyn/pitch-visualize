import 'dart:math' as math;
import 'dart:typed_data';

import '../pitch_math.dart';

/// C1–C9, sampled uniformly in cents (72 rows per octave).
/// Values encode -90..0 dBFS as 0..255; row zero is the lowest frequency.
abstract final class LogSpectrum {
  static const minCents = 0.0;
  static const maxCents = 9600.0;
  static const bands = 576;
  static const floorDb = -90.0;
  static const centsPerBand = (maxCents - minCents) / bands;

  static double frequencyAt(double band) =>
      centsToFrequency(minCents + (band + .5) * centsPerBand);

  /// Converts a packed Hann-window FFT to a compact logarithmic spectrum.
  /// The single-sided amplitude correction is 4/N: a full-scale, bin-centred
  /// sinusoid measures 0 dBFS. This is amplitude, not a power spectral density.
  static Uint8List fromFft(Float64List packed, int sampleRate) {
    final size = packed.length;
    final binHz = sampleRate / size;
    final power = Float64List(size ~/ 2);
    for (var bin = 1; bin < power.length; bin++) {
      final real = packed[bin * 2], imaginary = packed[bin * 2 + 1];
      power[bin] = (real * real + imaginary * imaginary) * 16 / (size * size);
    }
    double interpolate(double bin) {
      final lower = bin.floor().clamp(1, power.length - 2);
      final fraction = (bin - lower).clamp(0.0, 1.0);
      return power[lower] * (1 - fraction) + power[lower + 1] * fraction;
    }

    final result = Uint8List(bands);
    for (var row = 0; row < bands; row++) {
      final lower = frequencyAt(row - .5) / binHz;
      final upper = frequencyAt(row + .5) / binHz;
      var peak = interpolate(frequencyAt(row.toDouble()) / binHz);
      // Wide high-frequency bands retain narrow harmonics between row centres.
      for (var bin = lower.ceil(); bin <= upper.floor(); bin++) {
        if (bin > 0 && bin < power.length) peak = math.max(peak, power[bin]);
      }
      final db = peak > 0 ? 10 * math.log(peak) / math.ln10 : floorDb;
      result[row] = ((db.clamp(floorDb, 0) - floorDb) / -floorDb * 255).round();
    }
    return result.asUnmodifiableView();
  }
}

class SpectrumPoint {
  const SpectrumPoint(this.sequence, this.seconds, this.bands);
  final int sequence;
  final double seconds;
  final Uint8List bands;
}
