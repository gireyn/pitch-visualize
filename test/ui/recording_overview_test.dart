import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/data/services/platform_service.dart';
import 'package:pitch_visual/domain/audio/pitch_worker.dart';
import 'package:pitch_visual/domain/audio/recording_analyzer.dart';
import 'package:pitch_visual/domain/models/wave_data.dart';
import 'package:pitch_visual/domain/pitch_math.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';

import '../data/fakes.dart';

class _TestAnalyzer extends RecordingAnalyzer {
  int calls = 0;
  Completer<List<PitchFrame>>? pending;
  Object? error;

  @override
  Future<List<PitchFrame>> analyze(WaveData wave, {required double threshold}) {
    calls++;
    if (error != null) return Future.error(error!);
    return pending?.future ?? super.analyze(wave, threshold: threshold);
  }
}

WaveData _recording(double seconds) {
  const rate = 8000;
  final pcm = Uint8List((rate * seconds).round() * 2);
  final data = ByteData.sublistView(pcm);
  for (var i = 0; i < pcm.length ~/ 2; i++) {
    final time = i / rate;
    final hz = time < seconds / 3 ? 220 : (time < 2 * seconds / 3 ? 0 : 660);
    data.setInt16(
      i * 2,
      (12000 * math.sin(2 * math.pi * hz * time)).round(),
      Endian.little,
    );
  }
  return WaveData(pcm: pcm, sampleRate: rate);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late FakePlatformService platform;
  late FakePitchWorker worker;
  late RecordingRepository repository;
  late _TestAnalyzer analyzer;
  late MonitorController controller;
  var disposed = false;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('recording-overview-');
    platform = FakePlatformService(folder.path);
    worker = FakePitchWorker();
    repository = RecordingRepository(platform);
    analyzer = _TestAnalyzer();
    controller = MonitorController(
      platform: platform,
      worker: worker,
      recordingAnalyzer: analyzer,
      recordingRepository: repository,
      settingsRepository: SettingsRepository(platform),
    );
    disposed = false;
    await controller.initialize();
  });

  tearDown(() async {
    if (!disposed) controller.dispose();
    await Future<void>.delayed(Duration.zero);
    await worker.close();
    await platform.close();
    await folder.delete(recursive: true);
  });

  test(
    'loads all file frames before playback and preserves the overview',
    () async {
      final entry = await repository.save(_recording(96));
      await controller.updateSetting('horizontalZoom', 2.0);
      await controller.updateSetting('scrollSpeed', 10);
      await controller.selectRecording(entry);
      expect(controller.hasRecordingOverview, isTrue);
      expect(controller.history, hasLength(2880));
      expect(controller.spectra, hasLength(2880));
      expect(controller.history.first.seconds, closeTo(1 / 30, 1e-9));
      expect(controller.history.last.seconds, 96);
      expect(controller.history[15].cents, closeTo(frequencyToCents(220), 10));
      expect(controller.history[1440].cents, isNull);
      expect(controller.history.last.cents, closeTo(frequencyToCents(660), 10));
      expect(controller.graphTime, 96);
      expect(controller.graphSeconds, 96);
      expect(controller.graphPlaybackTime, 0);
      expect(platform.playing, isFalse);
      expect(platform.capturing, isFalse);
      expect(platform.keepScreenOn, isFalse);

      final history = controller.history;
      final spectra = controller.spectra;
      await controller.updateSetting('showSpectrum', true);
      expect(controller.spectra, orderedEquals(spectra));
      await controller.togglePlayback();
      worker.frame(880, .1); // Late live frames cannot overwrite the file.
      expect(controller.history, orderedEquals(history));
      platform.pausePosition = 80000;
      await controller.togglePlayback();
      expect(controller.currentTime, 80);
      expect(controller.graphPlaybackTime, 80);
      expect(controller.frequency, closeTo(660, 2));
      expect(controller.history, orderedEquals(history));
      controller.toggleHold();
      expect(controller.graphTime, 96);
      await controller.togglePlayback();
      expect(platform.calls, contains('play:80000'));
      controller.toggleHold();
      platform.eventController.add({'type': 'playbackComplete'});
      expect(controller.graphPlaybackTime, 96);
      expect(controller.spectra, orderedEquals(spectra));
      await controller.togglePlayback();
      expect(controller.graphPlaybackTime, 0);
      await controller.stop();
      expect(controller.history, orderedEquals(history));
      expect(analyzer.calls, 1);
      expect(worker.blocks, isEmpty);

      await controller.startListening();
      expect(controller.hasRecordingOverview, isFalse);
      expect(controller.graphPlaybackTime, isNull);
      expect(controller.graphSeconds, 5);
      expect(controller.history, isEmpty);
      expect(controller.spectra, isEmpty);
      worker.frame(440, 1 / 30);
      expect(controller.history, hasLength(1));
    },
  );

  test(
    'import selects and analyzes the file while leaving live capture',
    () async {
      worker.frame(880, 1 / 30);
      final wave = _recording(1);
      platform.pickedFile = PickedFile(
        name: 'Imported.wav',
        bytes: wave.encode(),
      );
      await controller.importRecording();
      expect(controller.selectedRecording!.name, 'Imported.wav');
      expect(controller.hasRecordingOverview, isTrue);
      expect(controller.history, hasLength(30));
      expect(controller.graphSeconds, 1);
      expect(controller.mode, MonitorMode.idle);
      expect(platform.capturing, isFalse);
      await controller.deleteRecording(controller.selectedRecording!);
      expect(controller.hasRecordingOverview, isFalse);
      expect(controller.history, isEmpty);
      expect(controller.spectra, isEmpty);
    },
  );

  test('newly saved recording is fully analyzed when played', () async {
    await controller.toggleRecording();
    platform.pcm(Uint8List(44100 * 2));
    await controller.toggleRecording();
    expect(controller.hasRecordingOverview, isFalse);
    await controller.togglePlayback();
    expect(controller.hasRecordingOverview, isTrue);
    expect(controller.history, hasLength(30));
    expect(controller.graphTime, 1);
    expect(controller.isPlaying, isTrue);
  });

  test(
    'failed analysis keeps the previous file and releases loading state',
    () async {
      final first = await repository.save(_recording(.2));
      final second = await repository.save(_recording(.3));
      await controller.selectRecording(first);
      final previous = controller.history;
      analyzer.error = StateError('analysis failed');
      await controller.selectRecording(second);
      expect(controller.selectedRecording, same(first));
      expect(controller.history, orderedEquals(previous));
      expect(controller.message, isNotNull);
      expect(controller.busy, isFalse);
      expect(controller.analyzingRecording, isFalse);
    },
  );

  test('disposing during analysis cannot publish late results', () async {
    final entry = await repository.save(_recording(.2));
    analyzer.pending = Completer<List<PitchFrame>>();
    final started = Completer<void>();
    controller.addListener(() {
      if (controller.analyzingRecording && !started.isCompleted) {
        started.complete();
      }
    });
    final loading = controller.selectRecording(entry);
    await started.future;
    expect(controller.busy, isTrue);
    controller.dispose();
    disposed = true;
    analyzer.pending!.complete([]);
    await loading;
    expect(controller.hasRecordingOverview, isFalse);
    expect(controller.selectedRecording, isNull);
    expect(controller.analyzingRecording, isFalse);
  });
}
