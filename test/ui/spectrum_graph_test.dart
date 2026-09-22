import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/l10n/l10n.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/models/monitor_settings.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';
import 'package:pitch_visual/ui/features/monitor/spectrum_graph.dart';

import '../data/fakes.dart';

typedef _Stroke = ({Offset start, Offset end, Color color});

class _PlotCanvas extends Fake implements Canvas {
  late Rect plot;
  final grid = <Offset>[];
  final labels = <double>[];
  final strokes = <_Stroke>[];

  List<_Stroke> get scaleLines =>
      strokes
          .where(
            (line) => line.start.dx == plot.left && line.end.dx == plot.right,
          )
          .toList()
        ..sort((a, b) => b.start.dy.compareTo(a.start.dy));

  List<_Stroke> get ticks => strokes
      .where((line) => line.start.dx == plot.left && line.end.dx < plot.right)
      .toList();

  @override
  void drawRect(Rect rect, Paint paint) => plot = rect;

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    if (p1.dy == p2.dy) {
      grid.add(p1);
      strokes.add((start: p1, end: p2, color: paint.color));
    }
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    if (offset.dx < plot.left && offset.dy < plot.bottom) {
      labels.add(offset.dy + paragraph.height / 2);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late MonitorController model;

  setUp(() {
    final platform = FakePlatformService('unused');
    final worker = FakePitchWorker();
    model =
        MonitorController(
            platform: platform,
            settingsRepository: SettingsRepository(platform),
            recordingRepository: RecordingRepository(platform),
            worker: worker,
          )
          ..scale = ScaleConfig.parse(
            'C4: 261.6255653005986\n0\\7 1\\7 2\\7 3\\7 4\\7 5\\7 6\\7 7\\7\nC D E F G A B',
            '7ed2',
          )
          ..centerCents = 4800
          ..settings = const MonitorSettings(verticalZoom: 2, showBeats: false);
    addTearDown(model.dispose);
    addTearDown(platform.close);
    addTearDown(worker.close);
  });

  Future<void> mount(
    WidgetTester tester, {
    bool reduceMotion = false,
    Size size = const Size(375, 400),
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Center(
          child: SizedBox.fromSize(
            size: size,
            child: ListenableBuilder(
              listenable: model,
              builder: (context, _) => SpectrumGraph(controller: model),
            ),
          ),
        ),
      ),
    ),
  );

