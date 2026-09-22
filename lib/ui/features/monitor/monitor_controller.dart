import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/recording_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/platform_service.dart';
import '../../../domain/audio/pitch_worker.dart';
import '../../../domain/audio/log_spectrum.dart';
import '../../../domain/models/monitor_settings.dart';
import '../../../domain/models/app_exception.dart';
import '../../../domain/models/wave_data.dart';
import '../../../domain/pitch_math.dart';
import '../../../domain/tuning/scale_config.dart';
import '../../../l10n/app_message.dart';
import '../../../l10n/l10n.dart';
import 'history_viewport.dart';

enum MonitorMode { idle, listening, recording, playing, paused }

@immutable
class PitchPoint {
  const PitchPoint(this.seconds, this.cents);
  final double seconds;
  final double? cents;
}

class MonitorController extends ChangeNotifier {
  MonitorController({
    required this.platform,
    required this.settingsRepository,
    required this.recordingRepository,
    PitchWorker? worker,
  }) : _worker = worker ?? PitchWorker();
  final PlatformService platform;
  final SettingsRepository settingsRepository;
  final RecordingRepository recordingRepository;
  final PitchWorker _worker;
  MonitorSettings settings = const MonitorSettings();
  ScaleConfig? scale;
  MonitorMode mode = MonitorMode.idle;
  bool initialized = false, busy = false, held = false;
  AppMessage? message;
  double frequency = 0, level = 0, currentTime = 0, centerCents = 3600;
  ScaleNote? note;
  double deviation = 0;
  int beat = 0;
  double beatPhase = 0;
  List<RecordingEntry> recordings = [];
  RecordingEntry? selectedRecording;
  final List<PitchPoint> _history = [];
  final _historyViewport = HistoryViewport();
  double _historyBaseRange = 2400;
  // Automatic fitting is transient; it must not rewrite the saved zoom.
  double get historyBaseRange => _historyBaseRange;
  double get historyRange => _historyBaseRange / settings.verticalZoom;
  List<PitchPoint>? _heldHistory;
  final List<SpectrumPoint> _spectra = [];
  List<SpectrumPoint>? _heldSpectra;
  int _spectrumSequence = 0;
  List<SpectrumPoint> get spectra =>
      List.unmodifiable(_heldSpectra ?? _spectra);
  double _heldTime = 0;
  double _analysisTimeOffset = 0;
  final List<double> _smoothedCents = [];
  List<PitchPoint> get history => List.unmodifiable(_heldHistory ?? _history);
  double get graphTime => held ? _heldTime : currentTime;
  double get graphSeconds =>
      (18 / settings.horizontalZoom) * (5 / settings.scrollSpeed);
  bool get isCapturing =>
      mode == MonitorMode.listening || mode == MonitorMode.recording;
  bool get isRecording => mode == MonitorMode.recording;
  bool get isPlaying => mode == MonitorMode.playing;
  bool get canPlay => selectedRecording != null;
  double get recordingSeconds =>
      _recordedBytes / (math.max(1, _sampleRate) * 2);
  double get duration => _playbackWave?.durationSeconds ?? 0;
  final Stopwatch _clock = Stopwatch();
  final Stopwatch _playbackClock = Stopwatch();
  StreamSubscription<Map<String, Object?>>? _events;
  StreamSubscription<PitchFrame>? _frames;
  Timer? _tick;
  BytesBuilder? _recordBuffer;
  int _recordedBytes = 0, _sampleRate = 44100;
  WaveData? _playbackWave;
  int _playbackOffsetMs = 0, _playbackRead = 0;
  bool _disposed = false, _resumeCapture = false;
  bool _interrupted = false;
  int? _interruptedPositionMs;
  WaveData? _pendingRecording;
  bool get hasPendingRecording => _pendingRecording != null;
  Future<void> _queue = Future.value();

