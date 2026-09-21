import 'package:flutter/material.dart';

abstract final class SpectrumPalette {
  static const background = Color(0xff000000);
  static const colors = [
    Color(0xff020813),
    Color(0xff10283c),
    Color(0xff76400a),
    Color(0xfff48000),
    Color(0xffffd51c),
    Color(0xffffffed),
  ];
  static const stops = [0.0, .2, .4, .64, .84, 1.0];
  static const gradient = LinearGradient(colors: colors, stops: stops);
  static final rgba = List<int>.generate(256, (index) {
    final value = index / 255;
    var segment = 0;
    while (segment < stops.length - 2 && value > stops[segment + 1]) {
      segment++;
    }
    final color = Color.lerp(
      colors[segment],
      colors[segment + 1],
      (value - stops[segment]) / (stops[segment + 1] - stops[segment]),
    )!;
    return color.toARGB32();
  });
}
