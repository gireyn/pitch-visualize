import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/monitor_settings.dart';
import 'monitor_controller.dart';

class PitchRangeTween extends Tween<RangeValues> {
  PitchRangeTween({required RangeValues begin, required RangeValues end})
    : super(begin: begin, end: end);

  @override
  RangeValues lerp(double t) => RangeValues(
    lerpDouble(begin!.start, end!.start, t)!,
    lerpDouble(begin!.end, end!.end, t)!,
  );
}

/// Moves the pitch viewport in plot coordinates, keeping the pinch focal pitch
/// under the fingers. Horizontal motion never changes the time axis.
class PitchRangeGesture extends StatefulWidget {
  const PitchRangeGesture({
    super.key,
    required this.controller,
    required this.baseRange,
    required this.plotPadding,
    required this.builder,
    this.minCents,
    this.maxCents,
    this.visibleViewport,
  });

  final MonitorController controller;
  final double baseRange;
  final EdgeInsets plotPadding;
  final double? minCents, maxCents;
  // Read the painted bounds when a gesture interrupts automatic animation.
  final RangeValues Function()? visibleViewport;
  final Widget Function(BuildContext context, bool interacting) builder;

  @override
  State<PitchRangeGesture> createState() => _PitchRangeGestureState();
}

class _PitchRangeGestureState extends State<PitchRangeGesture> {
  double _startZoom = 1, _anchorCents = 0;
  double _startBaseRange = 2400, _lastCenter = 0, _lastZoom = 1;
  bool _changed = false;
  final _team = GestureArenaTeam();
  final _pointers = <int>{};

  void _finish() {
    if (!_changed) return;
    setState(() => _changed = false);
    unawaited(widget.controller.savePitchRange());
  }

  void _pointerEnded(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) _finish();
  }

  double get _minZoom => widget.minCents != null && widget.maxCents != null
      ? math.max(
          MonitorSettings.minVerticalZoom,
          widget.baseRange / (widget.maxCents! - widget.minCents!),
        )
      : MonitorSettings.minVerticalZoom;

  double _clampCenter(double center, double range) => center.clamp(
    widget.minCents == null
        ? double.negativeInfinity
        : widget.minCents! + range / 2,
    widget.maxCents == null ? double.infinity : widget.maxCents! - range / 2,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = constraints.maxHeight - widget.plotPadding.vertical;
      double pitchFraction(double y) =>
          .5 - (y - widget.plotPadding.top) / height;
      return Semantics(
        hint: '双指竖直拉开放大、捏合缩小，上下拖动调整音域；手动调整后暂停自动跟随。',
        child: Listener(
          onPointerDown: (event) => _pointers.add(event.pointer),
          onPointerUp: _pointerEnded,
          onPointerCancel: _pointerEnded,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              ScaleGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                    () {
                      final recognizer = ScaleGestureRecognizer()..team = _team;
                      _team.captain = recognizer;
                      return recognizer;
                    },
                    (recognizer) => recognizer
                      ..onStart = (details) {
                        if (height <= 0) return;
                        _startZoom = widget.controller.settings.verticalZoom
                            .clamp(_minZoom, MonitorSettings.maxVerticalZoom);
                        final viewport = widget.visibleViewport?.call();
                        _startBaseRange = viewport == null
                            ? widget.baseRange
                            : (viewport.end - viewport.start) * _startZoom;
                        final range = _startBaseRange / _startZoom;
                        _lastCenter = _clampCenter(
                          viewport == null
                              ? widget.controller.centerCents
                              : (viewport.start + viewport.end) / 2,
                          range,
                        );
                        _lastZoom = _startZoom;
                        _anchorCents =
                            _lastCenter +
                            pitchFraction(details.localFocalPoint.dy) * range;
                      }
                      ..onUpdate = (details) {
                        if (height <= 0 || !details.verticalScale.isFinite) {
                          return;
                        }
                        final zoom = (_startZoom * details.verticalScale).clamp(
                          _minZoom,
                          MonitorSettings.maxVerticalZoom,
                        );
                        final range = _startBaseRange / zoom;
                        final center = _clampCenter(
                          _anchorCents -
                              pitchFraction(details.localFocalPoint.dy) * range,
                          range,
                        );
                        if ((zoom - _lastZoom).abs() < .000001 &&
                            (center - _lastCenter).abs() < .000001) {
                          return;
                        }
                        _lastZoom = zoom;
                        _lastCenter = center;
                        if (!_changed) setState(() => _changed = true);
                        widget.controller.adjustPitchRange(
                          center: center,
                          zoom: zoom,
                          baseRange: _startBaseRange,
                        );
                      }
                      ..onEnd = (details) {
                        if (details.pointerCount == 0) _finish();
                      },
                  ),
              // Let vertical drags claim the chart before an ancestor scroll
              // view. The scale recognizer handles both pan and pinch updates.
              VerticalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    VerticalDragGestureRecognizer
                  >(
                    () => VerticalDragGestureRecognizer()..team = _team,
                    (recognizer) => recognizer..onStart = (_) {},
                  ),
            },
            child: widget.builder(context, _changed),
          ),
        ),
      );
    },
  );
}
