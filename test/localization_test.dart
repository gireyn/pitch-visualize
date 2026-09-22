import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';
import 'package:pitch_visual/main.dart';
import 'package:pitch_visual/l10n/app_message.dart';
import 'package:pitch_visual/l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:pitch_visual/domain/models/wave_data.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_screen.dart';

import 'data/fakes.dart';

void main() {
  MonitorController controller() {
    final platform = FakePlatformService('unused');
    final worker = FakePitchWorker();
    addTearDown(platform.close);
    addTearDown(worker.close);
    return MonitorController(
        platform: platform,
        worker: worker,
        settingsRepository: SettingsRepository(platform),
        recordingRepository: RecordingRepository(platform),
      )
      ..initialized = true
      ..scale = ScaleConfig.parse(
        'C4: 261.6255653\n0\\7 1\\7 2\\7 3\\7 4\\7 5\\7 6\\7 7\\7\nC D E F G A B',
        '7ed2 on C',
      );
  }

  for (final (locales, expectedLanguage) in <(List<Locale>, String)>[
    ([const Locale('en', 'US')], 'en'),
    ([const Locale('en', 'GB')], 'en'),
    ([const Locale('zh', 'CN')], 'zh'),
    ([const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')], 'zh'),
    (
      [
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      ],
      'zh',
    ),
    ([const Locale('fr', 'FR')], 'en'),
    ([const Locale('ja'), const Locale('zh', 'CN')], 'zh'),
    (<Locale>[], 'en'),
  ]) {
    testWidgets('system locales $locales resolve to $expectedLanguage', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = locales;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        PitchVisualApp(controller: controller(), initialize: false),
      );
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(tester.element(find.byType(MonitorScreen)))
            .languageCode,
        expectedLanguage,
      );
      expect(
        find.byTooltip(expectedLanguage == 'zh' ? '开始监听' : 'Start listening'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('open settings and recording library follow locale changes', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final model = controller();
    await tester.pumpWidget(
      PitchVisualApp(controller: model, initialize: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('选择调律'), findsOneWidget);

    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('设置'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recordings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No recordings yet'), findsOneWidget);

    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    await tester.pumpAndSettle();
    expect(find.text('录音库'), findsOneWidget);
    expect(find.textContaining('还没有录音'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'visible status and error messages update with the system locale',
    (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final model = controller()
        ..message = AppMessage(
          (strings) => strings.noticeRecordingSaved('声乐.wav'),
        );
      await tester.pumpWidget(
        PitchVisualApp(controller: model, initialize: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recording saved: 声乐.wav'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = const [Locale('zh')];
      await tester.pumpAndSettle();
      expect(find.text('录音已保存：声乐.wav'), findsOneWidget);
      model.message = AppMessage.error(
        PlatformException(code: 'permissionDenied'),
      );
      model.toggleHold();
      await tester.pumpAndSettle();
      expect(find.textContaining('麦克风'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      await tester.pumpAndSettle();
      expect(find.textContaining('Microphone access'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('invalid WAV errors resolve in both languages', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final zh = await AppLocalizations.delegate.load(const Locale('zh'));
    Object? failure;
    try {
      WaveData.decode(Uint8List(0));
    } catch (error) {
      failure = error;
    }
    expect(failure, isFormatException);
    final message = AppMessage.error(failure!);
    expect(message.resolve(en), en.errorWavInvalidFile);
    expect(message.resolve(zh), zh.errorWavInvalidFile);
    expect(message.resolve(en), isNot(message.resolve(zh)));
    expect(en.scaleName('天干音阶'), 'Tiangan scale');
    expect(en.scaleName('My custom tuning'), 'My custom tuning');
  });

  test(
    'malformed tuning diagnostics are translated without losing inputs',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final zh = await AppLocalizations.delegate.load(const Locale('zh'));
      for (final source in [
        '',
        'C4 440\n0c 1200c',
        'C4: 0\n0c 1200c',
        'C4: 440\n0c',
        'C4: 440\nunrecognized-pitch 1200c',
        'C4: 440\n0c 0c',
        '甲4: 440\n0c 1200c\n乙',
      ]) {
        FormatException? failure;
        try {
          ScaleConfig.parse(source, 'Imported tuning');
        } on FormatException catch (error) {
          failure = error;
        }
        expect(failure, isNotNull);
        final message = AppMessage.error(failure!);
        expect(message.resolve(zh), isNot(contains(failure.message)));
        expect(message.resolve(en), isNot(message.resolve(zh)));
        if (source.contains('unrecognized-pitch')) {
          expect(message.resolve(en), contains('unrecognized-pitch'));
          expect(message.resolve(zh), contains('unrecognized-pitch'));
        }
      }
    },
  );

  for (final (size, textScale) in [
    (const Size(320, 568), 1.0),
    (const Size(812, 375), 1.0),
    (const Size(375, 812), 2.0),
  ]) {
    testWidgets('English UI fits $size at text scale $textScale', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      await tester.binding.setSurfaceSize(size);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        PitchVisualApp(controller: controller(), initialize: false),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Exercise the bottom sections as well as controls near the top.
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
