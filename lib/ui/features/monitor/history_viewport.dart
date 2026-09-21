import 'dart:math' as math;

/// Fits the visible history, with room for vibrato and delayed contraction.
class HistoryViewport {
  bool _hasPitch = false;
  double? _shrinkSince;

  void reset() {
    _hasPitch = false;
    _shrinkSince = null;
  }

  ({double center, double range}) fit({
    required Iterable<double> pitches,
    required double time,
    required double center,
    required double range,
    required double minimumRange,
  }) {
    var low = double.infinity, high = double.negativeInfinity;
    for (final pitch in pitches) {
      if (!pitch.isFinite) continue;
      low = math.min(low, pitch);
      high = math.max(high, pitch);
    }
    if (!low.isFinite) {
      _shrinkSince = null;
      return (center: center, range: range);
    }

    // Quantized bounds avoid rescaling for every small pitch fluctuation.
    final padding = math.max(100.0, minimumRange * .1);
    low = ((low - padding) / 300).floor() * 300.0;
    high = ((high + padding) / 300).ceil() * 300.0;
    final fittedRange = math.max(minimumRange, high - low);
    final fittedCenter = center.clamp(
      high - fittedRange / 2,
      low + fittedRange / 2,
    );
    if (!_hasPitch) {
      _hasPitch = true;
      return (center: fittedCenter, range: fittedRange);
    }

    final start = center - range / 2, end = center + range / 2;
    if (low < start || high > end || range < minimumRange) {
      _shrinkSince = null;
      final expandedLow = math.min(low, start);
      final expandedHigh = math.max(high, end);
      return (
        center: (expandedLow + expandedHigh) / 2,
        range: math.max(minimumRange, expandedHigh - expandedLow),
      );
    }

    // Keep all visible notes. Only reclaim substantial unused space after
    // older extremes have left the time window and stayed absent for 2 s.
    if (fittedRange <= range * .75) {
      _shrinkSince ??= time;
      if (time - _shrinkSince! >= 2) {
        _shrinkSince = null;
        return (center: fittedCenter, range: fittedRange);
      }
    } else {
      _shrinkSince = null;
    }
    return (center: center, range: range);
  }
}
