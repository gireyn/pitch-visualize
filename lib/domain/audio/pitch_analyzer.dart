import 'dart:math' as math;
import 'dart:typed_data';

import '../pitch_math.dart';
import 'log_spectrum.dart';
import 'real_fft.dart';

/// The legacy 4096-point Hann FFT / autocorrelation pitch detector.
///
/// Feed mono, signed PCM16 at 44.1 kHz. Pitch is emitted every 1470 samples,
/// including an unvoiced -1 sentinel when energy or periodicity is insufficient.
class PitchAnalyzer {
  PitchAnalyzer({double threshold = 2}) {
    this.threshold = threshold;
    reset();
  }

  static const int sampleRate = 44100;
  static const int fftSize = 4096;
  static const int analyzeInterval = 1470;
  static const int historySize = 800;
  static const double intervalSeconds = analyzeInterval / sampleRate;
  static final double _maximumFrequency = c1Frequency * 128;
  static final Float64List _window = Float64List.fromList(
    List<double>.generate(
      fftSize,
      (i) => (0.5 - 0.5 * math.cos(2 * math.pi * i / fftSize)) / 32767,
    ),
  );

  final RealFft _fft = RealFft(fftSize);
  final Float64List _wave = Float64List(fftSize);
  final Float64List _spectrum = Float64List(fftSize);
  final Float64List _acf = Float64List(fftSize);
  final Float32List _history = Float32List(historySize);
  int _wavePosition = 0;
  int _intervalCount = 0;
  int _historyPosition = 0;
  int _totalFrames = 0;
  double _threshold = 2;
  double _peakFrequency = -1;
  double _intervalEnergy = 0;
  double _level = 0;
  Uint8List _logSpectrum = Uint8List(LogSpectrum.bands).asUnmodifiableView();

