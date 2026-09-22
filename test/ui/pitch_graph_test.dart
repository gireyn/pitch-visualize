import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/l10n/l10n.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/models/monitor_settings.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';
import 'package:pitch_visual/ui/core/app_theme.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';
import 'package:pitch_visual/ui/features/monitor/pitch_graph.dart';

import '../data/fakes.dart';

typedef _Stroke = ({Offset start, Offset end, Color color});

class _PreviewController extends MonitorController {
  _PreviewController(FakePlatformService platform, FakePitchWorker worker)
    : super(
        platform: platform,
        worker: worker,
        settingsRepository: SettingsRepository(platform),
        recordingRepository: RecordingRepository(platform),
      );

  final points = <PitchPoint>[const PitchPoint(0, 3600)];
  double _range = 2400;

  @override
  List<PitchPoint> get history => points;
  @override
  double get historyRange => settings.autoScroll ? _range : super.historyRange;
  @override
  double get historyBaseRange => historyRange * settings.verticalZoom;

  void showRange(double center, double range) {
    centerCents = center;
    _range = range;
    notifyListeners();
  }
}

class _PlotCanvas extends Fake implements Canvas {
  late Rect plot;
  final dots = <Offset>[];
  final labels = <Rect>[];
  final strokes = <_Stroke>[];

  List<_Stroke> get scaleLines =>
      strokes
          .where(
            (line) =>
                line.start.dy == line.end.dy &&
                line.start.dx == plot.left &&
                line.end.dx == plot.right,
          )
          .toList()
        ..sort((a, b) => b.start.dy.compareTo(a.start.dy));