  Future<void> initialize() async {
    await _run(() async {
      final saved = await settingsRepository.load();
      if (_disposed) return;
      settings = saved.settings;
      scale = saved.scale;
      message = saved.notice;
      centerCents = scale!.noteAt(0, scale!.referenceOctave).cents;
      await _worker.start();
      if (_disposed) {
        await _worker.dispose();
        return;
      }
      _worker.threshold = settings.threshold;
      _frames = _worker.frames.listen(
        _onFrame,
        onError: (Object error) {
          _report(error);
        },
      );
      _events = platform.events.listen(
        _onEvent,
        onError: (Object error) {
          _report(error);
        },
      );
      recordings = await recordingRepository.list();
      if (_disposed) return;
      initialized = true;
      _tick = Timer.periodic(
        const Duration(milliseconds: 33),
        (_) => _onTick(),
      );
      await _startCapture();
    });
  }

  Future<void> _run(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      if (_disposed) return;
      busy = true;
      _notify();
      try {
        await action();
      } catch (error) {
        _report(error);
      } finally {
        busy = false;
        _notify();
      }
    });
    return _queue;
  }

  void _report(Object error) {
    message = AppMessage.error(error);
    _notify();
  }

  void clearMessage() {
    message = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _clearAnalysis() {
    _worker.reset();
    _history.clear();
    _historyViewport.reset();
    _historyBaseRange = 2400;
    _heldHistory = null;
    _spectra.clear();
    _heldSpectra = null;
    held = false;
    frequency = 0;
    level = 0;
    note = null;
    currentTime = 0;
    _analysisTimeOffset = 0;
    _smoothedCents.clear();
    _clock
      ..reset()
      ..start();
  }

  Future<void> _startCapture({bool clear = true}) async {
    await platform.stopPlayback();
    if (clear) _clearAnalysis();
    _sampleRate = await platform.startCapture();
    if (clear) {
      _clock
        ..reset()
        ..start();
    }
    mode = MonitorMode.listening;
    await platform.setKeepScreenOn(true);
  }

  Future<void> startListening() => _run(() async {
    if (isCapturing) return;
    message = null;
    _interrupted = false;
    await _startCapture();
  });
  Future<void> toggleRecording() => _run(() async {
    if (isRecording) {
      await _finishRecording();
      return;
    }
    if (_pendingRecording != null) await _savePendingRecording();
    _interrupted = false;
    if (!isCapturing) await _startCapture();
    _recordBuffer = BytesBuilder(copy: false);
    _recordedBytes = 0;
    mode = MonitorMode.recording;
  });
  Future<void> _finishRecording() async {
    final buffer = _recordBuffer;
    _recordBuffer = null;
    if (mode == MonitorMode.recording) mode = MonitorMode.listening;
    if (buffer == null || buffer.isEmpty) return;
    _pendingRecording = WaveData(
      pcm: buffer.takeBytes(),
      sampleRate: _sampleRate,
    );
    await _savePendingRecording();
  }

  Future<void> retrySaveRecording() => _run(_savePendingRecording);
  Future<void> _savePendingRecording() async {
    final wave = _pendingRecording;
    if (wave == null) return;
    selectedRecording = await recordingRepository.save(wave);
    _pendingRecording = null;
    _playbackWave = wave;
    _playbackOffsetMs = 0;
    recordings = await recordingRepository.list();
    final name = selectedRecording!.name;
    message = AppMessage((strings) => strings.noticeRecordingSaved(name));
  }

  Future<void> stop() {
    _resumeCapture = false;
    return _run(_stopAudio);
  }

  Future<void> _stopAudio() async {
    try {
      await platform.stopCapture();
      if (isRecording) await _finishRecording();
    } finally {
      mode = MonitorMode.idle;
      _playbackClock.stop();
      _clock.stop();
      _worker.reset();
      _playbackOffsetMs = 0;
      frequency = 0;
      level = 0;
      note = null;
      try {
        await platform.stopPlayback();
      } finally {
        await platform.setKeepScreenOn(false);
      }
    }
  }

  void _stopWithMessage(AppMessage reason) {
    _resumeCapture = false;
    unawaited(
      _run(() async {
        await _stopAudio();
        message = reason;
      }),
    );
  }

  Future<void> togglePlayback() => _run(() async {
    if (isPlaying) {
      _playbackOffsetMs = await platform.pausePlayback();
      _playbackClock.stop();
      _worker.reset();
      mode = MonitorMode.paused;
      await platform.setKeepScreenOn(false);
      return;
    }
    if (isRecording) await _finishRecording();
    if (selectedRecording == null) return;
    await platform.stopCapture();
    mode = MonitorMode.idle;
    _playbackWave ??= await recordingRepository.load(selectedRecording!);
    if (_playbackOffsetMs == 0) _clearAnalysis();
    _playbackRead = (_playbackOffsetMs * _playbackWave!.sampleRate ~/ 1000) * 2;
    _worker.reset();
    _interruptedPositionMs = null;
    _interrupted = false;
    _smoothedCents.clear();
    _analysisTimeOffset = _playbackOffsetMs / 1000;
    await platform.play(selectedRecording!.path, positionMs: _playbackOffsetMs);
    _playbackClock
      ..reset()
      ..start();
    mode = MonitorMode.playing;
    await platform.setKeepScreenOn(true);
  });
  Future<void> selectRecording(RecordingEntry entry) => _run(() async {
    if (isRecording) await _finishRecording();
    await platform.stopCapture();
    await platform.stopPlayback();
    mode = MonitorMode.idle;
    _clock.stop();
    _playbackClock.stop();
    await platform.setKeepScreenOn(false);
    final wave = await recordingRepository.load(entry);
    selectedRecording = entry;
    _playbackWave = wave;
    _playbackOffsetMs = 0;
    _history.clear();
    _heldHistory = null;
    _spectra.clear();
    _heldSpectra = null;
    held = false;
    _worker.reset();
    _smoothedCents.clear();
    currentTime = 0;
    frequency = 0;
    note = null;
  });
  Future<void> deleteRecording(RecordingEntry entry) => _run(() async {
    if (selectedRecording?.path == entry.path) {
      await platform.stopPlayback();
      _playbackClock.stop();
      if (mode == MonitorMode.playing || mode == MonitorMode.paused) {
        mode = MonitorMode.idle;
        await platform.setKeepScreenOn(false);
      }
      selectedRecording = null;
      _playbackWave = null;
      _playbackOffsetMs = 0;
    }
    await recordingRepository.delete(entry);
    recordings = await recordingRepository.list();
  });
  Future<void> importRecording() => _run(() async {
    final file = await platform.pickFile('audio');
    if (file == null) return;
    final wave = WaveData.decode(file.bytes);
    final entry = await recordingRepository.save(wave, name: file.name);
    recordings = await recordingRepository.list();
    if (!isCapturing && !isPlaying) {
      selectedRecording = entry;
      _playbackWave = wave;
      _playbackOffsetMs = 0;
    }
    message = AppMessage(
      (strings) => strings.noticeRecordingImported(entry.name),
    );
  });

  Future<void> importScale() => _run(() async {
    final file = await platform.pickFile('tuning');
    if (file == null) return;
    if (file.bytes.length > 1024 * 1024) {
      throw const AppFormatException(
        AppFormatError.tuningTooLarge,
        'Tuning file exceeds 1 MB',
      );
    }
    final next = ScaleConfig.parse(
      utf8.decode(file.bytes),
      file.name.replaceFirst(
        RegExp(r'\.(txt|json)$', caseSensitive: false),
        '',
      ),
    );
    await _applyScale(next);
  });
  Future<void> useBundledScale(bool tiangan) => _run(
    () async => _applyScale(await settingsRepository.bundledScale(tiangan)),
  );
  Future<void> useEdoScale() =>
      _run(() async => _applyScale(ScaleConfig.equalDivision(settings.edo)));
  Future<void> _applyScale(ScaleConfig next) async {
    await settingsRepository.save(settings, next);
    scale = next;
    centerCents = next.noteAt(0, next.referenceOctave).cents;
    _updateNote();
    message = AppMessage(
      (strings) => strings.noticeScaleApplied(strings.scaleName(next.name)),
    );
  }

  Future<void> updateSetting(String key, Object value) => _run(() async {
    final next = settings.withValue(key, value);
    final nextScale = key == 'edo' && scale?.edo != null
        ? ScaleConfig.equalDivision(next.edo)
        : scale;
    if (nextScale != null) await settingsRepository.save(next, nextScale);
    settings = next;
    if (scale != nextScale) {
      scale = nextScale;
      _updateNote();
    }
    if (key == 'showSpectrum' ||
        key == 'verticalZoom' ||
        (key == 'autoScroll' && settings.autoScroll)) {
      _historyViewport.reset();
    }
    _worker.threshold = settings.threshold;
    if (!settings.showHold) {
      held = false;
      _heldHistory = null;
      _heldSpectra = null;
    }
    _fitHistoryViewport();
  });
  void toggleHold() {
    held = !held;
    _heldHistory = held ? List.of(_history) : null;
    _heldSpectra = held ? List.of(_spectra) : null;
    if (held) _heldTime = currentTime;
    _fitHistoryViewport();
    _notify();
  }

  void panRange(double cents) {
    centerCents += cents;
    _notify();
  }

  void adjustPitchRange({
    required double center,
    required double zoom,
    double? baseRange,
  }) {
    if (!center.isFinite || !zoom.isFinite) return;
    if (!settings.showSpectrum &&
        baseRange != null &&
        baseRange.isFinite &&
        baseRange > 0) {
      _historyBaseRange = baseRange;
    }
    centerCents = center;
    settings = settings
        .withValue('verticalZoom', zoom)
        .withValue('autoScroll', false);
    _notify();
  }

  // Apply every gesture frame immediately; only touch storage on release.
  Future<void> savePitchRange() => _run(() async {
    if (scale != null) await settingsRepository.save(settings, scale!);
  });

  void _updateNote() {
    if (frequency <= 0 || scale == null) {
      note = null;
      deviation = 0;
      return;
    }
    final cents = frequencyToCents(frequency);
    note = scale!.nearestNote(cents);
    deviation = cents - note!.cents;
  }

  void _onFrame(PitchFrame frame) {
    if (_disposed || (!isCapturing && !isPlaying)) return;
    final voiced = frame.frequency > 0 && frame.frequency.isFinite;
    level = frame.level;
    final cents = voiced ? frequencyToCents(frame.frequency) : null;
    if (!held) {
      if (cents == null) {
        _smoothedCents.clear();
        frequency = 0;
      } else {
        if (_smoothedCents.isNotEmpty &&
            (cents - _smoothedCents.last).abs() > 300) {
          _smoothedCents.clear();
        }
        _smoothedCents.add(cents);
        while (_smoothedCents.length > settings.smoothing) {
          _smoothedCents.removeAt(0);
        }
        frequency = centsToFrequency(
          _smoothedCents.reduce((a, b) => a + b) / _smoothedCents.length,
        );
      }
    }
    _history.add(PitchPoint(_analysisTimeOffset + frame.timeSeconds, cents));
    final spectrum = frame.spectrum;
    if (spectrum != null && spectrum.length == LogSpectrum.bands) {
      _spectra.add(
        SpectrumPoint(
          _spectrumSequence++,
          _analysisTimeOffset + frame.timeSeconds,
          spectrum,
        ),
      );
      if (_spectra.length > 2700) {
        _spectra.removeRange(0, _spectra.length - 2700);
      }
    }
    if (_history.length > 2700) _history.removeRange(0, _history.length - 2700);
    if (!held) {
      _updateNote();
      if (settings.showSpectrum && settings.autoScroll && cents != null) {
        final margin = 600 / settings.verticalZoom;
        if ((cents - centerCents).abs() > margin) centerCents = cents;
      }
      _fitHistoryViewport();
    }
    _notify();
  }

  void _fitHistoryViewport() {
    if (held || !settings.autoScroll || settings.showSpectrum) return;
    final time = math.max(
      graphTime,
      _history.isEmpty ? 0.0 : _history.last.seconds,
    );
    final fitted = _historyViewport.fit(
      pitches: _history
          .where((point) => point.seconds >= time - graphSeconds)
          .map((point) => point.cents)
          .whereType<double>(),
      time: time,
      center: centerCents,
      range: historyRange,
      minimumRange: 2400 / settings.verticalZoom,
    );
    centerCents = fitted.center;
    _historyBaseRange = fitted.range * settings.verticalZoom;
  }

  void _onEvent(Map<String, Object?> event) {
    if (_disposed) return;
    switch (event['type']) {
      case 'pcm':
        if (!isCapturing) return;
        final data = event['data'] as Uint8List;
        final rate = (event['sampleRate'] as num).toInt();
        _worker.addPcm(data, rate);
        if (isRecording && _recordBuffer != null) {
          if (rate != _sampleRate) {
            _stopWithMessage(
              AppMessage((strings) => strings.noticeAudioDeviceChanged),
            );
            return;
          }
          final remaining = WaveData.maxSeconds * rate * 2 - _recordedBytes;
          final length = math.min(remaining, data.length) & ~1;
          if (length > 0) {
            _recordBuffer!.add(Uint8List.sublistView(data, 0, length));
            _recordedBytes += length;
          }
          if (_recordedBytes >= WaveData.maxSeconds * rate * 2) {
            unawaited(stop());
          }
        }
      case 'playbackComplete':
        if (isPlaying) {
          mode = MonitorMode.idle;
          _playbackClock.stop();
          _playbackOffsetMs = 0;
          currentTime = duration;
          frequency = 0;
          note = null;
          unawaited(platform.setKeepScreenOn(false));
          _notify();
        }
      case 'interrupted':
        _interrupted = true;
        _resumeCapture = false;
        if (event['positionMs'] case final num position) {
          _interruptedPositionMs = position.toInt();
        }
        if (isPlaying || mode == MonitorMode.paused) {
          _playbackOffsetMs =
              _interruptedPositionMs ??
              (_playbackOffsetMs + _playbackClock.elapsedMilliseconds);
          _playbackClock.stop();
          _worker.reset();
          mode = MonitorMode.paused;
          message = AppMessage((strings) => strings.noticePlaybackInterrupted);
          unawaited(platform.setKeepScreenOn(false));
          _notify();
        } else {
          _stopWithMessage(
            AppMessage((strings) => strings.noticeAudioInterrupted),
          );
        }
      case 'error':
        _interrupted = true;
        _stopWithMessage(
          AppMessage.audioError(
            code: event['code'] as String?,
            details: event['message'] as String?,
          ),
        );
    }
  }

  void _onTick() {
    if (_disposed) return;
    if (isCapturing) currentTime = _clock.elapsedMicroseconds / 1000000;
    if (isPlaying && _playbackWave != null) {
      final wave = _playbackWave!;
      final milliseconds =
          _playbackOffsetMs + _playbackClock.elapsedMilliseconds;
      currentTime = milliseconds / 1000;
      final target =
          math.min(
            wave.pcm.length,
            milliseconds * wave.sampleRate ~/ 1000 * 2,
          ) &
          ~1;
      if (target > _playbackRead) {
        // Bound catch-up work after a stalled frame; the worker discards old
        // queued blocks if necessary while maintaining the source timeline.
        while (_playbackRead < target) {
          final end = math.min(target, _playbackRead + 32768);
          _worker.addPcm(
            Uint8List.sublistView(wave.pcm, _playbackRead, end),
            wave.sampleRate,
          );
          _playbackRead = end;
        }
      }
    }
    if (isCapturing || isPlaying) {
      final progress = currentTime * settings.bpm / 60;
      beat = settings.beatsPerBar == 0
          ? 0
          : progress.floor() % settings.beatsPerBar;
      beatPhase = progress % 1;
      _fitHistoryViewport();
      _notify();
    }
  }

  Future<void> suspend() => _run(() async {
    _resumeCapture = isCapturing && !_interrupted;
    try {
      if (isPlaying) {
        final nativePosition = await platform.pausePlayback();
        _playbackOffsetMs = _interruptedPositionMs ?? nativePosition;
        mode = MonitorMode.paused;
        _playbackClock.stop();
      } else if (mode != MonitorMode.paused) {
        await platform.stopCapture();
        if (isRecording) await _finishRecording();
      }
    } finally {
      if (mode != MonitorMode.paused) mode = MonitorMode.idle;
      _clock.stop();
      _worker.reset();
      await platform.setKeepScreenOn(false);
    }
  });
  Future<void> resume() => _run(() async {
    if (_resumeCapture && !_interrupted) {
      _resumeCapture = false;
      await _startCapture();
    }
  });
  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    unawaited(_events?.cancel());
    unawaited(_frames?.cancel());
    unawaited(_worker.dispose());
    unawaited(
      _queue
          .then((_) async {
            await platform.stopCapture();
            await platform.stopPlayback();
            await platform.setKeepScreenOn(false);
          })
          .catchError((Object _) {}),
    );
    super.dispose();
  }
}
