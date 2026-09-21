import 'dart:math' as math;

import 'math_eval.dart';

/// A named degree of a tuning at a particular register.
class ScaleNote {
  const ScaleNote({
    required this.index,
    required this.register,
    required this.cents,
    required this.label,
    required this.frequency,
  });

  final int index;
  final int register;
  final double cents;
  final String label;
  final double frequency;
}

/// A tuning-config scale, including non-octave equaves and custom note names.
class ScaleConfig {
  ScaleConfig._({
    required this.name,
    required List<String> names,
    required List<double> cents,
    required this.periodCents,
    required this.referenceFrequency,
    required this.referenceOctave,
    required this.referenceName,
    required this.referenceIndex,
    required this.source,
    List<int>? colors,
  }) : names = List.unmodifiable(names),
       cents = List.unmodifiable(cents),
       colors = colors == null ? null : List.unmodifiable(colors);

  final String name;
  final List<String> names;
  final List<double> cents;
  final double periodCents;
  final double referenceFrequency;
  final int referenceOctave;
  final String referenceName;
  final int referenceIndex;
  final List<int>? colors;

  /// Original imported text; empty for a restored legacy cache payload.
  final String source;

  static const c1Frequency = 32.70319566257483;
  static final _whitespace = RegExp(r'\s+');
  static final _standardName = RegExp(r'^[a-gA-G][0-9#♯b♭x]*$');

  /// Absolute cents of the nominal zero at the reference register.
  double get baseCents =>
      (_log2(referenceFrequency) - _log2(c1Frequency)) * 1200 -
      cents[referenceIndex];

