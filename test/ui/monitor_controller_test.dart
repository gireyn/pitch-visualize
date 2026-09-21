import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/data/repositories/settings_repository.dart';
import 'package:pitch_visual/data/services/platform_service.dart';
import 'package:pitch_visual/domain/models/wave_data.dart';
import 'package:pitch_visual/domain/audio/log_spectrum.dart';
import 'package:pitch_visual/ui/features/monitor/monitor_controller.dart';

import '../data/fakes.dart';

Future<void> flushEvents() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class TestRecordingRepository extends RecordingRepository {
  TestRecordingRepository(super.platform);
  Object? saveError;

  @override
  Future<RecordingEntry> save(WaveData wave, {String? name}) {
    if (saveError != null) return Future.error(saveError!);
    return super.save(wave, name: name);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late FakePlatformService platform;
  late FakePitchWorker worker;
  late TestRecordingRepository recordings;
  late MonitorController controller;
  var disposed = false;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('pitch-controller-test-');
    platform = FakePlatformService(folder.path);
    worker = FakePitchWorker();
    recordings = TestRecordingRepository(platform);
    controller = MonitorController(
      platform: platform,
      worker: worker,
      settingsRepository: SettingsRepository(platform),
      recordingRepository: recordings,
    );
    disposed = false;
  });
  tearDown(() async {
    if (!disposed) controller.dispose();
    await flushEvents();
    await platform.close();
    await worker.close();
    await folder.delete(recursive: true);
  });

  test(
    'initialization starts continuous pitch analysis without recording',
    () async {
      await controller.initialize();
      expect(controller.initialized, isTrue);
      expect(worker.started, isTrue);
      expect(controller.mode, MonitorMode.listening);
      expect(platform.capturing, isTrue);
      expect(platform.keepScreenOn, isTrue);
      final samples = Uint8List(400);
      platform.pcm(samples);
      worker.frame(440, 1 / 30);
      worker.frame(442, 2 / 30);
      expect(worker.blocks.single, samples);
      expect(controller.history.length, 2);
      expect(controller.frequency, greaterThan(0));
      expect(controller.isRecording, isFalse);
      expect(controller.recordingSeconds, 0);
      expect(controller.recordings, isEmpty);
      expect(await recordings.list(), isEmpty);
      await controller.startListening();
      expect(platform.calls.where((call) => call == 'startCapture').length, 1);
      expect(controller.history.length, 2);
      await controller.stop();
      expect(await recordings.list(), isEmpty);
    },
  );

  test(
    'recording saves only audio between button presses and keeps measuring',
    () async {
      await controller.initialize();
      platform.pcm(Uint8List.fromList([1, 0, 2, 0]));
      worker.frame(440, 1 / 30);
      final resetsBeforeRecording = worker.resets;

      await controller.toggleRecording();
      expect(controller.isRecording, isTrue);
      final recordedSamples = Uint8List.fromList([3, 0, 4, 0]);
      platform.pcm(recordedSamples);
      worker.frame(441, 2 / 30);
      await controller.toggleRecording();

      platform.pcm(Uint8List.fromList([5, 0, 6, 0]));
      worker.frame(442, 3 / 30);
      expect(controller.mode, MonitorMode.listening);
      expect(platform.capturing, isTrue);
      expect(platform.keepScreenOn, isTrue);
      expect(platform.calls.where((call) => call == 'startCapture').length, 1);
      expect(worker.resets, resetsBeforeRecording);
      expect(controller.history.length, 3);
      expect(worker.blocks.length, 3);
      expect(controller.recordings.length, 1);
      expect(controller.recordingSeconds, recordedSamples.length / (44100 * 2));
      expect(
        (await recordings.load(controller.selectedRecording!)).pcm,
        recordedSamples,
      );
      await controller.stop();
      expect((await recordings.list()).length, 1);
    },
  );

  test(
    'startup permission denial recovers to idle and permits later retry',
    () async {
      platform.captureError = PlatformException(
        code: 'permission_denied',
        message: 'Microphone denied',
      );
      await controller.initialize();
      expect(controller.initialized, isTrue);
      expect(controller.mode, MonitorMode.idle);
      expect(controller.busy, isFalse);
      expect(controller.message, contains('Microphone denied'));
      expect(platform.keepScreenOn, isFalse);
      platform.captureError = null;
      await controller.startListening();
      expect(controller.mode, MonitorMode.listening);
      expect(controller.message, isNull);
    },
  );

  test('background event during pending permission ends capture after permission settles', () async {
    platform.pendingCapture = Completer<int>();
    final starting = controller.initialize();
    await flushEvents();
    expect(controller.busy, isTrue);
    final suspended = controller.suspend();
    platform.pendingCapture!.complete(44100);
    await Future.wait([starting, suspended]);
    expect(controller.mode, MonitorMode.idle);
    expect(platform.capturing, isFalse);
    expect(platform.keepScreenOn, isFalse);
    platform.pendingCapture = null;
    await controller.resume();
    expect(controller.mode, MonitorMode.listening);
  });

  test(
    'disposing during pending initialization does not attach audio listeners',
    () async {
      worker.pendingStart = Completer<void>();
      final initialization = controller.initialize();
      await flushEvents();
      controller.dispose();
      disposed = true;
      worker.pendingStart!.complete();
      await initialization;
      await flushEvents();
      expect(controller.initialized, isFalse);
      expect(platform.eventController.hasListener, isFalse);
      expect(worker.frameController.hasListener, isFalse);
      expect(worker.disposed, isTrue);
      expect(platform.keepScreenOn, isFalse);
    },
  );

  test(
    'capture records, saves, plays, pauses and resumes from native position',
    () async {
      await controller.initialize();
      await controller.toggleRecording();
      final samples = Uint8List(44100 * 2);
      samples[3] = 32;
      platform.pcm(samples);
      expect(controller.recordingSeconds, 1);
      expect(worker.blocks.single, samples);
      await controller.toggleRecording();
      expect(controller.mode, MonitorMode.listening);
      expect(controller.recordings.length, 1);
      expect(
        (await recordings.load(controller.selectedRecording!)).pcm,
        samples,
      );
      await controller.togglePlayback();
      expect(controller.mode, MonitorMode.playing);
      expect(platform.capturing, isFalse);
      expect(platform.playing, isTrue);
      await controller.togglePlayback();
      expect(controller.mode, MonitorMode.paused);
      expect(platform.keepScreenOn, isFalse);
      await controller.togglePlayback();
      expect(controller.mode, MonitorMode.playing);
      expect(
        platform.calls.lastWhere((call) => call.startsWith('play:')),
        'play:100',
      );
    },
  );

  test('stopping an empty recording does not create an invalid WAV', () async {
    await controller.initialize();
    await controller.toggleRecording();
    await controller.stop();
    expect(controller.recordings, isEmpty);
    expect(controller.mode, MonitorMode.idle);
    expect(platform.keepScreenOn, isFalse);
  });

  for (final background in [false, true]) {
    test(
      '${background ? 'backgrounding' : 'stopping'} releases audio even if saving fails',
      () async {
        await controller.initialize();
        await controller.toggleRecording();
        platform.pcm(Uint8List(400));
        recordings.saveError = const FileSystemException('Storage full');
        if (background) {
          await controller.suspend();
        } else {
          await controller.stop();
        }
        expect(platform.capturing, isFalse);
        expect(platform.keepScreenOn, isFalse);
        expect(controller.mode, MonitorMode.idle);
        expect(controller.message, contains('Storage full'));
      },
    );
  }

  test(
    'interruption overrides automatic resume from an already queued suspend',
    () async {
      await controller.initialize();
      await controller.startListening();
      final suspending = controller.suspend();
      platform.eventController.add({'type': 'interrupted'});
      await suspending;
      await controller.resume();
      expect(controller.mode, MonitorMode.idle);
      expect(platform.capturing, isFalse);
    },
  );

  test(
    'backgrounding a recording saves it then resumes in listening mode',
    () async {
      await controller.initialize();
      await controller.toggleRecording();
      platform.pcm(Uint8List(400));
      await controller.suspend();
      expect(controller.recordings.length, 1);
      expect(controller.mode, MonitorMode.idle);
      await controller.resume();
      expect(controller.mode, MonitorMode.listening);
      expect(controller.isRecording, isFalse);
    },
  );

  test(
    'system interruption saves recording and retains interruption explanation',
    () async {
      await controller.initialize();
      await controller.toggleRecording();
      platform.pcm(Uint8List(400));
      platform.eventController.add({'type': 'interrupted'});
      await controller.updateSetting(
        'bpm',
        120,
      ); // joins serialized work after stop
      expect(controller.mode, MonitorMode.idle);
      expect(controller.recordings.length, 1);
      expect(controller.message, contains('中断'));
      await controller.resume();
      expect(controller.mode, MonitorMode.idle);
    },
  );

  test(
    'audio-time pitch frames remain spaced when delivered in one batch',
    () async {
      await controller.initialize();
      await controller.startListening();
      worker.frame(440, 1 / 30);
      worker.frame(441, 2 / 30);
      worker.frame(442, 3 / 30);
      expect(controller.history.map((point) => point.seconds), [
        1 / 30,
        2 / 30,
        3 / 30,
      ]);
    },
  );

  test('hold freezes spectrum and resumes with live frames, including unvoiced audio', () async {
    await controller.initialize();
    await controller.startListening();
    final spectrum = Uint8List(LogSpectrum.bands)..[200] = 200;
    worker.frame(440, 1 / 30, spectrum: spectrum.asUnmodifiableView());
    controller.toggleHold();
    final frozen = controller.spectra;
    final frozenTime = controller.graphTime;
    worker.frame(-1, 2 / 30, spectrum: Uint8List(LogSpectrum.bands));
    expect(controller.spectra, frozen);
    expect(controller.graphTime, frozenTime);
    expect(controller.isCapturing, isTrue);
    controller.toggleHold();
    expect(controller.spectra.length, 2);
    expect(controller.spectra.first.bands[200], 200);
    expect(controller.spectra.last.bands, everyElement(0));
    expect(controller.spectra.map((point) => point.seconds), [1 / 30, 2 / 30]);
    await controller.stop();
    await controller.startListening();
    expect(controller.spectra, isEmpty);
  });

  test(
    'spectrum retains bounded history and disabling hold restores live data',
    () async {
      await controller.initialize();
      await controller.startListening();
      final spectrum = Uint8List(LogSpectrum.bands).asUnmodifiableView();
      worker.frame(440, 1 / 30, spectrum: spectrum);
      controller.toggleHold();
      for (var i = 2; i <= 2710; i++) {
        worker.frame(-1, i / 30, spectrum: spectrum);
      }
      expect(controller.spectra.length, 1);
      await controller.updateSetting('showHold', false);
      expect(controller.held, isFalse);
      expect(controller.spectra.length, 2700);
      expect(controller.spectra.first.seconds, 11 / 30);
    },
  );

  test(
    'selecting another recording clears a held trace from previous audio',
    () async {
      final entry = await recordings.save(
        WaveData(pcm: Uint8List(400), sampleRate: 44100),
      );
      await controller.initialize();
      await controller.startListening();
      worker.frame(440, 1 / 30, spectrum: Uint8List(LogSpectrum.bands));
      controller.toggleHold();
      await controller.selectRecording(entry);
      expect(controller.history, isEmpty);
      expect(controller.spectra, isEmpty);
      expect(controller.held, isFalse);
      expect(controller.currentTime, 0);
      expect(controller.selectedRecording!.path, entry.path);
    },
  );

  test('failed setting persistence keeps active preference intact', () async {
    await controller.initialize();
    platform.saveError = StateError('Storage full');
    await controller.updateSetting('bpm', 160);
    expect(controller.settings.bpm, 120);
    expect(controller.message, contains('Storage full'));
    expect(controller.busy, isFalse);
  });

  test(
    'invalid tuning import keeps active scale and reports failure',
    () async {
      await controller.initialize();
      final original = controller.scale;
      platform.pickedFile = PickedFile(
        name: 'broken.txt',
        bytes: Uint8List.fromList('broken'.codeUnits),
      );
      await controller.importScale();
      expect(controller.scale, same(original));
      expect(controller.message, isNotNull);
    },
  );

  test('native playback completion releases screen and selected recording can play again', () async {
    final entry = await recordings.save(
      WaveData(pcm: Uint8List(400), sampleRate: 44100),
    );
    await controller.initialize();
    await controller.selectRecording(entry);
    await controller.togglePlayback();
    platform.eventController.add({'type': 'playbackComplete'});
    await flushEvents();
    expect(controller.mode, MonitorMode.idle);
    expect(controller.currentTime, controller.duration);
    expect(platform.keepScreenOn, isFalse);
    await controller.togglePlayback();
    expect(controller.mode, MonitorMode.playing);
    expect(
      platform.calls.lastWhere((call) => call.startsWith('play:')),
      'play:0',
    );
  });
}