  _PlotCanvas paint(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(SpectrumGraph),
      matching: find.byType(CustomPaint),
    );
    final canvas = _PlotCanvas();
    tester
        .widget<CustomPaint>(finder)
        .painter!
        .paint(canvas, tester.getSize(finder));
    return canvas;
  }

  // Recover the displayed lower bound from the highest C-based grid degree.
  // This checks actual painted positions, without reaching into widget state.
  double displayedMin(_PlotCanvas canvas, double maxCents, double range) {
    final scale = model.scale!;
    final note = scale.notesBetween(maxCents - 200, maxCents).last;
    return note.cents -
        (canvas.plot.bottom - canvas.grid.first.dy) /
            canvas.plot.height *
            range;
  }

  for (final edo in [12, 31]) {
    testWidgets(
      '$edo EDO paints equally spaced notes and emphasized octave ticks',
      (tester) async {
        model.scale = ScaleConfig.equalDivision(edo);
        model.settings = MonitorSettings(
          edo: edo,
          verticalZoom: 8,
          showBeats: false,
        );
        model.centerCents = 4200;
        await mount(tester, reduceMotion: true, size: const Size(375, 550));
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

  testWidgets('0 EDO paints octave guides with no intermediate degrees', (
    tester,
  ) async {
    model.scale = ScaleConfig.equalDivision(0);
    await mount(tester, reduceMotion: true);
    final canvas = paint(tester);

    expect(canvas.scaleLines, hasLength(5));
    expect(canvas.ticks, hasLength(5));
    for (var i = 0; i < 5; i++) {
      expect(
        canvas.scaleLines[i].start.dy,
        closeTo(canvas.plot.bottom - i / 4 * canvas.plot.height, .001),
      );
    }
  });

  testWidgets(
    'changing EDO keeps an imported non-octave spectrum grid and colors',
    (tester) async {
      model.scale = ScaleConfig.parse(
        'A4: 261.6255653005986\n0c 250c 700c 1900c\nA B D\n220 90 150',
        'Custom period',
      );
      model.settings = const MonitorSettings(
        edo: 12,
        verticalZoom: 2,
        showBeats: false,
      );
      model.centerCents = 4800;
      await mount(tester, reduceMotion: true);
      final before = paint(tester);
      const cents = [2400, 3600, 3850, 4300, 5500, 5750, 6200];
      expect(before.scaleLines, hasLength(cents.length));
      for (var i = 0; i < cents.length; i++) {
        expect(
          before.scaleLines[i].start.dy,
          closeTo(
            before.plot.bottom - (cents[i] - 2400) / 4800 * before.plot.height,
            .001,
          ),
        );
      }
      expect(before.ticks, isEmpty);
      expect(before.scaleLines[1].color.r, closeTo(220 / 255, .001));
      expect(before.scaleLines[2].color.r, closeTo(90 / 255, .001));

      await tester.runAsync(() => model.updateSetting('edo', 31));
      await tester.pumpAndSettle();
      final after = paint(tester);
      expect(model.settings.edo, 31);
      expect(model.scale!.edo, isNull);
      expect(after.scaleLines, before.scaleLines);
      expect(after.ticks, isEmpty);
    },
  );

  testWidgets('range changes scroll through intermediate painted positions', (
    tester,
  ) async {
    await mount(tester);
    final before = paint(tester);
    expect(displayedMin(before, 7200, 4800), closeTo(2400, .001));

    model.panRange(600);
    await tester.pump();
    final start = paint(tester);
    expect(start.grid, before.grid);
    await tester.pump(const Duration(milliseconds: 80));
    final middle = paint(tester);
    // Match a degree present in both frames: every grid line has the same shift.
    final originalY = before.grid[10].dy;
    final shift = middle.plot.height * 600 / 4800;
    final candidates = middle.grid.where(
      (point) => point.dy > originalY && point.dy < originalY + shift,
    );
    expect(candidates, isNotEmpty);
    expect(middle.grid, isNot(before.grid));

    await tester.pumpAndSettle();
    final end = paint(tester);
    expect(displayedMin(end, 7800, 4800), closeTo(3000, .001));
    expect(end.plot, before.plot);
  });

  testWidgets('a new range continues from the currently displayed position', (
    tester,
  ) async {
    await mount(tester);
    model.panRange(600);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final middle = paint(tester);
    model.panRange(-900);
    await tester.pump();
    expect(paint(tester).grid, middle.grid);

    // Ordinary controller updates must not restart a range transition.
    for (var i = 0; i < 8; i++) {
      model.panRange(0);
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(displayedMin(paint(tester), 6900, 4800), closeTo(2100, .001));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('zoom animates and clamps to the spectrum limits', (
    tester,
  ) async {
    await mount(tester);
    final before = paint(tester);
    model.settings = model.settings.withValue('verticalZoom', 1);
    model.panRange(0);
    await tester.pump();
    expect(paint(tester).grid, before.grid);
    await tester.pump(const Duration(milliseconds: 80));
    final middle = paint(tester);
    expect(middle.grid.length, greaterThan(before.grid.length));
    await tester.pumpAndSettle();
    final end = paint(tester);
    expect(end.grid.length, greaterThan(middle.grid.length));
    expect(displayedMin(end, 9600, 9600), closeTo(0, .001));

    model.panRange(20000);
    await tester.pumpAndSettle();
    expect(paint(tester).grid, end.grid);
  });

  testWidgets('dense labels keep their pitch anchor when a top note exits', (
    tester,
  ) async {
    await mount(
      tester,
      reduceMotion: true,
      size: const Size(812, 240),
      textScale: 2,
    );
    final before = paint(tester);
    model.panRange(-100);
    await tester.pumpAndSettle();
    final after = paint(tester);
    final shift = -100 / 4800 * before.plot.height;
    for (final y in before.labels) {
      final moved = y + shift;
      if (moved > after.plot.top + 1 && moved < after.plot.bottom - 1) {
        expect(after.labels, contains(closeTo(moved, .001)));
      }
    }
    expect(after.plot, before.plot);
    expect(displayedMin(after, 7100, 4800), closeTo(2300, .001));
    expect(tester.takeException(), isNull);
  });
}
