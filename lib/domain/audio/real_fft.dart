import 'dart:math' as math;
import 'dart:typed_data';

/// Reusable radix-2 real FFT with the original FFT4g packed representation.
///
/// The spectrum is [DC, Nyquist, Re(1), Im(1), ...]. Forward uses positive
/// imaginary sign; inverse is intentionally unnormalized: a round trip scales
/// samples by N/2, matching FFT4g and the analyzer's amplitude threshold.
class RealFft {
  RealFft(this.size) {
    if (size < 4 || (size & (size - 1)) != 0) {
      throw ArgumentError.value(size, 'size', 'Must be a power of two >= 4');
    }
    _real = Float64List(size);
    _imaginary = Float64List(size);
    _cosines = Float64List(size ~/ 2);
    _sines = Float64List(size ~/ 2);
    _reverse = Uint32List(size);
    final bits = size.bitLength - 1;
    for (var i = 0; i < size; i++) {
      var index = i;
      var reversed = 0;
      for (var bit = 0; bit < bits; bit++) {
        reversed = (reversed << 1) | (index & 1);
        index >>= 1;
      }
      _reverse[i] = reversed;
    }
    for (var i = 0; i < size ~/ 2; i++) {
      final angle = 2 * math.pi * i / size;
      _cosines[i] = math.cos(angle);
      _sines[i] = math.sin(angle);
    }
  }

  final int size;
  late final Float64List _real;
  late final Float64List _imaginary;
  late final Float64List _cosines;
  late final Float64List _sines;
  late final Uint32List _reverse;

  void forward(Float64List data) {
    _checkLength(data);
    _real.setAll(0, data);
    _imaginary.fillRange(0, size, 0);
    _transform(inverse: false);
    data[0] = _real[0];
    data[1] = _real[size ~/ 2];
    for (var k = 1; k < size ~/ 2; k++) {
      data[2 * k] = _real[k];
      data[2 * k + 1] = _imaginary[k];
    }
  }

  void inverse(Float64List data) {
    _checkLength(data);
    _real[0] = data[0];
    _real[size ~/ 2] = data[1];
    _imaginary[0] = 0;
    _imaginary[size ~/ 2] = 0;
    for (var k = 1; k < size ~/ 2; k++) {
      _real[k] = _real[size - k] = data[2 * k];
      _imaginary[k] = data[2 * k + 1];
      _imaginary[size - k] = -data[2 * k + 1];
    }
    _transform(inverse: true);
    for (var i = 0; i < size; i++) {
      data[i] = _real[i] * 0.5;
    }
  }

  void _checkLength(Float64List data) {
    if (data.length != size) {
      throw ArgumentError('FFT data must contain exactly $size values');
    }
  }

  void _transform({required bool inverse}) {
    for (var i = 0; i < size; i++) {
      final j = _reverse[i];
      if (i < j) {
        final real = _real[i];
        final imaginary = _imaginary[i];
        _real[i] = _real[j];
        _imaginary[i] = _imaginary[j];
        _real[j] = real;
        _imaginary[j] = imaginary;
      }
    }
    for (var length = 2; length <= size; length *= 2) {
      final half = length ~/ 2;
      final step = size ~/ length;
      for (var start = 0; start < size; start += length) {
        for (var offset = 0; offset < half; offset++) {
          final cosine = _cosines[offset * step];
          final sine = _sines[offset * step] * (inverse ? -1 : 1);
          final even = start + offset;
          final odd = even + half;
          final real = _real[odd] * cosine - _imaginary[odd] * sine;
          final imaginary = _real[odd] * sine + _imaginary[odd] * cosine;
          _real[odd] = _real[even] - real;
          _imaginary[odd] = _imaginary[even] - imaginary;
          _real[even] += real;
          _imaginary[even] += imaginary;
        }
      }
    }
  }
}
