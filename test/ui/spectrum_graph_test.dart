import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/models/monitor_settings.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';
import 'package:pitch_visual/ui/features/monitor/spectrum_graph.dart';

import '../data/fakes.dart';

class _PlotCanvas extends Fake implements Canvas {
  late Rect plot;
  final grid = <Offset>[];
  final labels = <double>[];

  @override
  void drawRect(Rect rect, Paint paint) => plot = rect;

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    if (p1.dy == p2.dy) grid.add(p1);
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
