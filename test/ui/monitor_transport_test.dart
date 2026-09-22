import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/audio/pitch_worker.dart';
import 'package:pitch_visual/domain/audio/recording_analyzer.dart';
import 'package:pitch_visual/domain/models/wave_data.dart';
import 'package:pitch_visual/main.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';

import '../data/fakes.dart';

class _Recordings extends RecordingRepository {
  _Recordings(super.platform);

  final entry = RecordingEntry(
    '/recording.wav',
    'recording',
    DateTime(2026),
    400,
  );
  WaveData? wave;

  @override
  Future<List<RecordingEntry>> list() async => wave == null ? [] : [entry];

  @override
  Future<RecordingEntry> save(WaveData wave, {String? name}) async {
    this.wave = wave;
    return entry;
  }

  @override
  Future<WaveData> load(RecordingEntry entry) async => wave!;
}

class _Analyzer extends RecordingAnalyzer {
  @override
  Future<List<PitchFrame>> analyze(
    WaveData wave, {
    required double threshold,
  }) async => [];
}

void main() {
  late FakePlatformService platform;
  late FakePitchWorker worker;
  late _Recordings recordings;
  late MonitorController controller;

  void createController() {
    platform = FakePlatformService('unused')
      ..preferences = '{"scaleMode":"edo"}';
    worker = FakePitchWorker();
    recordings = _Recordings(platform);
    controller = MonitorController(
      platform: platform,
      worker: worker,
      recordingAnalyzer: _Analyzer(),
      settingsRepository: SettingsRepository(platform),
      recordingRepository: recordings,
    );
  }

  tearDown(() async {
    if (!worker.disposed) controller.dispose();
    await platform.close();
    await worker.close();
  });

  Future<void> mount(WidgetTester tester) async {
    createController();
    await controller.initialize();
    tester.platformDispatcher.localesTestValue = const [Locale('zh')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      PitchVisualApp(controller: controller, initialize: false),
    );
    await tester.pump();
  }

  Finder button(IconData icon) => find.widgetWithIcon(IconButton, icon);

  for (final source in ['listening', 'saved recording', 'recording']) {
    testWidgets('stop then right-hand start resumes $source as live audio', (
      tester,
    ) async {
      await mount(tester);
      if (source != 'listening') {
        await controller.toggleRecording();
        platform.pcm(Uint8List(400));
        if (source == 'saved recording') await controller.toggleRecording();
      }
      await tester.pump();

      for (var cycle = 0; cycle < 2; cycle++) {
        await tester.tap(button(Icons.stop));
        await tester.pump();
        expect(controller.mode, MonitorMode.idle);
        expect(platform.capturing, isFalse);
        expect(platform.keepScreenOn, isFalse);

        final start = button(Icons.play_arrow);
        expect(
          tester.getCenter(start).dx,
          greaterThan(tester.getCenter(button(Icons.stop)).dx),
        );
        expect(tester.widget<IconButton>(start).onPressed, isNotNull);
        expect(tester.widget<IconButton>(start).tooltip, '开始监听');
        expect(find.byTooltip('开始监听'), findsOneWidget);
        await tester.tap(start);
        await tester.pump();

        expect(controller.mode, MonitorMode.listening);
        expect(platform.capturing, isTrue);
        expect(platform.playing, isFalse);
        expect(platform.keepScreenOn, isTrue);
        expect(controller.history, isEmpty);
        final blocksBefore = worker.blocks.length;
        platform.pcm(Uint8List(400));
        worker.frame(440, 1 / 30);
        expect(worker.blocks.length, blocksBefore + 1);
        expect(controller.history, hasLength(1));
        expect(controller.frequency, closeTo(440, .01));
      }
      expect(
        platform.calls.where((call) => call == 'startCapture'),
        hasLength(3),
      );
      expect(platform.calls.where((call) => call.startsWith('play:')), isEmpty);
      expect(controller.recordings, hasLength(source == 'listening' ? 0 : 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selected recording keeps play, pause, resume and restart', (
    tester,
  ) async {
    await mount(tester);
    final entry = await recordings.save(
      WaveData(pcm: Uint8List(44100 * 2), sampleRate: 44100),
    );
    await controller.selectRecording(entry);
    await tester.pump();
    expect(tester.widget<IconButton>(button(Icons.play_arrow)).tooltip, '播放录音');
    await tester.tap(button(Icons.play_arrow));
    await tester.pump();
    expect(controller.mode, MonitorMode.playing);
    expect(platform.capturing, isFalse);

    await tester.tap(button(Icons.pause));
    await tester.pump();
    expect(controller.mode, MonitorMode.paused);
    await tester.tap(button(Icons.play_arrow));
    await tester.pump();
    expect(controller.mode, MonitorMode.playing);
    expect(platform.calls, contains('play:100'));

    await tester.tap(button(Icons.stop));
    await tester.pump();
    await tester.tap(button(Icons.play_arrow));
    await tester.pump();
    expect(controller.mode, MonitorMode.playing);
    expect(
      platform.calls.lastWhere((call) => call.startsWith('play:')),
      'play:0',
    );

    await tester.tap(button(Icons.mic_none));
    await tester.pump();
    expect(controller.mode, MonitorMode.listening);
    await tester.tap(button(Icons.stop));
    await tester.pump();
    await tester.tap(button(Icons.play_arrow));
    await tester.pump();
    expect(controller.mode, MonitorMode.listening);
    expect(platform.capturing, isTrue);
    expect(platform.playing, isFalse);
  });

  testWidgets('start stays disabled while the microphone is opening', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(button(Icons.stop));
    await tester.pump();
    platform.pendingCapture = Completer<int>();
    await tester.tap(button(Icons.play_arrow));
    await tester.pump();
    expect(controller.busy, isTrue);
    expect(
      tester.widget<IconButton>(button(Icons.play_arrow)).onPressed,
      isNull,
    );
    await tester.tap(button(Icons.play_arrow));
    await tester.pump();
    expect(
      platform.calls.where((call) => call == 'startCapture'),
      hasLength(2),
    );

    platform.pendingCapture!.complete(44100);
    await tester.pump();
    expect(controller.mode, MonitorMode.listening);
    expect(controller.busy, isFalse);
  });

  testWidgets('failed restart can be retried with the same start button', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(button(Icons.stop));
    await tester.pump();
    platform.captureError = PlatformException(code: 'permission_denied');
    await tester.tap(button(Icons.play_arrow));
    await tester.pump();
    expect(controller.mode, MonitorMode.idle);
    expect(controller.message, isNotNull);
    expect(
      tester.widget<IconButton>(button(Icons.play_arrow)).onPressed,
      isNotNull,
    );

    platform.captureError = null;
    await tester.tap(button(Icons.play_arrow));
    await tester.pump();
    expect(controller.mode, MonitorMode.listening);
    expect(platform.capturing, isTrue);
    expect(controller.message, isNull);
  });
}