  /// Parses a config or throws [FormatException] with an import diagnostic.
  static ScaleConfig parse(String text, String displayName) {
    if (text.length > 1024 * 1024) {
      throw const FormatException('Tuning config is larger than 1 MB');
    }
    var normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.startsWith('\uFEFF')) normalized = normalized.substring(1);
    final lines = normalized
        .split('\n')
        .map((line) => line.split('//').first.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2) {
      throw const FormatException(
        'Need at least a reference note line and a pitch line',
      );
    }
    final colon = lines.first.indexOf(':');
    if (colon < 0) {
      throw const FormatException('Reference note must look like "甲4: 320"');
    }
    final refSpec = lines.first.substring(0, colon).trim();
    final freqText = lines.first.substring(colon + 1).trim();
    final frequency = MathEval.eval(freqText);
    if (!frequency.isFinite || frequency <= 0) {
      throw FormatException('Invalid reference frequency: $freqText');
    }
    final registerMatch = RegExp(r'\d+$').firstMatch(refSpec);
    final register = registerMatch == null
        ? 4
        : int.tryParse(registerMatch.group(0)!) ?? 4;
    final refName = registerMatch == null
        ? refSpec
        : refSpec.substring(0, registerMatch.start);
    final pitchTokens = lines[1].split(_whitespace);
    if (pitchTokens.length < 2) {
      throw const FormatException(
        'Need at least one scale pitch and an equave',
      );
    }
    if (pitchTokens.length > 4097) {
      throw const FormatException('A tuning can contain at most 4096 notes');
    }
    final pitches = <double>[];
    for (final token in pitchTokens) {
      final value = parseCentsOrRatio(token);
      if (value == null) throw FormatException('Cannot parse pitch: $token');
      pitches.add(value);
    }
    final period = pitches.removeLast();
    if (period == 0) {
      throw const FormatException('Equave size must be non-zero');
    }
    var namesEnd = lines.length;
    List<int>? colors;
    if (lines.length > 2) {
      final tokens = lines.last.split(_whitespace);
      final grayscale = tokens.map(_grayscale).toList();
      if (tokens.length <= pitches.length &&
          grayscale.every((color) => color != null)) {
        colors = grayscale
            .cast<int>()
            .map((v) => 0xff000000 | v * 0x010101)
            .toList();
        namesEnd--;
      }
    }
    final nameTokens = lines.sublist(2, namesEnd).join(' ').trim();
    final tokens = nameTokens.isEmpty
        ? <String>[]
        : nameTokens.split(_whitespace);
    final names = List<String>.generate(
      pitches.length,
      (index) =>
          tokens.isEmpty ? '${index + 1}' : tokens[index % tokens.length],
    );
    var referenceIndex = names.indexOf(refName);
    if (referenceIndex < 0 && _standardName.hasMatch(refName)) {
      referenceIndex = 0;
    }
    if (referenceIndex < 0) {
      throw FormatException('Reference note "$refName" is not a scale note');
    }
    return ScaleConfig._(
      name: displayName,
      names: names,
      cents: pitches,
      periodCents: period,
      referenceFrequency: frequency,
      referenceOctave: register,
      referenceName: refName,
      referenceIndex: referenceIndex,
      source: text,
      colors: colors,
    );
  }

  /// Converts cents, ratios and equal divisions into a finite cent value.
  static double? parseCentsOrRatio(String? token) {
    if (token == null) return null;
    final text = token.trim();
    double offset;
    if (text.endsWith('c')) {
      offset = MathEval.eval(text.substring(0, text.length - 1));
    } else if (text.endsWith('me')) {
      offset =
          MathEval.eval(text.substring(0, text.length - 2)) / math.ln2 * 1.2;
    } else if (text.startsWith('ie')) {
      final value = double.tryParse(text.substring(2).trim());
      if (value == null || value == 0) return null;
      offset = 1000 / value / math.ln2 * 1.2;
    } else if (text.contains(r'\') || text.contains('ed')) {
      final parts = text.split(RegExp(r'\\|ed'));
      // String.split in Java drops trailing empty strings.
      while (parts.isNotEmpty && parts.last.isEmpty) {
        parts.removeLast();
      }
      if (parts.length < 2 ||
          parts.length > 3 ||
          parts[0].isEmpty ||
          parts[1].isEmpty) {
        return null;
      }
      final numerator = MathEval.eval(parts[0]);
      final denominator = MathEval.eval(parts[1]);
      final equave = parts.length == 3 ? MathEval.eval(parts[2]) : 2.0;
      if (denominator == 0 || equave <= 0) return null;
      offset = numerator * 1200 * _log2(equave) / denominator;
    } else {
      final ratio = MathEval.eval(text);
      offset = ratio == 0 ? 0 : ratio.sign * _log2(ratio.abs()) * 1200;
    }
    return offset.isFinite ? offset : null;
  }

  int colorFor(int index) {
    final palette = colors;
    if (palette != null && palette.isNotEmpty) {
      return palette[index % palette.length];
    }
    return index == 0 ? 0xff888888 : 0xff545454;
  }

  ScaleNote noteAt(int index, int register) {
    RangeError.checkValidIndex(index, cents);
    final relative =
        cents[index] -
        cents[referenceIndex] +
        (register - referenceOctave) * periodCents;
    return ScaleNote(
      index: index,
      register: register,
      cents:
          baseCents + cents[index] + (register - referenceOctave) * periodCents,
      label: '${names[index]}$register',
      frequency: referenceFrequency * math.pow(2, relative / 1200),
    );
  }

  ScaleNote nearestNote(double absoluteCents) {
    if (!absoluteCents.isFinite) {
      throw ArgumentError.value(
        absoluteCents,
        'absoluteCents',
        'Must be finite',
      );
    }
    ScaleNote? best;
    var bestDeviation = double.infinity;
    for (var index = 0; index < cents.length; index++) {
      final relative = absoluteCents - baseCents - cents[index];
      // Java Math.round resolves negative midpoint ties towards +infinity.
      final register = (relative / periodCents + 0.5).floor() + referenceOctave;
      final note = noteAt(index, register);
      final deviation = (absoluteCents - note.cents).abs();
      if (deviation < bestDeviation) {
        best = note;
        bestDeviation = deviation;
      }
    }
    return best!;
  }

  /// Returns the grid notes in a finite visible cent range, sorted by pitch.
  List<ScaleNote> notesBetween(double minimumCents, double maximumCents) {
    if (!minimumCents.isFinite || !maximumCents.isFinite) {
      throw ArgumentError('Note range must be finite');
    }
    if (maximumCents < minimumCents) return const [];
    final notes = <ScaleNote>[];
    for (var index = 0; index < cents.length; index++) {
      final first = (minimumCents - baseCents - cents[index]) / periodCents;
      final last = (maximumCents - baseCents - cents[index]) / periodCents;
      final lower = math.min(first, last).ceil() + referenceOctave;
      final upper = math.max(first, last).floor() + referenceOctave;
      if (upper - lower + notes.length > 20000) {
        throw RangeError('The visible range contains too many scale notes');
      }
      for (var register = lower; register <= upper; register++) {
        notes.add(noteAt(index, register));
      }
    }
    notes.sort((a, b) => a.cents.compareTo(b.cents));
    return notes;
  }

  /// Serializes a cache compatible with the original Android XENCFG1 format.
  String toPayload() {
    final lines = [
      'XENCFG1',
      name.replaceAll(RegExp(r'[\r\n]'), ' '),
      referenceName,
      '$referenceIndex',
      '$referenceOctave',
      '$referenceFrequency',
      '$periodCents',
      '${cents.length}',
      cents.join(' '),
      names.join(' '),
      if (colors != null)
        'colors ${colors!.map((v) => (v >> 16) & 0xff).join(' ')}',
    ];
    return lines.join('\n');
  }

  /// Restores a legacy cache. Corrupt or non-finite payloads return null.
  static ScaleConfig? fromPayload(String? payload) {
    if (payload == null || payload.length > 1024 * 1024) return null;
    try {
      final lines = payload.split('\n');
      if (lines.length < 9 || lines[0] != 'XENCFG1') return null;
      final count = int.parse(lines[7]);
      final referenceIndex = int.parse(lines[3]);
      final referenceOctave = int.parse(lines[4]);
      final frequency = double.parse(lines[5]);
      final period = double.parse(lines[6]);
      if (count < 1 ||
          count > 4096 ||
          referenceIndex < 0 ||
          referenceIndex >= count ||
          !frequency.isFinite ||
          frequency <= 0 ||
          !period.isFinite ||
          period == 0) {
        return null;
      }
      final values = lines[8].trim().split(_whitespace);
      if (values.length < count) return null;
      final cents = values.take(count).map(double.parse).toList();
      if (cents.any((value) => !value.isFinite)) return null;
      final nameTokens = lines.length < 10
          ? <String>[]
          : lines[9].trim().split(_whitespace);
      final names = List<String>.generate(
        count,
        (i) => i < nameTokens.length && nameTokens[i].isNotEmpty
            ? nameTokens[i]
            : '${i + 1}',
      );
      List<int>? colors;
      if (lines.length > 10 && lines[10].startsWith('colors')) {
        final tokens = lines[10].substring(6).trim().split(_whitespace);
        final values = tokens.map(_grayscale).toList();
        if (values.any((value) => value == null)) return null;
        colors = values
            .cast<int>()
            .map((v) => 0xff000000 | v * 0x010101)
            .toList();
      }
      return ScaleConfig._(
        name: lines[1],
        names: names,
        cents: cents,
        periodCents: period,
        referenceFrequency: frequency,
        referenceOctave: referenceOctave,
        referenceName: lines[2],
        referenceIndex: referenceIndex,
        source: '',
        colors: colors,
      );
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  static int? _grayscale(String token) {
    if (!RegExp(r'^[0-9]{1,3}$').hasMatch(token)) return null;
    final value = int.parse(token);
    return value <= 255 ? value : null;
  }

  static double _log2(double value) => math.log(value) / math.ln2;
}
