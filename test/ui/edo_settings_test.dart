import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';
import 'package:pitch_visual/l10n/l10n.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';
import 'package:pitch_visual/ui/features/settings/settings_screen.dart';

import '../data/fakes.dart';

void main() {
  testWidgets(
    'EDO preference is configurable and requires explicit activation',
    (tester) async {
      final platform = FakePlatformService('unused');
      final worker = FakePitchWorker();
      final controller = MonitorController(
        platform: platform,
        worker: worker,
        settingsRepository: SettingsRepository(platform),
        recordingRepository: RecordingRepository(platform),
      )..scale = ScaleConfig.parse('C4: 261.6255653\n0c 1200c\nC', 'Custom');
      addTearDown(() async {
        controller.dispose();
        await platform.close();
        await worker.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SettingsScreen(controller: controller),
        ),
      );
      expect(find.text('EDO 刻度'), findsOneWidget);
      expect(find.textContaining('当前优先使用调律配置'), findsOneWidget);
      final edoSlider = tester.widget<Slider>(find.byType(Slider).first);
      expect(edoSlider.min, 0);
      expect(edoSlider.max, 72);
      expect(edoSlider.divisions, 72);
      edoSlider.onChangeEnd!(19);
      await tester.pumpAndSettle();
      expect(controller.settings.edo, 19);
      expect(controller.scale!.name, 'Custom');

      await tester.tap(find.text('选择调律'));
      await tester.pumpAndSettle();
      expect(find.text('默认 · 七等分八度'), findsOneWidget);
      await tester.tap(find.text('使用 EDO 刻度'));
      await tester.pumpAndSettle();
      expect(controller.scale!.edo, 19);
      expect(find.textContaining('EDO 刻度生效'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
