import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/models/monitor_settings.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePlatformService platform;
  late SettingsRepository repository;
  setUp(() {
    platform = FakePlatformService('unused');
    repository = SettingsRepository(platform);
  });
  tearDown(() async {
    await platform.close();
  });
  final custom = ScaleConfig.parse('甲4: 320\n0c 100c 3\n甲 乙', 'Custom');

  test(
    'missing preferences load default settings and bundled tuning',
    () async {
      final loaded = await repository.load();
      expect(loaded.settings.toJson(), const MonitorSettings().toJson());
      expect(loaded.scale.name, '7ed2 on C');
      expect(loaded.notice, isNull);
    },
  );
  test('source and payload persist with every setting', () async {
    const settings = MonitorSettings(bpm: 183, showBeats: true);
    await repository.save(settings, custom);
    final loaded = await repository.load();
    expect(loaded.settings.toJson(), settings.toJson());
    expect(loaded.scale.toPayload(), custom.toPayload());
    expect(loaded.scale.source, custom.source);
    expect(loaded.notice, isNull);
  });
  test('legacy flat preferences retain tuning cache and meter', () async {
    platform.preferences = jsonEncode({
      'key_bpm': 160,
      'key_meter': '3/4',
      'key_config_payload': custom.toPayload(),
    });
    final loaded = await repository.load();
    expect(loaded.settings.bpm, 160);
    expect(loaded.settings.beatsPerBar, 3);
    expect(loaded.scale.name, 'Custom');
  });
  test(
    'invalid source falls back to its intact cached scale with notice',
    () async {
      platform.preferences = jsonEncode({
        'settings': {'bpm': 155},
        'scaleSource': 'broken',
        'scalePayload': custom.toPayload(),
      });
      final loaded = await repository.load();
      expect(loaded.scale.name, 'Custom');
      expect(loaded.settings.bpm, 155);
      expect(loaded.notice, isNotNull);
    },
  );
  test(
    'source and cache corruption preserves valid preferences but defaults tuning',
    () async {
      platform.preferences = jsonEncode({
        'settings': {'bpm': 155},
        'scaleSource': 'broken',
        'scalePayload': 'broken',
      });
      final loaded = await repository.load();
      expect(loaded.settings.bpm, 155);
      expect(loaded.scale.name, '7ed2 on C');
      expect(loaded.notice, isNotNull);
    },
  );
  test(
    'broken JSON and native read errors recover with a visible notice',
    () async {
      for (final raw in ['{', '[]', 'null', '17']) {
        platform.preferences = raw;
        final loaded = await repository.load();
        expect(loaded.scale.name, '7ed2 on C');
        expect(loaded.notice, isNotNull);
      }
      platform.preferencesError = StateError('Storage unavailable');
      expect((await repository.load()).notice, isNotNull);
    },
  );
  test(
    'save failure propagates so the caller can keep previous settings',
    () async {
      platform.saveError = StateError('Storage full');
      await expectLater(
        repository.save(const MonitorSettings(), custom),
        throwsStateError,
      );
    },
  );
}
