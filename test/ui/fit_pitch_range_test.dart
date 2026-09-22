import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/audio/log_spectrum.dart';
import 'package:pitch_visual/domain/pitch_math.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';

import '../data/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late FakePlatformService platform;
  late FakePitchWorker worker;
  late MonitorController controller;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('pitch-fit-test-');
    platform = FakePlatformService(folder.path);
    worker = FakePitchWorker();
    controller = MonitorController(
      platform: platform,
      settingsRepository: SettingsRepository(platform),
      recordingRepository: RecordingRepository(platform),
      worker: worker,
    );
    await controller.initialize();
  });

  tearDown(() async {
    controller.dispose();
    await platform.close();
    await worker.close();
    await folder.delete(recursive: true);
  });

  double getRange() => controller.settings.showSpectrum
      ? LogSpectrum.maxCents / controller.settings.verticalZoom
      : controller.historyRange;

  void expectVisible(double cents) {
    expect(controller.centerCents - getRange() / 2, lessThanOrEqualTo(cents));
    expect(
      controller.centerCents + getRange() / 2,
      greaterThanOrEqualTo(cents),
    );
  }

  Uint8List spectrumAt(int low, int high) => Uint8List(LogSpectrum.bands)
    ..fillRange(0, LogSpectrum.bands, 8)
    ..[low] = 220
    ..[high] = 180;

  test(
    'fit shrinks or expands to visible history and keeps following',
    () async {
      await controller.updateSetting('showSpectrum', false);
      worker.frame(centsToFrequency(3600), 0);
      worker.frame(centsToFrequency(6000), 1);
      controller.adjustPitchRange(center: 1200, zoom: 1, baseRange: 9000);
      await controller.fitPitchRangeAndFollow();
      expect(controller.settings.autoScroll, isTrue);
      expect(controller.historyRange, lessThan(9000));
      expectVisible(3600);
      expectVisible(6000);

      controller.adjustPitchRange(center: 1200, zoom: 2, baseRange: 2400);
      await controller.fitPitchRangeAndFollow();
      expect(controller.historyRange, greaterThan(1200));
      expectVisible(3600);
      expectVisible(6000);
      worker.frame(centsToFrequency(8400), 2);
      expectVisible(8400);
      final saved = jsonDecode(platform.preferences!) as Map;
      expect((saved['settings'] as Map)['autoScroll'], isTrue);
    },
  );

  test(
    'fit immediately contracts even when following is already enabled',
    () async {
      await controller.updateSetting('showSpectrum', false);
      worker.frame(centsToFrequency(1200), 0);
      worker.frame(centsToFrequency(8400), 1);
      final expanded = controller.historyRange;
      worker.frame(centsToFrequency(8400), 21);
      expect(controller.historyRange, expanded);
      await controller.fitPitchRangeAndFollow();
      expect(controller.historyRange, 2400);
      expectVisible(8400);
    },
  );

  test(
    'spectrum fit uses visible energy without requiring detected pitch',
    () async {
      await controller.updateSetting('showSpectrum', true);
      worker.frame(-1, 0, spectrum: spectrumAt(0, 575));
      worker.frame(-1, 30, spectrum: spectrumAt(216, 360));
      controller.adjustPitchRange(center: 8500, zoom: 1);
      await controller.fitPitchRangeAndFollow();
      expect(controller.settings.autoScroll, isTrue);
      expect(controller.settings.verticalZoom, greaterThan(1));
      expectVisible(216 * LogSpectrum.centsPerBand);
      expectVisible(361 * LogSpectrum.centsPerBand);
      expect(controller.centerCents - getRange() / 2, greaterThan(0));
      expect(controller.centerCents + getRange() / 2, lessThan(9600));
      expect(controller.frequency, 0);
    },
  );

  test('spectrum fit widens for both edge bands and clamps to C1–C9', () async {
    await controller.updateSetting('showSpectrum', true);
    worker.frame(-1, 1, spectrum: spectrumAt(0, 575));
    controller.adjustPitchRange(center: 9000, zoom: 2);
    await controller.fitPitchRangeAndFollow();
    expect(controller.settings.verticalZoom, 1);
    expect(controller.centerCents, 4800);
    expectVisible(0);
    expectVisible(9600);
  });

  for (final spectrum in [false, true]) {
    test(
      'fit with no signal preserves the viewport (spectrum=$spectrum)',
      () async {
        await controller.updateSetting('showSpectrum', spectrum);
        worker.frame(-1, 1, spectrum: Uint8List(LogSpectrum.bands));
        controller.adjustPitchRange(center: 4500, zoom: 1.5);
        final beforeRange = getRange();
        await controller.fitPitchRangeAndFollow();
        expect(controller.settings.autoScroll, isTrue);
        expect(controller.centerCents, 4500);
        expect(getRange(), beforeRange);
      },
    );

    test(
      'fit uses frozen data and does not unfreeze (spectrum=$spectrum)',
      () async {
        await controller.updateSetting('showSpectrum', spectrum);
        worker.frame(centsToFrequency(3600), 1, spectrum: spectrumAt(216, 252));
        controller.currentTime = 1;
        controller.toggleHold();
        final frozenTime = controller.graphTime;
        worker.frame(
          centsToFrequency(9000),
          40,
          spectrum: spectrumAt(530, 550),
        );
        controller.adjustPitchRange(center: 0, zoom: 1);
        await controller.fitPitchRangeAndFollow();
        expect(controller.held, isTrue);
        expect(controller.graphTime, frozenTime);
        expect(controller.settings.autoScroll, isTrue);
        expectVisible(3600);
        expect(controller.centerCents + getRange() / 2, lessThan(9000));
        controller.toggleHold();
        expect(controller.held, isFalse);
        expect(controller.history, hasLength(2));
      },
    );
  }
}
