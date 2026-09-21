import 'dart:async';
import 'dart:typed_data';

import 'package:pitch_visual/data/services/platform_service.dart';
import 'package:pitch_visual/domain/audio/pitch_worker.dart';

class FakePlatformService extends PlatformService {
  FakePlatformService(this.storagePath);
  final String storagePath;
  final eventController = StreamController<Map<String, Object?>>.broadcast(
    sync: true,
  );
  final calls = <String>[];
  String? preferences;
  Object? preferencesError;
  Object? captureError;
  Object? saveError;
  Completer<int>? pendingCapture;
  PickedFile? pickedFile;
  bool keepScreenOn = false;
  bool capturing = false;
  bool playing = false;
  int rate = 44100;
  int pausePosition = 100;

  @override
  Stream<Map<String, Object?>> get events => eventController.stream;
  @override
  Future<String> getStorageDirectory() async => storagePath;
  @override
  Future<String?> loadPreferences() async {
    if (preferencesError != null) throw preferencesError!;
    return preferences;
  }

  @override
  Future<void> savePreferences(String json) async {
    if (saveError != null) throw saveError!;
    preferences = json;
  }

  @override
  Future<int> startCapture() async {
    calls.add('startCapture');
    if (captureError != null) throw captureError!;
    final result = pendingCapture == null ? rate : await pendingCapture!.future;
    capturing = true;
    return result;
  }

  @override
  Future<void> stopCapture() async {
    calls.add('stopCapture');
    capturing = false;
  }

  @override
  Future<void> play(String path, {int positionMs = 0}) async {
    calls.add('play:$positionMs');
    playing = true;
  }

  @override
  Future<int> pausePlayback() async {
    calls.add('pausePlayback');
    playing = false;
    return pausePosition;
  }

  @override
  Future<void> stopPlayback() async {
    calls.add('stopPlayback');
    playing = false;
  }

  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    calls.add('screen:$enabled');
    keepScreenOn = enabled;
  }

  @override
  Future<PickedFile?> pickFile(String kind) async => pickedFile;
  void pcm(Uint8List data, {int? sampleRate}) => eventController.add({
    'type': 'pcm',
    'data': data,
    'sampleRate': sampleRate ?? rate,
  });
  Future<void> close() => eventController.close();
}

class FakePitchWorker extends PitchWorker {
  final frameController = StreamController<PitchFrame>.broadcast(sync: true);
  final blocks = <Uint8List>[];
  final rates = <int>[];
  Completer<void>? pendingStart;
  bool started = false;
  bool disposed = false;
  int resets = 0;

  @override
  Stream<PitchFrame> get frames => frameController.stream;
  @override
  Future<void> start() async {
    await pendingStart?.future;
    started = true;
  }

  @override
  void addPcm(Uint8List pcm, int sampleRate) {
    blocks.add(Uint8List.fromList(pcm));
    rates.add(sampleRate);
  }

  @override
  void reset() {
    resets++;
  }

  void frame(double frequency, double seconds, {Uint8List? spectrum}) =>
      frameController.add(
        PitchFrame(
          frequency: frequency,
          level: .2,
          timeSeconds: seconds,
          spectrum: spectrum,
        ),
      );
  @override
  Future<void> dispose() async {
    disposed = true;
  }

  Future<void> close() => frameController.close();
}