  double get threshold => _threshold;
  set threshold(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, 'threshold', 'Must be finite and >= 0');
    }
    _threshold = value;
  }

  double get peakFrequency => _peakFrequency;
  double get level => _level;
  Uint8List get spectrum => _logSpectrum;
  int get totalFrames => _totalFrames;
  int get historyPosition => _historyPosition;
  Float32List get pitchHistory => _history.asUnmodifiableView();

  /// Adds one PCM16 sample and returns whether a new frame is available.
  bool addSample(int sample) {
    if (sample < -32768 || sample > 32767) {
      throw RangeError.range(sample, -32768, 32767, 'sample');
    }
    _wave[_wavePosition] = sample.toDouble();
    _wavePosition = (_wavePosition + 1) % fftSize;
    final normalized = sample / 32768;
    _intervalEnergy += normalized * normalized;
    _intervalCount++;
    if (_intervalCount < analyzeInterval) return false;
    _level = math.sqrt(_intervalEnergy / analyzeInterval).clamp(0, 1);
    _intervalCount = 0;
    _intervalEnergy = 0;
    _analyze();
    return true;
  }

  /// Starts a clean recording with no samples or pitch history from the past.
  void reset() {
    _wave.fillRange(0, fftSize, 0);
    _spectrum.fillRange(0, fftSize, 0);
    _acf.fillRange(0, fftSize, 0);
    _history.fillRange(0, historySize, -1);
    _wavePosition = 0;
    _intervalCount = 0;
    _historyPosition = 0;
    _totalFrames = 0;
    _peakFrequency = -1;
    _intervalEnergy = 0;
    _level = 0;
    _logSpectrum = Uint8List(LogSpectrum.bands).asUnmodifiableView();
  }

  void _analyze() {
    for (var i = 0; i < fftSize; i++) {
      _spectrum[i] = _window[i] * _wave[(_wavePosition + i) % fftSize];
    }
    _fft.forward(_spectrum);
    _logSpectrum = LogSpectrum.fromFft(_spectrum, sampleRate);
    _acf[0] = _spectrum[0] * _spectrum[0];
    _acf[1] = _spectrum[1] * _spectrum[1];
    for (var k = 1; k < fftSize ~/ 2; k++) {
      _acf[2 * k] = _spectralPower(k);
      _acf[2 * k + 1] = 0;
    }
    _fft.inverse(_acf);
    _peakFrequency = math.sqrt(_acf[0]) >= threshold ? _detectPitch() : -1;
    _history[_historyPosition] = frequencyToCents(_peakFrequency);
    _historyPosition = (_historyPosition + 1) % historySize;
    _totalFrames++;
  }

  double _detectPitch() {
    var lag = (sampleRate / _maximumFrequency).toInt() - 1;
    var previousMaximum = _acfMaximum(lag, lag + 4);
    var bestMagnitude = 0.0;
    var bestLag = 0;
    var previousDifference = -1.0;
    while (lag < sampleRate / c1Frequency + 1) {
      final nextMaximum = _acfMaximum(lag + 1, lag + 5);
      final difference = nextMaximum - previousMaximum;
      if (difference < 0 &&
          previousDifference > 0 &&
          previousMaximum > bestMagnitude) {
        bestLag = lag;
        bestMagnitude = previousMaximum;
      }
      if (difference != 0) {
        previousMaximum = nextMaximum;
        previousDifference = difference;
      }
      lag++;
    }
    if (bestLag == 0 || bestMagnitude < _acf[0] * 0.5) return -1;

    var frequency = sampleRate / _interpolatedLag(bestLag);
    final fundamental = _fftMagnitudeNear(frequency);
    var corrected = frequency / 3;
    final twoThirds = _fftMagnitudeNear(corrected * 2);
    if (fundamental < 0.24 ||
        twoThirds <= 3.15 * fundamental ||
        corrected < c1Frequency) {
      final threeHalves = _fftMagnitudeNear(1.5 * frequency);
      if (fundamental >= 0.24 &&
          threeHalves > fundamental &&
          frequency / 2 >= c1Frequency) {
        corrected = frequency / 2;
      } else {
        corrected = frequency * 2;
        final second = _fftMagnitudeNear(corrected);
        final thirdFrequency = frequency * 3;
        final third = _fftMagnitudeNear(thirdFrequency);
        if (second < 0.24 ||
            second <= fundamental * 1.25 ||
            third >= second * 0.06 ||
            corrected > _maximumFrequency) {
          if (third >= 0.24 &&
              third > 1.25 * fundamental &&
              second < 0.06 * third &&
              thirdFrequency <= _maximumFrequency) {
            frequency = thirdFrequency;
          }
          if (math.sqrt(
                fundamental * fundamental + second * second + third * third,
              ) <
              0.7) {
            return -1;
          }
          corrected = frequency;
        }
      }
    }

    var contributions = 1;
    final harmonics = ((fftSize ~/ 2 - 1) / (sampleRate / corrected)).toInt();
    for (var harmonic = 2; harmonic <= harmonics; harmonic++) {
      final numerator = harmonic * sampleRate.toDouble();
      final center = (numerator / (corrected / contributions)).toInt();
      final upper = math.min(center + 3, fftSize ~/ 2 - 1);
      final lower = math.max(0, center - 3);
      var maximum = _acf[upper];
      var maximumLag = upper;
      for (var candidate = lower; candidate <= upper; candidate++) {
        if (_acf[candidate] >= maximum) {
          maximumLag = candidate;
          maximum = _acf[candidate];
        }
      }
      if (maximumLag != lower && maximumLag != upper) {
        corrected += numerator / _interpolatedLag(maximumLag);
        contributions++;
      }
    }
    var pitch = corrected / contributions;
    final spectralPitch = _interpolatedFftPeak(pitch);
    if (spectralPitch > 0) {
      final ratio = spectralPitch / pitch;
      if (ratio > 0.8 && ratio < 1.25) pitch = spectralPitch;
    }
    return pitch;
  }

  double _acfMaximum(int start, int end) {
    var maximum = _acf[start];
    for (var i = start + 1; i <= end; i++) {
      if (_acf[i] > maximum) maximum = _acf[i];
    }
    return maximum;
  }

  double _interpolatedLag(int lag) {
    final before = _acf[lag - 1];
    final center = _acf[lag];
    final after = _acf[lag + 1];
    final denominator = before - 2 * center + after;
    if (denominator != 0) {
      final delta = 0.5 * (before - after) / denominator;
      if (delta > -0.5 && delta < 0.5) return lag + delta;
    }
    return lag.toDouble();
  }

  double _spectralPower(int bin) {
    final real = _spectrum[2 * bin];
    final imaginary = _spectrum[2 * bin + 1];
    return real * real + imaginary * imaginary;
  }

  double _fftMagnitudeNear(double frequency) {
    const binHz = sampleRate / fftSize;
    final lower = (0.9791666666666666 * frequency / binHz).toInt().clamp(
      1,
      fftSize ~/ 2 - 2,
    );
    final upper = (1.0208333333333333 * frequency / binHz).toInt().clamp(
      lower,
      fftSize ~/ 2 - 2,
    );
    var best = lower;
    var maximum = 0.0;
    for (var bin = lower; bin <= upper; bin++) {
      final power = _spectralPower(bin);
      if (power > maximum) {
        best = bin;
        maximum = power;
      }
    }
    return math.sqrt(
      (maximum + _spectralPower(best - 1) + _spectralPower(best + 1)) / 3,
    );
  }

  double _interpolatedFftPeak(double frequency) {
    const binHz = sampleRate / fftSize;
    final lower = math.max(1, (frequency * 0.94 / binHz).toInt());
    final upper = math.min(
      fftSize ~/ 2 - 1,
      (frequency * 1.06 / binHz).toInt(),
    );
    if (upper <= lower) return -1;
    var best = lower;
    var maximum = -1.0;
    for (var bin = lower; bin <= upper; bin++) {
      final power = _spectralPower(bin);
      if (power > maximum) {
        best = bin;
        maximum = power;
      }
    }
    if (best <= 0 || best >= fftSize ~/ 2 - 1) return -1;
    final before = math.log(1 + _spectralPower(best - 1));
    final center = math.log(1 + maximum);
    final after = math.log(1 + _spectralPower(best + 1));
    final denominator = before - 2 * center + after;
    if (denominator == 0) return best * binHz;
    final delta = (0.5 * (before - after) / denominator).clamp(-0.5, 0.5);
    return (best + delta) * binHz;
  }
}
