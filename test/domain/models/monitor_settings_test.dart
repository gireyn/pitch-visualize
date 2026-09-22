import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/domain/models/monitor_settings.dart';

void main() {
  test('settings JSON round trip preserves every preference', () {
    const settings = MonitorSettings(
      threshold: 8,
      horizontalZoom: 2,
      verticalZoom: .5,
      autoScroll: false,
      scrollSpeed: 9,
      showHz: false,
      showTuner: false,
      showSpectrum: false,
      smoothing: 5,
      bpm: 234,
      beatsPerBar: 3,
      showBeats: true,
      flashBeat: true,
      showHold: false,
      showScale: false,
      showTempo: false,
      edo: 31,
      pitchColor: 0xff123456,
      beatColor: 0xff334455,
      metronomeColor: 0xff8899aa,
    );
    final json = Map<String, Object?>.from(
      jsonDecode(jsonEncode(settings.toJson())) as Map,
    );
    expect(MonitorSettings.fromJson(json).toJson(), settings.toJson());
  });
  test('legacy Android key mapping and meter values survive migration', () {
    final settings = MonitorSettings.fromJson({
      'key_threshold': 3.5,
      'key_horizontal_zooming': 2,
      'key_vertical_zooming': .5,
      'key_auto_scroll': false,
      'key_scroll_speed': 6,
      'key_display_hz': false,
      'key_display_tuner': false,
      'key_tuner_smooth': 4,
      'key_bpm': 180,
      'key_meter': '3/4',
      'key_edo': 19,
      'key_display_bpm': true,
      'key_display_metronome': true,
      'key_display_button_hold': false,
      'key_display_button_scale': false,
      'key_display_button_tempo': false,
      'key_color_pitch': 0x123456,
      'key_color_tempo': 0x334455,
      'key_color_Metronome': 0x8899aa,
    });
    expect(settings.threshold, 3.5);
    expect(settings.horizontalZoom, 2);
    expect(settings.verticalZoom, .5);
    expect(settings.autoScroll, isFalse);
    expect(settings.scrollSpeed, 6);
    expect(settings.showHz, isFalse);
    expect(settings.showTuner, isFalse);
    expect(settings.smoothing, 4);
    expect(settings.bpm, 180);
    expect(settings.beatsPerBar, 3);
    expect(settings.edo, 19);
    expect(settings.showBeats, isTrue);
    expect(settings.flashBeat, isTrue);
    expect(settings.showHold, isFalse);
    expect(settings.showScale, isFalse);
    expect(settings.showTempo, isFalse);
    expect(settings.pitchColor, 0xff123456);
    expect(settings.beatColor, 0xff334455);
    expect(settings.metronomeColor, 0xff8899aa);
    expect(MonitorSettings.fromJson({'key_meter': 'none'}).beatsPerBar, 0);
    expect(MonitorSettings.fromJson({'key_meter': '4/4'}).beatsPerBar, 4);
  });
  test(
    'invalid and out of range settings normalize without losing other fields',
    () {
      final settings = MonitorSettings.fromJson({
        'threshold': double.nan,
        'bpm': 9999,
        'scrollSpeed': -3,
        'smoothing': 'bad',
        'showHz': 0,
        'horizontalZoom': double.infinity,
        'verticalZoom': 8,
        'pitchColor': 'not-a-color',
        'showTempo': false,
      });
      expect(settings.threshold, 2);
      expect(settings.bpm, 250);
      expect(settings.scrollSpeed, 1);
      expect(settings.smoothing, 3);
      expect(settings.showHz, isTrue);
      expect(settings.horizontalZoom, 1);
      expect(settings.verticalZoom, 2);
      expect(settings.pitchColor, const MonitorSettings().pitchColor);
      expect(settings.showTempo, isFalse);
    },
  );
  test('withValue changes only its selected preference', () {
    const settings = MonitorSettings();
    expect(settings.withValue('bpm', 160).toJson(), {
      ...settings.toJson(),
      'bpm': 160,
    });
    expect(settings.bpm, 120);
  });
  test('EDO defaults and malformed preferences normalize to 0 through 72', () {
    expect(const MonitorSettings().edo, 12);
    for (final value in [null, 'bad', double.nan, double.infinity]) {
      expect(MonitorSettings.fromJson({'edo': value}).edo, 12);
    }
    expect(MonitorSettings.fromJson({'edo': -3}).edo, 0);
    expect(MonitorSettings.fromJson({'edo': 100}).edo, 72);
    expect(MonitorSettings.fromJson({'edo': 19.8}).edo, 20);
  });
}
