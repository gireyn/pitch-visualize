import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/domain/tuning/math_eval.dart';

void main() {
  group('MathEval', () {
    final expressions = <String, double>{
      '1/13*1901.9550008653873': 1901.9550008653873 / 13,
      'Math.pow(3/2,3)': 3.375,
      'MATH.pow(3, 2)': 9,
      '(1*1200*Math.log(3)/Math.LN2)': 1901.9550008653873,
      '2**3': 8,
      '2^3^2': 512,
      '-2^2': 4,
      '2^-2': 0.25,
      '3*(2+4)-1/2': 17.5,
      '+.5 + 1e-3 + 1.': 1.501,
      'Math.round(-1.5)': -1,
      'Math.round(1.5)': 2,
      'Math.trunc(-1.9)': -1,
      'Math.floor(-1.1)': -2,
      'Math.ceil(-1.1)': -1,
      'Math.sign(-5)': -1,
      'Math.abs(-5)': 5,
      'Math.sqrt(9)': 3,
      'Math.cbrt(-8)': -2,
      'Math.exp(0)': 1,
      'Math.log2(8)': 3,
      'Math.log10(100)': 2,
      'ln(Math.E)': 1,
      'Math.min(4,2,1)': 2,
      'Math.max(4,2,5)': 4,
      'Math.sin(Math.PI/2)': 1,
      'Math.cos(0)': 1,
      'Math.tan(0)': 0,
      'Math.asin(1)': math.pi / 2,
      'Math.acos(1)': 0,
      'Math.atan(1)': math.pi / 4,
      'Math.atan2(1,1)': math.pi / 4,
      'Math.sinh(0)': 0,
      'Math.cosh(0)': 1,
      'Math.tanh(0)': 0,
      'Math.hypot(3,4)': 5,
      'Math.LN10': math.ln10,
      'Math.LOG2E': 1 / math.ln2,
      'Math.LOG10E': 1 / math.ln10,
      'Math.SQRT2': math.sqrt2,
      'Math.SQRT1_2': 1 / math.sqrt2,
      'PI': math.pi,
      'any.prefix.POW(2,3)': 8,
    };
    for (final entry in expressions.entries) {
      test(entry.key, () {
        expect(MathEval.eval(entry.key), closeTo(entry.value, 1e-10));
      });
    }

    test('invalid expressions return NaN without executing code', () {
      for (final source in <String?>[
        null,
        '',
        ' ',
        '1+',
        '(1+2',
        '1e',
        '1.2.3',
        '1;2',
        'unknown(2)',
        'Math.min(2)',
        'Math.pow()',
        'Math.pow(2,)',
        'alert(1)',
        'Math.random()',
        'null',
        'true',
        'Math.PI garbage',
        '${'(' * 200}1${')' * 200}',
        '${'-' * 200}1',
        '1' * 9000,
      ]) {
        expect(MathEval.eval(source).isNaN, isTrue, reason: source);
      }
    });

    test('arithmetic can be infinite but scale import decides validity', () {
      expect(MathEval.eval('1/0'), double.infinity);
      expect(MathEval.eval('0/0').isNaN, isTrue);
    });
  });
}
