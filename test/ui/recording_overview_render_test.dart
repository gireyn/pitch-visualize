import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/audio/pitch_worker.dart';
import 'package:pitch_visual/domain/audio/recording_analyzer.dart';
import 'package:pitch_visual/domain/models/wave_data.dart';
import 'package:pitch_visual/main.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';
import 'package:pitch_visual/ui/features/monitor/pitch_graph.dart';
import 'package:pitch_visual/ui/features/monitor/spectrum_graph.dart';

import '../data/fakes.dart';

class _DeferredAnalyzer extends RecordingAnalyzer {
  final started = Completer<void>();
  final result = Completer<List<PitchFrame>>();

  @override
  Future<List<PitchFrame>> analyze(WaveData wave, {required double threshold}) {
    started.complete();
    return result.future;
  }
}

void main() {
  testWidgets(
    'library loading shows progress then paints the whole file in both modes',
    (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.binding.setSurfaceSize(const Size(375, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final folder = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('overview-render-'),
      ))!;
      final platform = FakePlatformService(folder.path);
      final worker = FakePitchWorker();
      final repository = RecordingRepository(platform);
      late _DeferredAnalyzer analyzer;
      late MonitorController controller;
      addTearDown(() async {
        await platform.close();
        await worker.close();
        await folder.delete(recursive: true);
      });
      final pcm = Uint8List(44100 * 2 * 12);
      final data = ByteData.sublistView(pcm);
      for (var i = 0; i < pcm.length ~/ 2; i++) {
        final t = i / 44100;
        final hz = t < 4 ? 220 : (t < 8 ? 0 : 660);
        data.setInt16(
          i * 2,
          (12000 * math.sin(2 * math.pi * hz * t)).round(),
          Endian.little,
        );
      }
      final wave = WaveData(pcm: pcm, sampleRate: 44100);
      late List<PitchFrame> frames;
      await tester.runAsync(() async {
        analyzer = _DeferredAnalyzer();
        controller = MonitorController(
          platform: platform,
          worker: worker,
          recordingAnalyzer: analyzer,
          recordingRepository: repository,
          settingsRepository: SettingsRepository(platform),
        );
        await repository.save(wave, name: 'Full recording.wav');
        await controller.initialize();
        frames = await const RecordingAnalyzer().analyze(wave, threshold: 2);
      });
      await tester.pumpWidget(
        PitchVisualApp(controller: controller, initialize: false),
      );
      await tester.tap(find.byTooltip('Recordings'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Full recording.wav'));
        await analyzer.started.future.timeout(const Duration(seconds: 5));
      });
      await tester.pump();
      expect(
        find.text('Analyzing the full recording…').hitTestable(),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        analyzer.result.complete(frames);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.text('Analyzing the full recording…'), findsNothing);
      expect(controller.currentTime, 0);
      expect(controller.graphSeconds, 12);

      Future<void> verifyDrawing(bool spectrum) async {
        final plot = find
            .descendant(
              of: find.byType(PitchGraph),
              matching: find.byType(CustomPaint),
            )
            .first;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.ancestor(of: plot, matching: find.byType(RepaintBoundary)).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData())!;
          const preview = String.fromEnvironment('RECORDING_PREVIEW_DIR');
          if (preview.isNotEmpty) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(preview).create(recursive: true);
            await File('$preview/${spectrum ? 'fft' : 'pitch'}.png')
                .writeAsBytes(png!.buffer.asUint8List());
          }
          var early = 0, late = 0;
          for (var y = 30; y < image.height - 70; y++) {
            for (var x = 0; x < image.width; x++) {
              final offset = (y * image.width + x) * 4;
              final r = bytes.getUint8(offset),
                  g = bytes.getUint8(offset + 1),
                  b = bytes.getUint8(offset + 2);
              if (r > 180 && g > 80 && b < 140) {
                if (x > image.width * .25 && x < image.width * .45) early++;
                if (x > image.width * .78 && x < image.width * .93) late++;
              }
            }
          }
          expect(
            early,
            greaterThan(80),
            reason: 'the start of the file must be visible',
          );
          expect(
            late,
            greaterThan(80),
            reason: 'the end must be visible before playback',
          );
          image.dispose();
        });
      }

      await verifyDrawing(false);
      await tester.tap(find.byTooltip('Switch to FFT spectrum'));
      await tester.pumpAndSettle();
      // Image decoding crosses both engine and framework queues.
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
      }
      expect(find.byType(SpectrumGraph), findsOneWidget);
      await verifyDrawing(true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    },
  );
}