  List<_Stroke> get ticks => strokes
      .where(
        (line) =>
            line.start.dy == line.end.dy &&
            line.start.dx == plot.left &&
            line.end.dx > plot.left &&
            line.end.dx < plot.right,
      )
      .toList();

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      strokes.add((start: p1, end: p2, color: paint.color));

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) => plot = rect;

  @override
  void drawCircle(Offset center, double radius, Paint paint) =>
      dots.add(center);

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    if (offset.dx == 10) {
      labels.add(offset & Size(paragraph.width, paragraph.height));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _PreviewController model;
  final boundaryKey = GlobalKey();

  setUp(() {
    final platform = FakePlatformService('unused');
    final worker = FakePitchWorker();
    model = _PreviewController(platform, worker)
      ..scale = ScaleConfig.parse(
        'C4: 261.6255653\n0\\7 1\\7 2\\7 3\\7 4\\7 5\\7 6\\7 7\\7\nC D E F G A B',
        '7ed2 on C',
      )
      ..settings = const MonitorSettings(showSpectrum: false)
      ..currentTime = 1;
    addTearDown(model.dispose);
    addTearDown(platform.close);
    addTearDown(worker.close);
  });

  Future<void> mount(
    WidgetTester tester, {
    bool reduceMotion = false,
    Size size = const Size(375, 500),
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Material(
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: RepaintBoundary(
                key: boundaryKey,
                child: ListenableBuilder(
                  listenable: model,
                  builder: (context, _) => PitchGraph(controller: model),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Finder painter() => find
      .descendant(
        of: find.byType(PitchGraph),
        matching: find.byType(CustomPaint),
      )
      .first;

  _PlotCanvas paint(WidgetTester tester) {
    final canvas = _PlotCanvas();
    tester
        .widget<CustomPaint>(painter())
        .painter!
        .paint(canvas, tester.getSize(painter()));
    return canvas;
  }

  Future<List<_Stroke>> paintTuner(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Center(
          child: SizedBox(width: 375, child: TunerStrip(controller: model)),
        ),
      ),
    );
    final finder = find.descendant(
      of: find.byType(TunerStrip),
      matching: find.byType(CustomPaint),
    );
    final canvas = _PlotCanvas();
    tester
        .widget<CustomPaint>(finder)
        .painter!
        .paint(canvas, tester.getSize(finder));
    return canvas.strokes
        .where(
          (line) =>
              line.start.dx == line.end.dx &&
              line.end.dy == 36 &&
              line.start.dx >= 0 &&
              line.start.dx <= 375 &&
              line.color.toARGB32() != AppColors.accent.toARGB32(),
        )
        .toList();
  }

  for (final edo in [12, 31]) {
    testWidgets(
      '$edo EDO tuner uses the same note positions and graded ticks',
      (tester) async {
        model.scale = ScaleConfig.equalDivision(edo);
        model.centerCents = 3600;
        final ticks = await paintTuner(tester);
        final stepsEachSide = edo == 12 ? 1 : 4;
        expect(ticks, hasLength(stepsEachSide * 2 + 1));
        for (var i = 0; i < ticks.length; i++) {
          final centsFromC4 = (i - stepsEachSide) * 1200 / edo;
          expect(
            ticks[i].start.dx,
            closeTo(187.5 + centsFromC4 / (1200 / 7) * 175.5, .001),
          );
        }
        final anchor = ticks[stepsEachSide];
        expect(anchor.end.dy - anchor.start.dy, closeTo(24, .001));
        expect(ticks.last.end.dy - ticks.last.start.dy, lessThan(24));
        expect(ticks.last.color.a, lessThan(anchor.color.a));
      },
    );
  }

  testWidgets(
    'tuner keeps irregular file pitches when the EDO setting changes',
    (tester) async {
      model.scale = ScaleConfig.parse(
        'A4: 261.6255653005986\n0c 130c 700c 1900c\nA B D',
        'Custom period',
      );
      model.centerCents = 3600;
      final before = await paintTuner(tester);
      expect(before, hasLength(2));
      expect(before.first.start.dx, closeTo(187.5, .001));
      expect(
        before.last.start.dx,
        closeTo(187.5 + 130 / (1200 / 7) * 175.5, .001),
      );
      expect(before.every((line) => line.end.dy - line.start.dy == 24), isTrue);

      await tester.runAsync(() => model.updateSetting('edo', 31));
      expect(await paintTuner(tester), before);
    },
  );

  for (final edo in [12, 31]) {
    testWidgets(
      '$edo EDO aligns the pitch grid and graded ticks with C4 to C5',
      (tester) async {
        model.scale = ScaleConfig.equalDivision(edo);
        model.showRange(4200, 1200);
        await mount(tester, reduceMotion: true);
        final canvas = paint(tester);
        final lines = canvas.scaleLines;

        expect(lines, hasLength(edo + 1));
        for (var i = 0; i <= edo; i++) {
          expect(
            lines[i].start.dy,
            closeTo(canvas.plot.bottom - i / edo * canvas.plot.height, .001),
          );
        }
        expect(canvas.ticks, hasLength(edo + 1));
        final anchor = canvas.ticks.singleWhere(
          (line) => (line.start.dy - canvas.plot.bottom).abs() < .001,
        );
        final degree = canvas.ticks.singleWhere(
          (line) => (line.start.dy - lines[1].start.dy).abs() < .001,
        );
        expect(anchor.end.dx - anchor.start.dx, closeTo(20, .001));
        expect(
          degree.end.dx - degree.start.dx,
          lessThan(anchor.end.dx - anchor.start.dx),
        );
        expect(degree.color.a, lessThan(anchor.color.a));
      },
    );
  }

  testWidgets('0 EDO paints only octave guides in pitch history', (
    tester,
  ) async {
    model.scale = ScaleConfig.equalDivision(0);
    model.showRange(4200, 1200);
    await mount(tester, reduceMotion: true);
    final canvas = paint(tester);

    expect(canvas.scaleLines, hasLength(2));
    expect(canvas.ticks, hasLength(2));
    expect(canvas.scaleLines.first.start.dy, closeTo(canvas.plot.bottom, .001));
    expect(canvas.scaleLines.last.start.dy, closeTo(canvas.plot.top, .001));
  });

  testWidgets('dense EDO pitch history avoids painting every fine division', (
    tester,
  ) async {
    model.scale = ScaleConfig.equalDivision(72);
    model.showRange(4800, 9600);
    await mount(
      tester,
      reduceMotion: true,
      size: const Size(740, 260),
      textScale: 2,
    );
    final canvas = paint(tester);

    expect(canvas.scaleLines.length, lessThan(72 * 8 ~/ 2));
    for (var octave = 0; octave <= 8; octave++) {
      final y = canvas.plot.bottom - octave / 8 * canvas.plot.height;
      expect(
        canvas.scaleLines.map((line) => line.start.dy),
        contains(closeTo(y, .001)),
      );
    }
    for (var i = 1; i < canvas.labels.length; i++) {
      expect(
        canvas.labels[i].top,
        greaterThanOrEqualTo(canvas.labels[i - 1].bottom),
      );
    }
  });

  testWidgets('changing EDO preserves an imported non-octave pitch grid', (
    tester,
  ) async {
    model.scale = ScaleConfig.parse(
      'A4: 261.6255653005986\n0c 250c 700c 1900c\nA B D\n220 90 150',
      'Custom period',
    );
    model.showRange(4700, 2400);
    await mount(tester, reduceMotion: true);
    final before = paint(tester);
    const cents = [3600, 3850, 4300, 5500, 5750];
    expect(before.scaleLines, hasLength(cents.length));
    for (var i = 0; i < cents.length; i++) {
      expect(
        before.scaleLines[i].start.dy,
        closeTo(
          before.plot.bottom - (cents[i] - 3500) / 2400 * before.plot.height,
          .001,
        ),
      );
    }
    expect(before.ticks, isEmpty);
    expect(before.scaleLines.first.color.r, closeTo(220 / 255, .001));
    expect(before.scaleLines[1].color.r, closeTo(90 / 255, .001));

    await tester.runAsync(() => model.updateSetting('edo', 31));
    await tester.pumpAndSettle();
    final after = paint(tester);
    expect(model.settings.edo, 31);
    expect(model.scale!.edo, isNull);
    expect(after.scaleLines, before.scaleLines);
    expect(after.ticks, isEmpty);
  });

  testWidgets('axis and old notes move continuously during expansion', (
    tester,
  ) async {
    await mount(tester);
    final before = paint(tester).dots.first.dy;
    model.showRange(5400, 6000);
    await tester.pump();
    expect(paint(tester).dots.first.dy, before);
    await tester.pump(const Duration(milliseconds: 80));
    final middle = paint(tester);
    expect(middle.dots.first.dy, greaterThan(before));
    expect(middle.plot.contains(middle.dots.first), isTrue);
    await tester.pumpAndSettle();
    expect(paint(tester).dots.first.dy, greaterThan(middle.dots.first.dy));
  });

  testWidgets('drag adopts the painted range while auto expansion is running', (
    tester,
  ) async {
    await mount(tester);
    model.showRange(5400, 6000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final touch = await tester.startGesture(tester.getCenter(painter()));
    await touch.moveBy(const Offset(0, 40));
    await tester.pump();
    final before = paint(tester).dots.first.dy;
    await touch.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(model.settings.autoScroll, isFalse);
    expect(paint(tester).dots.first.dy - before, closeTo(30, .01));
    final manual = paint(tester).dots.first;
    await tester.pump(const Duration(milliseconds: 400));
    expect(paint(tester).dots.first, manual);
    await touch.up();
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion updates range without intermediate movement', (
    tester,
  ) async {
    await mount(tester, reduceMotion: true);
    model.showRange(5400, 6000);
    await tester.pump();
    final updated = paint(tester).dots.first;
    await tester.pump(const Duration(milliseconds: 400));
    expect(paint(tester).dots.first, updated);
    final plot = paint(tester).plot;
    expect(updated.dy, closeTo(plot.bottom - .2 * plot.height, .001));
  });

  testWidgets('isolated historical notes remain visible across large jumps', (
    tester,
  ) async {
    model.points
      ..clear()
      ..addAll(const [
        PitchPoint(0, 1200),
        PitchPoint(.1, 8400),
        PitchPoint(.2, 1200),
        PitchPoint(.3, null),
      ]);
    model.showRange(4800, 8400);
    await mount(tester);
    final canvas = paint(tester);
    expect(canvas.dots.length, 3);
    expect(canvas.dots.every(canvas.plot.contains), isTrue);
  });

  testWidgets('pinch preserves focal pitch after automatic range expansion', (
    tester,
  ) async {
    model.showRange(5400, 6000);
    await mount(tester);
    final bounds = tester.getRect(painter());
    final plot = paint(tester).plot;
    final localFocus = Offset(bounds.width / 2, plot.center.dy);
    final focus = bounds.topLeft + localFocus;
    final upper = await tester.startGesture(
      focus - const Offset(0, 40),
      pointer: 1,
    );
    final lower = await tester.startGesture(
      focus + const Offset(0, 40),
      pointer: 2,
    );
    await upper.moveTo(focus - const Offset(0, 64));
    await lower.moveTo(focus + const Offset(0, 64));
    await tester.pump();
    final fraction = .5 - (localFocus.dy - plot.top) / plot.height;
    final focalPitch = model.centerCents + fraction * model.historyRange;
    for (var distance = 76.0; distance <= 88; distance += 12) {
      await upper.moveTo(focus - Offset(0, distance));
      await lower.moveTo(focus + Offset(0, distance));
      await tester.pump();
    }
    expect(model.settings.autoScroll, isFalse);
    expect(model.historyRange, lessThan(6000));
    expect(
      model.centerCents + fraction * model.historyRange,
      closeTo(focalPitch, .01),
    );
    await upper.up();
    await lower.up();
    await tester.pumpAndSettle();
  });

  for (final size in [const Size(375, 500), const Size(740, 260)]) {
    testWidgets('wide range labels do not overlap at $size and large text', (
      tester,
    ) async {
      model.showRange(4800, 9600);
      await mount(tester, size: size, textScale: 2);
      final canvas = paint(tester);
      expect(canvas.labels.length, greaterThan(1));
      for (var i = 1; i < canvas.labels.length; i++) {
        expect(
          canvas.labels[i].top,
          greaterThanOrEqualTo(canvas.labels[i - 1].bottom),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders a wide jump fixture with both registers visible', (
    tester,
  ) async {
    const preview = String.fromEnvironment('PITCH_PREVIEW_PATH');
    const font = String.fromEnvironment('PITCH_PREVIEW_FONT');
    if (preview.isNotEmpty && font.isNotEmpty) {
      await tester.runAsync(() async {
        final data = ByteData.sublistView(await File(font).readAsBytes());
        for (final family in ['Ahem', 'Roboto', 'sans-serif', 'monospace']) {
          await (FontLoader(family)..addFont(Future.value(data))).load();
        }
      });
    }
    model.points.clear();
    for (var i = 0; i < 450; i++) {
      final t = i / 30;
      final center = switch (t) {
        < 3 => 2400.0,
        < 6 => 6000.0,
        < 9 => 3600.0,
        < 12 => 7200.0,
        _ => 2400.0,
      };
      model.points.add(PitchPoint(t, center + 40 * math.sin(t * 30)));
    }
    model.currentTime = 15;
    model.showRange(4800, 6000);
    await mount(tester, size: const Size(375, 500));
    await tester.pumpAndSettle();
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final pixels = (await image.toByteData())!;
      var upper = 0, lower = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final offset = (y * image.width + x) * 4;
          if (pixels.getUint8(offset) > 220 &&
              pixels.getUint8(offset + 1) > 150 &&
              pixels.getUint8(offset + 2) < 140) {
            if (y < image.height / 2) {
              upper++;
            } else {
              lower++;
            }
          }
        }
      }
      expect(upper, greaterThan(300));
      expect(lower, greaterThan(300));
      if (preview.isNotEmpty) {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(preview).parent.create(recursive: true);
        await File(preview).writeAsBytes(data!.buffer.asUint8List());
      }
      image.dispose();
    });
  });
}
