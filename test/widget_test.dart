import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/main.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/data/services/platform_service.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';

class _Platform extends PlatformService {
  @override
  Future<void> stopCapture() async {}
  @override
  Future<void> stopPlayback() async {}
  @override
  Future<void> setKeepScreenOn(bool enabled) async {}
  @override
  Future<void> savePreferences(String json) async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.localesTestValue = const [Locale('zh')];
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);
  });
  MonitorController controller() {
    final platform = _Platform();
    return MonitorController(
        platform: platform,
        settingsRepository: SettingsRepository(platform),
        recordingRepository: RecordingRepository(platform),
      )
      ..initialized = true
      ..scale = ScaleConfig.parse(
        'C4: 261.6255653\n0\\7 1\\7 2\\7 3\\7 4\\7 5\\7 6\\7 7\\7\nC D E F G A B',
        '7ed2 on C',
      );
  }

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1024, 768),
    const Size(320, 568),
  ]) {
    testWidgets('Monitor has no overflow at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final model = controller();
      await tester.pumpWidget(
        PitchVisualApp(controller: model, initialize: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pitch Visual'), findsOneWidget);
      expect(find.byTooltip('开始监听'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('冻结图表'));
      await tester.tap(find.byTooltip('冻结图表'));
      await tester.pump();
      expect(model.held, isTrue);
      expect(find.byTooltip('继续图表'), findsOneWidget);
      await tester.tap(find.byTooltip('录音库'));
      await tester.pumpAndSettle();
      expect(find.textContaining('还没有录音'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Dense imported equave remains renderable', (tester) async {
    final model = controller()
      ..scale = ScaleConfig.parse(
        'C4: 261.6255653\n0c 0.001c\nC',
        'Dense scale',
      );
    await tester.pumpWidget(
      PitchVisualApp(controller: model, initialize: false),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('开始监听'), findsOneWidget);
  });
  testWidgets('Large text settings and monitor stay usable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      PitchVisualApp(controller: controller(), initialize: false),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('音量阈值'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
