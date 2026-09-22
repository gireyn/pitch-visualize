import 'package:flutter/foundation.dart';

@immutable
class MonitorSettings {
  static const minVerticalZoom = .5;
  static const maxVerticalZoom = 2.0;
  static const minEdo = 0;
  static const maxEdo = 72;

  const MonitorSettings({
    this.threshold = 2,
    this.horizontalZoom = 1,
    this.verticalZoom = 1,
    this.autoScroll = true,
    this.scrollSpeed = 5,
    this.showHz = true,
    this.showTuner = false,
    this.showSpectrum = true,
    this.smoothing = 3,
    this.bpm = 120,
    this.beatsPerBar = 4,
    this.showBeats = false,
    this.flashBeat = false,
    this.showHold = true,
    this.showScale = true,
    this.showTempo = true,
    this.edo = 12,
    this.pitchColor = 0xffffd75e,
    this.beatColor = 0xff495466,
    this.metronomeColor = 0xff326b69,
  });
  final double threshold, horizontalZoom, verticalZoom;
  final bool autoScroll, showHz, showTuner, showBeats, flashBeat;
  final bool showSpectrum;
  final bool showHold, showScale, showTempo;
  final int scrollSpeed, smoothing, bpm, beatsPerBar, edo;
  final int pitchColor, beatColor, metronomeColor;

  factory MonitorSettings.fromJson(Map<String, Object?> json) {
    Object? get(String name, String legacy) => json[name] ?? json[legacy];
    double number(
      String name,
      String legacy,
      double fallback,
      double min,
      double max,
    ) {
      final value = get(name, legacy);
      return value is num && value.isFinite
          ? value.toDouble().clamp(min, max)
          : fallback;
    }

    bool flag(String name, String legacy, bool fallback) =>
        switch (get(name, legacy)) {
          final bool value => value,
          _ => fallback,
        };
    int color(String name, String legacy, int fallback) =>
        switch (get(name, legacy)) {
          final int value => value | 0xff000000,
          _ => fallback,
        };
    final meter = get('beatsPerBar', 'key_meter');
    return MonitorSettings(
      threshold: number('threshold', 'key_threshold', 2, 0, 50),
      horizontalZoom: number(
        'horizontalZoom',
        'key_horizontal_zooming',
        1,
        1,
        2,
      ),
      verticalZoom: number(
        'verticalZoom',
        'key_vertical_zooming',
        1,
        minVerticalZoom,
        maxVerticalZoom,
      ),
      autoScroll: flag('autoScroll', 'key_auto_scroll', true),
      scrollSpeed: number('scrollSpeed', 'key_scroll_speed', 5, 1, 10).round(),
      showHz: flag('showHz', 'key_display_hz', true),
      showTuner: flag('showTuner', 'key_display_tuner', false),
      showSpectrum: flag('showSpectrum', 'showSpectrum', true),
      smoothing: number('smoothing', 'key_tuner_smooth', 3, 1, 5).round(),
      bpm: number('bpm', 'key_bpm', 120, 20, 250).round(),
      beatsPerBar: meter == 3 || meter == '3/4'
          ? 3
          : meter == 0 || meter == 'none'
          ? 0
          : 4,
      showBeats: flag('showBeats', 'key_display_bpm', false),
      flashBeat: flag('flashBeat', 'key_display_metronome', false),
      showHold: flag('showHold', 'key_display_button_hold', true),
      showScale: flag('showScale', 'key_display_button_scale', true),
      showTempo: flag('showTempo', 'key_display_button_tempo', true),
      edo: number(
        'edo',
        'key_edo',
        12,
        minEdo.toDouble(),
        maxEdo.toDouble(),
      ).round(),
      pitchColor: color('pitchColor', 'key_color_pitch', 0xffffd75e),
      beatColor: color('beatColor', 'key_color_tempo', 0xff495466),
      metronomeColor: color(
        'metronomeColor',
        'key_color_Metronome',
        0xff326b69,
      ),
    );
  }
  Map<String, Object?> toJson() => {
    'threshold': threshold,
    'horizontalZoom': horizontalZoom,
    'verticalZoom': verticalZoom,
    'autoScroll': autoScroll,
    'scrollSpeed': scrollSpeed,
    'showHz': showHz,
    'showTuner': showTuner,
    'showSpectrum': showSpectrum,
    'smoothing': smoothing,
    'bpm': bpm,
    'beatsPerBar': beatsPerBar,
    'showBeats': showBeats,
    'flashBeat': flashBeat,
    'showHold': showHold,
    'showScale': showScale,
    'showTempo': showTempo,
    'edo': edo,
    'pitchColor': pitchColor,
    'beatColor': beatColor,
    'metronomeColor': metronomeColor,
  };
  MonitorSettings withValue(String key, Object value) =>
      MonitorSettings.fromJson({...toJson(), key: value});
}
