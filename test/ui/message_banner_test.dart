import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';
import 'package:pitch_visual/l10n/l10n.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_screen.dart';

import '../data/fakes.dart';

void main() {
  late FakePlatformService platform;
  late FakePitchWorker worker;
  late MonitorController controller;
  var disposed = false;

  void createController() {
    platform = FakePlatformService('unused');
    worker = FakePitchWorker();
    controller =
        MonitorController(
            platform: platform,
            worker: worker,
            settingsRepository: SettingsRepository(platform),
            recordingRepository: RecordingRepository(platform),
          )
          ..initialized = true
          ..scale = ScaleConfig.equalDivision(12);
    disposed = false;
  }

  tearDown(() async {
    if (!disposed) controller.dispose();
    await platform.close();
    await worker.close();
  });

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MonitorScreen(controller: controller),
    ),
  );

  final dismissButton = find.byTooltip('Dismiss message');

  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('banner disappears after five seconds at $size', (
      tester,
    ) async {
      createController();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester);
      await controller.useEdoScale();
      await tester.pump();
      expect(dismissButton, findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      controller.toggleHold();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1999));
      expect(dismissButton, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(dismissButton, findsNothing);
      expect(controller.message, isNull);
    });
  }

  testWidgets('repeating a notice restarts its full display duration', (
    tester,
  ) async {
    createController();
    await mount(tester);
    await controller.useEdoScale();
    await tester.pump(const Duration(seconds: 3));
    await controller.useEdoScale();
    await tester.pump(const Duration(seconds: 2));
    expect(dismissButton, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(dismissButton, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(dismissButton, findsNothing);
  });

  testWidgets('manual dismissal cancels the pending timeout', (tester) async {
    createController();
    await mount(tester);
    await controller.useEdoScale();
    await tester.pump();
    await tester.tap(dismissButton);
    await tester.pump();
    expect(dismissButton, findsNothing);
    expect(controller.message, isNull);

    var notifications = 0;
    controller.addListener(() => notifications++);
    await tester.pump(const Duration(seconds: 5));
    expect(notifications, 0);
  });

  testWidgets('disposing cancels the pending message timeout', (tester) async {
    createController();
    await controller.useEdoScale();
    final message = controller.message;
    controller.dispose();
    disposed = true;
    await tester.pump(const Duration(seconds: 5));
    expect(controller.message, same(message));
    expect(tester.takeException(), isNull);
  });

  testWidgets('initialization failure remains visible beside retry', (
    tester,
  ) async {
    createController();
    controller.initialized = false;
    platform.preferences = '{"scaleMode":"edo"}';
    worker.pendingStart = Completer<void>();
    final initialization = controller.initialize();
    await tester.pump();
    worker.pendingStart!.completeError(StateError('Worker unavailable'));
    await initialization;
    await mount(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(find.textContaining('Worker unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
