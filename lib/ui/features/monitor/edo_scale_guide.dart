import 'dart:math' as math;

/// A built-in EDO guide line. [pitch] is measured in MIDI semitones.
class EdoScaleLine {
  const EdoScaleLine({
    required this.pitch,
    required this.ratio,
    required this.isAnchor,
    this.label,
  });

  final double pitch;
  final double ratio;
  final bool isAnchor;
  final String? label;
}

/// Smoothly thins dense EDO lines without letting octave anchors disappear.
abstract final class DenseLineVisibility {
  static const _epsilon = 0.0001;
  static const _minimumVisibleRatio = 0.02;

  static double ratioForStep({
    required int stepIndex,
    required double step,
    required double minimumPitchSpacing,
    bool isAnchor = false,
  }) {
    if (isAnchor) return 1;
    if (step <= _epsilon || minimumPitchSpacing <= _epsilon) return 1;
    final desiredStride = minimumPitchSpacing / step;
    if (!desiredStride.isFinite || desiredStride <= 1) return 1;

    final fineStride = math.max(1, desiredStride.floor());
    final coarseStride = math.max(1, desiredStride.ceil());
    if (fineStride == coarseStride) {
      return _positiveModulo(stepIndex, coarseStride) == 0 ? 1 : 0;
    }

    final fineWeight = _smoothStep(
      (coarseStride - desiredStride).clamp(0.0, 1.0),
    );
    final coarseWeight = 1 - fineWeight;
    var ratio = 0.0;
    if (_positiveModulo(stepIndex, fineStride) == 0) {
      ratio = math.max(ratio, fineWeight);
    }
    if (_positiveModulo(stepIndex, coarseStride) == 0) {
      ratio = math.max(ratio, coarseWeight);
    }
    return ratio >= _minimumVisibleRatio ? ratio : 0;
  }

  static double _smoothStep(double value) => value * value * (3 - 2 * value);

  static int _positiveModulo(int value, int modulus) {
    final result = value % modulus;
    return result < 0 ? result + modulus : result;
  }
}

/// Built-in 0–72 EDO ruler patterns migrated from XenSynth.
abstract final class EdoScaleGuide {
  static const _octaveSemitones = 12.0;
  static const _hiddenMark = 'N';
  static const _markRatios = <String, double>{
    '0': 1,
    '1': 0.8,
    '2': 0.6,
    '3': 0.4,
    '4': 0.2,
    _hiddenMark: 0,
    'S': 0,
  };

  static final Map<int, String> _patterns = _buildPatterns();

  static bool hasScale(int edo) => _patterns.containsKey(math.max(0, edo));

  /// Includes one neighboring step at each edge for clipped drawing.
  /// All pitch values and spacing use MIDI semitones, with C4 at 60.
  static Iterable<EdoScaleLine> linesForRange({
    required int edo,
    required double minimumPitch,
    required double maximumPitch,
    double minimumPitchSpacing = 0,
  }) sync* {
    final normalizedEdo = math.max(0, edo);
    final pattern = _patterns[normalizedEdo];
    if (pattern == null || pattern.isEmpty || maximumPitch < minimumPitch) {
      return;
    }
    final stepCount = normalizedEdo > 0 ? normalizedEdo : 1;
    final step = _octaveSemitones / stepCount;
    final firstStep = (minimumPitch / step).floor() - 1;
    final lastStep = (maximumPitch / step).floor() + 1;
    for (var stepIndex = firstStep; stepIndex <= lastStep; stepIndex++) {
      final pitch = stepIndex * step;
      if (pitch < minimumPitch - step || pitch > maximumPitch + step) {
        continue;
      }
      final octaveStep = _positiveModulo(stepIndex, stepCount);
      final marker = octaveStep < pattern.length
          ? pattern[octaveStep]
          : _hiddenMark;
      final markRatio = _markRatios[marker] ?? 0;
      if (markRatio <= 0) continue;
      final isAnchor = octaveStep == 0;
      final visibilityRatio = DenseLineVisibility.ratioForStep(
        stepIndex: stepIndex,
        step: step,
        minimumPitchSpacing: minimumPitchSpacing,
        isAnchor: isAnchor,
      );
      final ratio = markRatio * visibilityRatio;
      if (ratio <= 0) continue;
      yield EdoScaleLine(
        pitch: pitch,
        ratio: ratio.clamp(0.0, 1.0),
        isAnchor: isAnchor,
        label: isAnchor && (pitch - 60).abs() <= 0.0001 ? 'C4' : null,
      );
    }
  }

