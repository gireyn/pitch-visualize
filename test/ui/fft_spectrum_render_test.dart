import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/audio/log_spectrum.dart';
import 'package:pitch_visual/domain/audio/pitch_analyzer.dart';
import 'package:pitch_visual/domain/models/monitor_settings.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';
import 'package:pitch_visual/main.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';
import 'package:pitch_visual/ui/features/monitor/spectrum_graph.dart';

import '../data/fakes.dart';

class _PreviewController extends MonitorController {
  _PreviewController(FakePlatformService platform, this.points)
    : super(
        platform: platform,
        worker: FakePitchWorker(),
        settingsRepository: SettingsRepository(platform),
        recordingRepository: RecordingRepository(platform),
      );
  final List<SpectrumPoint> points;
  @override
  List<SpectrumPoint> get spectra => points;
}

void main() {
  testWidgets('real FFT harmonics render and the graph mode can be switched', (
    tester,
  ) async {
    const preview = String.fromEnvironment('SPECTRUM_PREVIEW_PATH');
    if (preview.isNotEmpty) {
      // Optional local preview fonts; normal CI remains platform independent.
      await tester.runAsync(() async {
        const font = String.fromEnvironment('SPECTRUM_PREVIEW_FONT');
        if (font.isNotEmpty) {
          final data = ByteData.sublistView(await File(font).readAsBytes());
          const latinFont = String.fromEnvironment(
            'SPECTRUM_PREVIEW_LATIN_FONT',
          );
          final latinData = latinFont.isEmpty
              ? data
              : ByteData.sublistView(await File(latinFont).readAsBytes());
          for (final family in ['Ahem', 'Roboto', 'sans-serif', 'monospace']) {
            await (FontLoader(family)
                  ..addFont(Future.value(latinData))
                  ..addFont(Future.value(data)))
                .load();
          }
        }
        final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(icons))).load();
      });
    }
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final analyzer = PitchAnalyzer();
    final points = <SpectrumPoint>[];
    var phase = 0.0;
    for (var sample = 0; sample < 44100 * 7; sample++) {
      final t = sample / 44100;
      final hz = 150 + 90 * (.5 + .5 * math.sin(t * 2.4));
      phase += 2 * math.pi * hz / 44100;
      var value = 0.0;
      if (t % 1.7 < 1.45) {
        for (var harmonic = 1; harmonic <= 24; harmonic++) {
          value += 7000 / harmonic * math.sin(phase * harmonic);
        }
      }
      if (analyzer.addSample(value.round())) {
        points.add(
          SpectrumPoint(points.length, (sample + 1) / 44100, analyzer.spectrum),
        );
      }
    }
    final platform = FakePlatformService('unused');
    addTearDown(platform.close);
    final controller = _PreviewController(platform, points)
      ..initialized = true
      ..mode = MonitorMode.listening
      ..scale = ScaleConfig.parse(
        'C4: 261.6255653\n0\\7 1\\7 2\\7 3\\7 4\\7 5\\7 6\\7 7\\7\nC D E F G A B',
        '7ed2 on C',
      )
      ..settings = const MonitorSettings(horizontalZoom: 1.3, scrollSpeed: 10)
      ..currentTime = 7
      ..frequency = analyzer.peakFrequency;
    controller.note = controller.scale!.nearestNote(3200);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: PitchVisualApp(controller: controller, initialize: false),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SpectrumGraph), findsOneWidget);
    expect(find.text('FFT · 音高 / log₂'), findsOneWidget);
    expect(find.text('0 dBFS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final pixels = (await image.toByteData())!;
      var warmPixels = 0;
      for (var offset = 0; offset < pixels.lengthInBytes; offset += 4) {
        if (pixels.getUint8(offset) > 180 &&
            pixels.getUint8(offset + 1) > 80 &&
            pixels.getUint8(offset + 2) < 80) {
          warmPixels++;
        }
      }
      expect(
        warmPixels,
        greaterThan(1500),
        reason: 'FFT tiles must actually be visible',
      );
      if (preview.isNotEmpty) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(preview).parent.create(recursive: true);
        await File(preview).writeAsBytes(png!.buffer.asUint8List());
      }
      image.dispose();
    });
    await tester.tap(find.byTooltip('更多选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换为音高曲线'));
    await tester.pumpAndSettle();
    expect(controller.settings.showSpectrum, isFalse);
    expect(find.byType(SpectrumGraph), findsNothing);
    await tester.tap(find.byTooltip('更多选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换为 FFT 频谱'));
    await tester.pumpAndSettle();
    expect(controller.settings.showSpectrum, isTrue);
    expect(find.byType(SpectrumGraph), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    expect(tester.takeException(), isNull);
  });
}
