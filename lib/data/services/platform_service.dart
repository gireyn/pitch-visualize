import 'package:flutter/services.dart';

/// A document copied from the system picker. Cancellation is represented by null.
class PickedFile {
  PickedFile({required this.name, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final String name;
  final Uint8List bytes;
}

/// Narrow native I/O boundary; inject a subclass or channels in application tests.
class PlatformService {
  PlatformService({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _methods = methodChannel ?? const MethodChannel('pitch_visual/platform'),
      _eventChannel = eventChannel ?? const EventChannel('pitch_visual/audio');

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  Stream<Map<String, Object?>>? _events;

  /// PCM is mono signed 16-bit little endian at the supplied actual sample rate.
  /// Interruptions include a reason (`background` or `audio`) and, when playback
  /// was active, a positionMs value that can be used to resume the recording.
  Stream<Map<String, Object?>> get events => _events ??= _eventChannel
      .receiveBroadcastStream()
      .map((event) => Map<String, Object?>.from(event as Map));

  Future<int> startCapture() async =>
      (await _methods.invokeMethod<num>('startCapture'))!.toInt();

  Future<void> stopCapture() => _methods.invokeMethod<void>('stopCapture');

  Future<void> play(String path, {int positionMs = 0}) => _methods
      .invokeMethod<void>('play', {'path': path, 'positionMs': positionMs});

  Future<int> pausePlayback() async =>
      (await _methods.invokeMethod<num>('pausePlayback'))!.toInt();

  Future<void> stopPlayback() => _methods.invokeMethod<void>('stopPlayback');

  Future<String> getStorageDirectory() async =>
      (await _methods.invokeMethod<String>('getStorageDirectory'))!;

  Future<PickedFile?> pickFile(String kind) async {
    final value = await _methods.invokeMapMethod<String, Object?>('pickFile', {
      'kind': kind,
    });
    if (value == null) return null;
    return PickedFile(
      name: value['name']! as String,
      bytes: value['bytes']! as Uint8List,
    );
  }

  Future<String?> loadPreferences() =>
      _methods.invokeMethod<String>('loadPreferences');

  Future<void> savePreferences(String json) =>
      _methods.invokeMethod<void>('savePreferences', {'json': json});

  Future<void> setKeepScreenOn(bool enabled) =>
      _methods.invokeMethod<void>('setKeepScreenOn', {'enabled': enabled});
}
