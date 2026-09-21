import 'dart:math' as math;

/// Reference C1 used by the original monitor, approximately 32.703 Hz.
final double c1Frequency = 55.0 * math.pow(2, -0.75);

/// Converts positive Hz to cents relative to C1. Invalid/unvoiced Hz is -1.
double frequencyToCents(double frequency) {
  if (!frequency.isFinite || frequency <= 0) return -1;
  return 1200 * math.log(frequency / c1Frequency) / math.ln2;
}

/// Converts cents relative to C1 to Hz, including notes below C1.
double centsToFrequency(double cents) =>
    cents.isFinite ? c1Frequency * math.pow(2, cents / 1200) : -1;
