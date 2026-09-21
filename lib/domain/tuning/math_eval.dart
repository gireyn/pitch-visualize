import 'dart:math' as math;

/// Evaluates the arithmetic expressions accepted by tuning configuration files.
///
/// Expressions never execute code. Invalid syntax produces [double.nan], as in
/// the original Android parser. Powers associate to the right; unary signs bind
/// before powers to preserve that parser's behavior.
abstract final class MathEval {
  static double eval(String? expression) {
    if (expression == null || expression.length > 8192) return double.nan;
    final source = expression.trim();
    if (source.isEmpty) return double.nan;
    try {
      final parser = _ExpressionParser(source);
      final result = parser.expression();
      parser.skipWhitespace();
      return parser.position == source.length ? result : double.nan;
    } on FormatException {
      return double.nan;
    } on RangeError {
      return double.nan;
    } on UnsupportedError {
      return double.nan;
    }
  }
}

class _ExpressionParser {
  _ExpressionParser(this.source);

  final String source;
  int position = 0;
  int _depth = 0;
  static final _number = RegExp(r'(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?');
  static final _identifier = RegExp(r'[a-zA-Z_][a-zA-Z_0-9.]*');

  void skipWhitespace() {
    while (position < source.length && ' \t\r\n'.contains(source[position])) {
      position++;
    }
  }

  bool _consume(String token) {
    skipWhitespace();
    if (!source.startsWith(token, position)) return false;
    position += token.length;
    return true;
  }

  double expression() {
    var value = _term();
    while (true) {
      if (_consume('+')) {
        value += _term();
      } else if (_consume('-')) {
        value -= _term();
      } else {
        return value;
      }
    }
  }

  double _term() {
    var value = _power();
    while (true) {
      if (_consume('*')) {
        value *= _power();
      } else if (_consume('/')) {
        value /= _power();
      } else {
        return value;
      }
    }
  }

  double _power() {
    _enter();
    try {
      final value = _unary();
      if (_consume('**') || _consume('^')) {
        return math.pow(value, _power()).toDouble();
      }
      return value;
    } finally {
      _depth--;
    }
  }

  double _unary() {
    _enter();
    try {
      if (_consume('-')) return -_unary();
      if (_consume('+')) return _unary();
      return _primary();
    } finally {
      _depth--;
    }
  }

  void _enter() {
    if (++_depth > 128) {
      throw const FormatException('Expression nesting is too deep');
    }
  }

  double _primary() {
    if (_consume('(')) {
      final value = expression();
      if (!_consume(')')) {
        throw const FormatException('Missing closing bracket');
      }
      return value;
    }
    skipWhitespace();
    final number = _number.matchAsPrefix(source, position);
    if (number != null) {
      position = number.end;
      return double.parse(number.group(0)!);
    }
    final identifier = _identifier.matchAsPrefix(source, position);
    if (identifier == null) throw const FormatException('Expected a value');
    position = identifier.end;
    final name = identifier.group(0)!.split('.').last.toLowerCase();
    if (!_consume('(')) return _constant(name);
    final arguments = <double>[];
    if (!_consume(')')) {
      do {
        final argument = expression();
        if (argument.isNaN) return double.nan;
        arguments.add(argument);
      } while (_consume(','));
      if (!_consume(')')) {
        throw const FormatException('Missing closing bracket');
      }
    }
    return _function(name, arguments);
  }

  static double _constant(String name) => switch (name) {
    'pi' => math.pi,
    'e' => math.e,
    'ln2' => math.ln2,
    'ln10' => math.ln10,
    'log2e' => 1 / math.ln2,
    'log10e' => 1 / math.ln10,
    'sqrt2' => math.sqrt2,
    'sqrt1_2' => 1 / math.sqrt2,
    _ => double.nan,
  };

  static double _function(String name, List<double> values) {
    // Fixed arity matches the old evaluator: extra arguments are ignored and
    // missing arguments are invalid rather than silently defaulting to zero.
    if (values.isEmpty) return double.nan;
    final a = values[0];
    if (const {'pow', 'min', 'max', 'atan2', 'hypot'}.contains(name)) {
      if (values.length < 2) return double.nan;
      final b = values[1];
      return switch (name) {
        'pow' => math.pow(a, b).toDouble(),
        'min' => math.min(a, b),
        'max' => math.max(a, b),
        'atan2' => math.atan2(a, b),
        'hypot' => _hypot(a, b),
        _ => double.nan,
      };
    }
    return switch (name) {
      'log' || 'ln' => math.log(a),
      'log2' => math.log(a) / math.ln2,
      'log10' => math.log(a) / math.ln10,
      'exp' => math.exp(a),
      'sqrt' => math.sqrt(a),
      'cbrt' => a.sign * math.pow(a.abs(), 1 / 3),
      'abs' => a.abs(),
      'floor' => a.floorToDouble(),
      'ceil' => a.ceilToDouble(),
      'round' => a.isFinite ? (a + 0.5).floorToDouble() : a,
      'trunc' => a.truncateToDouble(),
      'sign' => a.sign,
      'sin' => math.sin(a),
      'cos' => math.cos(a),
      'tan' => math.tan(a),
      'asin' => math.asin(a),
      'acos' => math.acos(a),
      'atan' => math.atan(a),
      'sinh' => (math.exp(a) - math.exp(-a)) / 2,
      'cosh' => (math.exp(a) + math.exp(-a)) / 2,
      'tanh' =>
        a > 20
            ? 1
            : (a < -20 ? -1 : (math.exp(2 * a) - 1) / (math.exp(2 * a) + 1)),
      _ => double.nan,
    };
  }

  static double _hypot(double a, double b) {
    final large = math.max(a.abs(), b.abs());
    final small = math.min(a.abs(), b.abs());
    if (large.isInfinite || large == 0) return large;
    return large * math.sqrt(1 + math.pow(small / large, 2));
  }
}
