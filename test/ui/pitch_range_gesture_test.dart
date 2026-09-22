import 'dart:convert';
import 'dart:ui' show ClipOp;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/l10n/l10n.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/domain/models/monitor_settings.dart';
import 'package:pitch_visual/domain/tuning/scale_config.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';
import 'package:pitch_visual/ui/features/monitor/pitch_graph.dart';

import '../data/fakes.dart';

class _GridCanvas extends Fake implements Canvas {
  late Rect plot;
  final grid = <double>[];

  @override
  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  }) => plot = rect;

  @override
  void drawLine(Offset start, Offset end, Paint paint) {
    if (start.dy == end.dy) grid.add(start.dy);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  for (final spectrum in [false, true]) {
    group(spectrum ? 'FFT gestures' : 'pitch history gestures', () {
      late MonitorController model;
      late FakePlatformService platform;

      setUp(() {
        platform = FakePlatformService('unused');
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
              ..settings = MonitorSettings(
                showSpectrum: spectrum,
                verticalZoom: 1.5,
              );
        addTearDown(model.dispose);
        addTearDown(platform.close);
        addTearDown(worker.close);
      });

      Future<void> mount(
        WidgetTester tester, {
        bool scrollable = false,
        Size size = const Size(375, 500),
      }) async {
        final graph = SizedBox.fromSize(
          size: size,
          child: ListenableBuilder(
            listenable: model,
            builder: (context, _) => PitchGraph(controller: model),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Center(
                child: scrollable
                    ? SizedBox(
                        height: 400,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [graph, const SizedBox(height: 600)],
                          ),
                        ),
                      )
                    : graph,
              ),
            ),
          ),
        );
      }

      Finder painter() => find
          .descendant(
            of: find.byType(PitchGraph),
            matching: find.byType(CustomPaint),
          )
          .first;

      _GridCanvas paint(WidgetTester tester) {
        final canvas = _GridCanvas();
        tester
            .widget<CustomPaint>(painter())
            .painter!
            .paint(canvas, tester.getSize(painter()));
        return canvas;
      }

      testWidgets(
        'vertical drag works with automatic following and paints immediately',
        (tester) async {
          await mount(tester);
          final center = tester.getCenter(painter());
          final touch = await tester.startGesture(center);
          await touch.moveBy(const Offset(0, 40));
          await tester.pump();
          final before = model.centerCents;
          final plot = paint(tester).plot;
          final range = (spectrum ? 9600 : 2400) / model.settings.verticalZoom;
          await touch.moveBy(const Offset(0, 30));
          await tester.pump();
          expect(
            model.centerCents - before,
            closeTo(30 * range / plot.height, .001),
          );
          expect(model.settings.autoScroll, isFalse);
          expect(model.settings.verticalZoom, 1.5);
          final grid = paint(tester).grid;
          await tester.pump(const Duration(milliseconds: 250));
          expect(
            paint(tester).grid,
            grid,
            reason: 'The plot must track the finger without animation lag.',
          );
          await touch.up();
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          expect(model.message, isNull);
          expect(platform.preferences, isNotNull);
          final saved = jsonDecode(platform.preferences!) as Map;
          expect((saved['settings'] as Map)['autoScroll'], isFalse);
          await tester.tap(find.byTooltip('恢复自动跟随音域'));
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          expect(model.settings.autoScroll, isTrue);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'pinch scales vertically around its focal pitch and preserves time',
        (tester) async {
          model.settings = model.settings.withValue(
            'verticalZoom',
            spectrum ? 1.1 : 1,
          );
          await mount(tester);
          final bounds = tester.getRect(painter());
          final plot = paint(tester).plot;
          final focus =
              bounds.topLeft +
              Offset(plot.center.dx, plot.top + plot.height * .6);
          var upper = focus - const Offset(0, 60);
          var lower = focus + const Offset(0, 60);
          final first = await tester.startGesture(upper, pointer: 1);
          final second = await tester.startGesture(lower, pointer: 2);
          upper -= const Offset(0, 24);
          await first.moveTo(upper);
          lower += const Offset(0, 24);
          await second.moveTo(lower);
          await tester.pump();
          final beforeZoom = model.settings.verticalZoom;
          final beforeRange = (spectrum ? 9600 : 2400) / beforeZoom;
          final focalPitch = model.centerCents - .1 * beforeRange;
          final seconds = model.graphSeconds;
          upper -= const Offset(0, 12);
          lower += const Offset(0, 12);
          await first.moveTo(upper);
          await second.moveTo(lower);
          await tester.pump();
          expect(model.settings.verticalZoom, greaterThan(beforeZoom));
          final range = (spectrum ? 9600 : 2400) / model.settings.verticalZoom;
          expect(model.centerCents - .1 * range, closeTo(focalPitch, .001));
          expect(model.graphSeconds, seconds);
          expect(model.settings.autoScroll, isFalse);
          // Horizontal separation must not zoom either axis.
          final zoom = model.settings.verticalZoom;
          await first.moveBy(const Offset(-30, 0));
          await second.moveBy(const Offset(30, 0));
          await tester.pump();
          expect(model.settings.verticalZoom, zoom);
          // Removing a finger must not jump the viewport.
          final center = model.centerCents;
          await second.up();
          await tester.pump();
          expect(model.centerCents, center);
          expect(model.settings.verticalZoom, zoom);
          await first.up();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('pinch in widens the range and clamps at the zoom limit', (
        tester,
      ) async {
        await mount(tester);
        final center = tester.getCenter(painter());
        final first = await tester.startGesture(
          center - const Offset(0, 160),
          pointer: 1,
        );
        final second = await tester.startGesture(
          center + const Offset(0, 160),
          pointer: 2,
        );
        for (var distance = 130.0; distance >= 10; distance -= 20) {
          await first.moveTo(center - Offset(0, distance));
          await second.moveTo(center + Offset(0, distance));
          await tester.pump();
        }
        expect(model.settings.verticalZoom, spectrum ? 1 : .5);
        if (spectrum) expect(model.centerCents, 4800);
        await first.up();
        await second.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'tap and horizontal swipe leave automatic following enabled',
        (tester) async {
          await mount(tester);
          await tester.tapAt(tester.getCenter(painter()));
          await tester.drag(painter(), const Offset(100, 0));
          await tester.pumpAndSettle();
          expect(model.settings.autoScroll, isTrue);
          expect(model.centerCents, 4800);
          expect(model.settings.verticalZoom, 1.5);
          expect(platform.preferences, isNull);
        },
      );

      testWidgets('chart drag wins over the compact screen scroll view', (
        tester,
      ) async {
        await mount(tester, scrollable: true, size: const Size(375, 240));
        final before = tester.getTopLeft(painter());
        await tester.timedDrag(
          painter(),
          const Offset(0, -80),
          const Duration(milliseconds: 400),
        );
        await tester.pumpAndSettle();
        expect(model.centerCents, lessThan(4800));
        expect(tester.getTopLeft(painter()), before);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
