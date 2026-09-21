import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/ui/features/monitor/history_viewport.dart';

void main() {
  late HistoryViewport viewport;
  late ({double center, double range}) bounds;

  setUp(() {
    viewport = HistoryViewport();
    bounds = (center: 3600, range: 2400);
  });

  void fit(List<double> pitches, double time) {
    bounds = viewport.fit(
      pitches: pitches,
      time: time,
      center: bounds.center,
      range: bounds.range,
      minimumRange: 2400,
    );
  }

  void containsAll(List<double> pitches) {
    for (final pitch in pitches) {
      expect(pitch, greaterThan(bounds.center - bounds.range / 2));
      expect(pitch, lessThan(bounds.center + bounds.range / 2));
    }
  }

  test('large jumps retain both old and new extremes with padding', () {
    fit([3600], 0);
    fit([3600, 8400], 1);
    containsAll([3600, 8400]);
    fit([-600, 3600, 8400], 2);
    containsAll([-600, 3600, 8400]);
    final expanded = bounds;
    for (var i = 0; i < 120; i++) {
      fit(i.isEven ? [-600, 8400] : [8400, -600], 2 + i / 30);
      expect(bounds, expanded);
    }
  });

  test('vibrato and isolated spikes do not make the axis bounce', () {
    fit([3600], 0);
    final original = bounds;
    for (var i = 0; i < 30; i++) {
      fit([3580, 3620], i / 30);
      expect(bounds, original);
    }
    fit([3600, 7200], 1);
    final expanded = bounds;
    fit([3600], 2);
    fit([3600, 7200], 3);
    fit([3600], 4);
    fit([3600], 5.9);
    expect(bounds, expanded);
  });

  test('contracts only after a substantial smaller envelope lasts 2 s', () {
    fit([3600, 8400], 0);
    final expanded = bounds;
    fit([8400], 18);
    fit([8400], 19.99);
    expect(bounds, expanded);
    fit([8400], 20);
    expect(bounds.range, 2400);
    containsAll([8400]);
  });

  test('silence holds the range and resets the contraction delay', () {
    fit([3600, 8400], 0);
    final expanded = bounds;
    fit([8400], 18);
    fit([], 19);
    fit([double.nan, double.infinity], 30);
    expect(bounds, expanded);
    fit([8400], 31);
    expect(bounds, expanded);
    fit([8400], 33);
    expect(bounds.range, 2400);
  });

  test('a new analysis resets the old envelope', () {
    fit([0, 9000], 0);
    viewport.reset();
    fit([3600], 0);
    expect(bounds.range, 2400);
    containsAll([3600]);
  });
}
