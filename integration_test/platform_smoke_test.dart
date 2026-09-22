import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:pitch_visual/l10n/l10n.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/data/services/platform_service.dart';
import 'package:pitch_visual/domain/models/wave_data.dart';
import 'package:pitch_visual/main.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native storage, tuning cache, WAV playback and live pitch graph',
    (tester) async {
      final platform = PlatformService();
      final settings = SettingsRepository(platform);
      final recordings = RecordingRepository(platform);
      final controller = MonitorController(
        platform: platform,
        settingsRepository: settings,
        recordingRepository: recordings,
      );
      final original = await platform.loadPreferences();
      RecordingEntry? testRecording;
      try {
        await controller.initialize();
        expect(
          controller.initialized,
          isTrue,
          reason: controller.message?.resolve(
            await AppLocalizations.delegate.load(const Locale('en')),
          ),
        );
        expect(
          controller.mode,
          MonitorMode.listening,
          reason: controller.message?.resolve(
            await AppLocalizations.delegate.load(const Locale('en')),
          ),
        );
        expect(controller.isRecording, isFalse);
        await tester.pumpWidget(
          PitchVisualApp(controller: controller, initialize: false),
        );
        // Live monitoring keeps scheduling frames, so it does not settle.
        await tester.pump();
        expect(find.text('PitchVisual'), findsOneWidget);
        await controller.useBundledScale(true);
        expect(controller.scale!.name, '天干音阶');
        final restored = await settings.load();
        expect(restored.scale.name, '天干音阶');
        expect(
          restored.scale.nearestNote(restored.scale.noteAt(0, 4).cents).label,
          '甲4',
        );

        final pcm = Uint8List(44100 * 2 * 4);
        final samples = ByteData.sublistView(pcm);
        for (var i = 0; i < pcm.length ~/ 2; i++) {
          samples.setInt16(
            i * 2,
            (8000 * sin(2 * pi * 440 * i / 44100)).round(),
            Endian.little,
          );
        }
        testRecording = await recordings.save(
          WaveData(pcm: pcm, sampleRate: 44100),
          name: 'integration-smoke-${DateTime.now().microsecondsSinceEpoch}',
        );
        await controller.selectRecording(testRecording);
        await controller.togglePlayback();
        expect(
          controller.isPlaying,
          isTrue,
          reason: controller.message?.resolve(
            await AppLocalizations.delegate.load(const Locale('en')),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await tester.pump();
        expect(
          controller.history.where((point) => point.cents != null),
          isNotEmpty,
        );
        expect(controller.frequency, closeTo(440, 3));
        expect(tester.takeException(), isNull);
        await controller.togglePlayback();
        expect(controller.mode, MonitorMode.paused);
        await controller.togglePlayback();
        expect(controller.isPlaying, isTrue);
        await controller.stop();
        expect(controller.mode, MonitorMode.idle);
      } finally {
        await controller.stop();
        if (testRecording != null) await recordings.delete(testRecording);
        await platform.savePreferences(original ?? '{}');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