  static int _positiveModulo(int value, int modulus) {
    final result = value % modulus;
    return result < 0 ? result + modulus : result;
  }

  static Map<int, String> _buildPatterns() {
    final result = <int, String>{};
    for (final row in _patternTable.trim().split('\n')) {
      final separator = row.indexOf('|');
      if (separator <= 0) continue;
      final edo = int.tryParse(row.substring(0, separator));
      if (edo != null) result[edo] = row.substring(separator + 1);
    }
    return Map.unmodifiable(result);
  }

  static const _patternTable = '''
0|0N
1|0N
2|01
3|011
4|0111
5|01111
6|011111
7|0111111
8|02121212
9|022122122
10|0212121212
11|02121121121
12|021211212121
13|0212112121121
14|02121212121212
15|022122122122122
16|0323132313231323
17|02212211221221221
18|021212121212121212
19|0221221212212212212
20|03231331132313313231
21|022122122122122122122
22|0323132311323132313231
23|03323323332331332332333
24|032313231313231323132313
25|0332332332323321323323323
26|03231323133132313231323133
27|033332333322333313333233332
28|0323132313231323132313231323
29|03333233332323333133332333323
30|033332333233323333133323332333
31|0333323333233233331333323333233
32|03231323132313231323132313231323
33|033332333323332333313333233332333
34|0323231323231313232313232313232313
35|03333233332333323333133332333323333
36|033233233233133133233233233133233133
37|0332331332331133233133233133233133233
38|03232313232313231323231323231323231323
39|033333323333332323333331333333233333323
40|0332331332331333313323313323313323313333
41|03333332333333233233333313333332333333233
42|033323331333233311333233313332333133323331
43|0333333233333323332333333133333323333332333
44|03332333133323331313332333133323331333233313
45|033333323333332333323333331333333233333323333
46|0333233313332333133133323331333233313332333133
47|03333332333333233333233333313333332333333233333
48|033323331333233313331333233313332333133323331333
49|0332332331332332331313323323313323323313323323313
50|03332333133323331333313332333133323331333233313333
51|033233233133233233133133233233133233233133233233133
52|0333233313332333133333133323331333233313332333133333
53|03333333323333333323332333333331333333332333333332333
54|033323331333233313333331333233313332333133323331333333
55|0332332331332332331333313323323313323323313323323313333
56|03333233331333323333133133332333313333233331333323333133
57|033233233133233233133233133233233133233233133233233133233
58|0333323333133332333313331333323333133332333313333233331333
59|04424344144243441442434414424434244144342441443424414434244
60|044443444424444344442444424444344441444434444244443444424444
61|0333333333323333333333233233333333331333333333323333333333233
62|04343434342434343434243434243434343414343434342434343434243434
63|033333333332333333333323332333333333313333333333233333333332333
64|0434243414342434143424341434243414342434143424341434243414342434
65|03333333333233333333332333323333333333133333333332333333333323333
66|043434343424343434342434343424343434143434343424343434342434343424
67|0333333333323333333333233333233333333331333333333323333333333233333
68|04342434243414342434243414341434243424341434243424341434243424341434
69|033333333332333333333323333332333333333313333333333233333333332333333
70|0444443444442444443444442444424444434444414444434444424444434444424444
71|03333333333332333333333333233233333333333313333333333332333333333333233
72|044344244344144344244344144344144344244344144344244344144344244344144344
''';
}
