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
import '../../../domain/audio/recording_analyzer.dart';
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
    RecordingAnalyzer? recordingAnalyzer,
  }) : _worker = worker ?? PitchWorker(),
       _recordingAnalyzer = recordingAnalyzer ?? const RecordingAnalyzer();
  final PlatformService platform;
  final SettingsRepository settingsRepository;
  final RecordingRepository recordingRepository;
  final PitchWorker _worker;
  final RecordingAnalyzer _recordingAnalyzer;
  MonitorSettings settings = const MonitorSettings();
  ScaleConfig? scale;
  MonitorMode mode = MonitorMode.idle;
  bool initialized = false, busy = false, held = false;
  bool analyzingRecording = false;
  AppMessage? _message;
  AppMessage? get message => _message;
  set message(AppMessage? value) {
    _message = value;
    _scheduleMessageDismissal();
  }

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
  List<PitchFrame>? _recordingFrames;
  int _playbackFrameIndex = -1;
  bool get hasRecordingOverview => _recordingFrames != null;
  final List<double> _smoothedCents = [];
  List<PitchPoint> get history => List.unmodifiable(_heldHistory ?? _history);
  double get graphTime =>
      hasRecordingOverview ? graphSeconds : (held ? _heldTime : currentTime);
  double get graphSeconds => hasRecordingOverview
      ? (duration > 0 ? duration : 1)
      : (20 / settings.horizontalZoom) * (5 / settings.scrollSpeed);
  double? get graphPlaybackTime =>
      hasRecordingOverview ? (held ? _heldTime : currentTime) : null;
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
  Timer? _messageTimer;
  BytesBuilder? _recordBuffer;
  int _recordedBytes = 0, _sampleRate = 44100;
  WaveData? _playbackWave;
  int _playbackOffsetMs = 0;
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
      _scheduleMessageDismissal();
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

  void _scheduleMessageDismissal() {
    _messageTimer?.cancel();
    _messageTimer = null;
    // Initialization failures are shown beside Retry, outside the banner.
    if (_disposed || !initialized || message == null) return;
    _messageTimer = Timer(const Duration(seconds: 5), clearMessage);
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
    _recordingFrames = null;
    _playbackFrameIndex = -1;
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
      if (hasRecordingOverview) currentTime = 0;
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
      currentTime = (_playbackOffsetMs / 1000).clamp(0.0, duration);
      _updatePlaybackReadout();
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
    if (!hasRecordingOverview) {
      await _loadRecording(selectedRecording!, wave: _playbackWave);
      if (_disposed) return;
    }
    _worker.reset();
    _interruptedPositionMs = null;
    _interrupted = false;
    _smoothedCents.clear();
    _playbackFrameIndex = -1;
    currentTime = (_playbackOffsetMs / 1000).clamp(0.0, duration);
    _updatePlaybackReadout();
    await platform.play(selectedRecording!.path, positionMs: _playbackOffsetMs);
    _playbackClock
      ..reset()
      ..start();
    mode = MonitorMode.playing;
    await platform.setKeepScreenOn(true);
  });
  Future<void> selectRecording(RecordingEntry entry) =>
      _run(() => _loadRecording(entry));

  Future<void> _loadRecording(RecordingEntry entry, {WaveData? wave}) async {
    _resumeCapture = false;
    _interrupted = false;
    if (isRecording) await _finishRecording();
    await platform.stopCapture();
    await platform.stopPlayback();
    mode = MonitorMode.idle;
    _clock.stop();
    _playbackClock.stop();
    _worker.reset();
    await platform.setKeepScreenOn(false);
    analyzingRecording = true;
    _notify();
    try {
      final audio = wave ?? await recordingRepository.load(entry);
      final frames = await _recordingAnalyzer.analyze(
        audio,
        threshold: settings.threshold,
      );
      if (_disposed) return;
      _clearAnalysis();
      _clock.stop();
      selectedRecording = entry;
      _playbackWave = audio;
      _playbackOffsetMs = 0;
      _recordingFrames = frames;
      for (final frame in frames) {
        _appendFrame(frame);
      }
      _fitHistoryViewport();
    } finally {
      analyzingRecording = false;
      _notify();
    }
  }

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
      if (hasRecordingOverview) {
        _clearAnalysis();
        _clock.stop();
      }
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
    await _loadRecording(entry, wave: wave);
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

  Future<void> fitPitchRangeAndFollow() => _run(() async {
    settings = settings.withValue('autoScroll', true);
    _historyViewport.reset();
    if (settings.showSpectrum) {
      _fitSpectrumViewport();
    } else {
      _fitHistoryViewport(includeHeld: true);
    }
    if (scale != null) await settingsRepository.save(settings, scale!);
  });

  void _fitSpectrumViewport() {
    final points = _heldSpectra ?? _spectra;
    final time = math.max(
      graphTime,
      points.isEmpty ? 0.0 : points.last.seconds,
    );
    final peaks = Uint8List(LogSpectrum.bands);
    var peak = 0;
    for (final point in points) {
      if (point.seconds < time - graphSeconds || point.seconds > time) continue;
      for (var band = 0; band < peaks.length; band++) {
        peaks[band] = math.max(peaks[band], point.bands[band]);
        peak = math.max(peak, peaks[band]);
      }
    }
    // Ignore background below -60 dBFS or 40 dB below the visible peak.
    final threshold = math.max(85, peak - 255 * 40 / -LogSpectrum.floorDb);
    final low = peaks.indexWhere((value) => value >= threshold);
    if (low < 0) return;
    final high = peaks.lastIndexWhere((value) => value >= threshold);
    final fullRange = LogSpectrum.maxCents - LogSpectrum.minCents;
    final fitted = HistoryViewport().fit(
      pitches: [
        LogSpectrum.minCents + low * LogSpectrum.centsPerBand,
        LogSpectrum.minCents + (high + 1) * LogSpectrum.centsPerBand,
      ],
      time: time,
      center: centerCents,
      range: fullRange / settings.verticalZoom,
      minimumRange: fullRange / MonitorSettings.maxVerticalZoom,
    );
    final range = fitted.range.clamp(
      fullRange / MonitorSettings.maxVerticalZoom,
      fullRange,
    );
    centerCents = fitted.center.clamp(
      LogSpectrum.minCents + range / 2,
      LogSpectrum.maxCents - range / 2,
    );
    settings = settings.withValue('verticalZoom', fullRange / range);
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
    if (_disposed || !isCapturing) return;
    _updateFrameReadout(frame);
    _appendFrame(frame);
    if (_spectra.length > 2700) {
      _spectra.removeRange(0, _spectra.length - 2700);
    }
    if (_history.length > 2700) _history.removeRange(0, _history.length - 2700);
    if (!held) {
      if (settings.showSpectrum && settings.autoScroll && frame.frequency > 0) {
        final cents = frequencyToCents(frame.frequency);
        final margin = 600 / settings.verticalZoom;
        if ((cents - centerCents).abs() > margin) centerCents = cents;
      }
      _fitHistoryViewport();
    }
    _notify();
  }

  void _updateFrameReadout(PitchFrame frame) {
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
    if (!held) _updateNote();
  }

  void _appendFrame(PitchFrame frame) {
    final cents = frame.frequency > 0 && frame.frequency.isFinite
        ? frequencyToCents(frame.frequency)
        : null;
    _history.add(PitchPoint(frame.timeSeconds, cents));
    final spectrum = frame.spectrum;
    if (spectrum != null && spectrum.length == LogSpectrum.bands) {
      _spectra.add(
        SpectrumPoint(_spectrumSequence++, frame.timeSeconds, spectrum),
      );
    }
  }

  void _updatePlaybackReadout() {
    final frames = _recordingFrames;
    if (frames == null || held) return;
    var low = 0, high = frames.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (frames[middle].timeSeconds <= currentTime) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final index = low - 1;
    if (index == _playbackFrameIndex) return;
    _playbackFrameIndex = index;
    _smoothedCents.clear();
    frequency = 0;
    level = 0;
    for (var i = math.max(0, index - settings.smoothing + 1); i <= index; i++) {
      _updateFrameReadout(frames[i]);
    }
    _updateNote();
  }

  void _fitHistoryViewport({bool includeHeld = false}) {
    if ((held && !includeHeld) ||
        !settings.autoScroll ||
        settings.showSpectrum) {
      return;
    }
    final points = _heldHistory ?? _history;
    final time = math.max(
      graphTime,
      points.isEmpty ? 0.0 : points.last.seconds,
    );
    final fitted = _historyViewport.fit(
      pitches: points
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
          level = 0;
          note = null;
          unawaited(platform.setKeepScreenOn(false));
          _notify();
        }
      case 'interrupted':
        if (event['positionMs'] case final num position) {
          _interruptedPositionMs = position.toInt();
          if (mode == MonitorMode.paused) {
            _playbackOffsetMs = position.toInt();
            currentTime = (_playbackOffsetMs / 1000).clamp(0.0, duration);
            _updatePlaybackReadout();
          }
        }
        if (event['reason'] == 'background') {
          // Native audio cleanup can arrive before or after the lifecycle
          // pause. Both paths preserve the intent to resume live monitoring.
          unawaited(suspend());
          return;
        }
        _interrupted = true;
        _resumeCapture = false;
        if (isPlaying || mode == MonitorMode.paused) {
          _playbackOffsetMs =
              _interruptedPositionMs ??
              (_playbackOffsetMs + _playbackClock.elapsedMilliseconds);
          currentTime = (_playbackOffsetMs / 1000).clamp(0.0, duration);
          _updatePlaybackReadout();
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
      final milliseconds =
          _playbackOffsetMs + _playbackClock.elapsedMilliseconds;
      currentTime = (milliseconds / 1000).clamp(0.0, duration);
      _updatePlaybackReadout();
    }
    if (isCapturing || isPlaying) {
      final progress = currentTime * settings.bpm / 60;
      beat = settings.beatsPerBar == 0
          ? 0
          : progress.floor() % settings.beatsPerBar;
      beatPhase = progress % 1;
      if (!hasRecordingOverview) _fitHistoryViewport();
      _notify();
    }
  }

  Future<void> suspend() => _run(() async {
    // Duplicate pauses must not discard the capture state from the first one.
    _resumeCapture = (_resumeCapture || isCapturing) && !_interrupted;
    try {
      if (isPlaying) {
        final nativePosition = await platform.pausePlayback();
        _playbackOffsetMs = _interruptedPositionMs ?? nativePosition;
        currentTime = (_playbackOffsetMs / 1000).clamp(0.0, duration);
        _updatePlaybackReadout();
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
    _messageTimer?.cancel();
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
