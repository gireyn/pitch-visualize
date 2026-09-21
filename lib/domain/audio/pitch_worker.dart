import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import 'pcm_resampler.dart';
import 'pitch_analyzer.dart';

class PitchFrame {
  const PitchFrame({
    required this.frequency,
    required this.level,
    required this.timeSeconds,
    this.spectrum,
  });

  /// Detected frequency in Hz, or -1 for unvoiced audio.
  final double frequency;

  /// RMS of the latest analysis interval, normalized to 0..1.
  final double level;

  /// Input audio time since the last reset, including dropped queued audio.
  ///
  /// This is independent of wall-clock delivery time and remains monotonic
  /// when backpressure drops blocks or the input sample rate changes.
  final double timeSeconds;

  /// Logarithmic C1–C9 spectrum, independent of voiced-pitch gating.
  final Uint8List? spectrum;
}

/// One long-lived DSP isolate, with one in-flight block and a bounded queue.
///
/// If the producer outruns analysis, queued old audio is dropped and the next
/// block starts a clean detector window. This keeps live monitoring responsive.
/// Call [reset] when pausing or changing sources to discard all stale results.
class PitchWorker {
  PitchWorker({double threshold = 2}) {
    this.threshold = threshold;
  }

  static const maxQueuedChunks = 8;
  static const maxQueuedBytes = 192000;
  final StreamController<_StampedFrame> _frames =
      StreamController<_StampedFrame>.broadcast();
  final Queue<_QueuedPcm> _queue = Queue<_QueuedPcm>();
  Isolate? _isolate;
  ReceivePort? _receive;
  StreamSubscription<dynamic>? _subscription;
  SendPort? _commands;
  Future<void>? _starting;
  Completer<void>? _ready;
  bool _disposed = false;
  bool _inFlight = false;
  int _generation = 0;
  int _queuedBytes = 0;
  int _droppedChunks = 0;
  double _threshold = 2;
  double _sourceTimeSeconds = 0;

  Stream<PitchFrame> get frames => _frames.stream
      .where((event) => !_disposed && event.generation == _generation)
      .map((event) => event.frame);
  int get droppedChunks => _droppedChunks;
  double get threshold => _threshold;
  set threshold(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, 'threshold', 'Must be finite and >= 0');
    }
    _threshold = value;
  }

  Future<void> start() {
    if (_disposed) return Future.error(StateError('PitchWorker is disposed'));
    return _starting ??= _start();
  }

  Future<void> _start() async {
    final ready = _ready = Completer<void>();
    final receive = _receive = ReceivePort();
    _subscription = receive.listen(_onEvent);
    try {
      final isolate = await Isolate.spawn<SendPort>(
        _pitchWorkerMain,
        receive.sendPort,
        onError: receive.sendPort,
        onExit: receive.sendPort,
        errorsAreFatal: true,
        debugName: 'pitch-analysis',
      );
      if (_disposed) {
        isolate.kill(priority: Isolate.immediate);
        return;
      }
      _isolate = isolate;
      await ready.future;
    } catch (_) {
      receive.close();
      rethrow;
    }
  }

  /// Copies a bounded chunk so native buffer reuse cannot alter queued audio.
  void addPcm(Uint8List pcm, int sampleRate) {
    if (_disposed) throw StateError('PitchWorker is disposed');
    if (_commands == null) throw StateError('Call and await start() first');
    StreamingPcmResampler.validatePcm(pcm, sampleRate);
    if (pcm.isEmpty) return;
    final sourceStartTime = _sourceTimeSeconds;
    _sourceTimeSeconds += (pcm.length ~/ 2) / sampleRate;
    var discontinuity = false;
    if (_queue.length >= maxQueuedChunks ||
        _queuedBytes + pcm.length > maxQueuedBytes) {
      _droppedChunks += _queue.length;
      _queue.clear();
      _queuedBytes = 0;
      discontinuity = true;
    }
    _queue.add(
      _QueuedPcm(
        Uint8List.fromList(pcm),
        sampleRate,
        discontinuity,
        sourceStartTime,
      ),
    );
    _queuedBytes += pcm.length;
    _dispatch();
  }

  void reset() {
    _generation++;
    _queue.clear();
    _queuedBytes = 0;
    _sourceTimeSeconds = 0;
  }

  void _dispatch() {
    if (_disposed || _inFlight || _queue.isEmpty || _commands == null) return;
    final pcm = _queue.removeFirst();
    _queuedBytes -= pcm.bytes.length;
    _inFlight = true;
    _commands!.send(
      _PcmRequest(
        _generation,
        TransferableTypedData.fromList([pcm.bytes]),
        pcm.sampleRate,
        _threshold,
        pcm.discontinuity,
        pcm.sourceStartTime,
      ),
    );
  }

  void _onEvent(dynamic event) {
    if (_disposed) return;
    switch (event) {
      case SendPort():
        _commands = event;
        if (!(_ready?.isCompleted ?? true)) _ready!.complete();
      case _PcmResult():
        _inFlight = false;
        if (event.generation == _generation) {
          for (final frame in event.frames) {
            _frames.add(_StampedFrame(event.generation, frame));
          }
        }
        _dispatch();
      case _PcmFailure():
        _inFlight = false;
        if (event.generation == _generation) {
          _frames.addError(StateError(event.message));
        }
        _dispatch();
      case List<dynamic>():
        _fail(StateError('Pitch analysis isolate failed: ${event.first}'));
      case null:
        _fail(StateError('Pitch analysis isolate exited unexpectedly'));
    }
  }

  void _fail(Object error) {
    _commands = null;
    _queue.clear();
    _queuedBytes = 0;
    _inFlight = false;
    if (!(_ready?.isCompleted ?? true)) {
      _ready!.completeError(error);
    } else {
      _frames.addError(error);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _queue.clear();
    _queuedBytes = 0;
    _isolate?.kill(priority: Isolate.immediate);
    _receive?.close();
    if (!(_ready?.isCompleted ?? true)) _ready!.complete();
    await _subscription?.cancel();
    await _frames.close();
  }
}

class _QueuedPcm {
  const _QueuedPcm(
    this.bytes,
    this.sampleRate,
    this.discontinuity,
    this.sourceStartTime,
  );
  final Uint8List bytes;
  final int sampleRate;
  final bool discontinuity;
  final double sourceStartTime;
}

class _StampedFrame {
  const _StampedFrame(this.generation, this.frame);
  final int generation;
  final PitchFrame frame;
}

class _PcmRequest {
  const _PcmRequest(
    this.generation,
    this.data,
    this.sampleRate,
    this.threshold,
    this.discontinuity,
    this.sourceStartTime,
  );
  final int generation;
  final TransferableTypedData data;
  final int sampleRate;
  final double threshold;
  final bool discontinuity;
  final double sourceStartTime;
}

class _PcmResult {
  const _PcmResult(this.generation, this.frames);
  final int generation;
  final List<PitchFrame> frames;
}

class _PcmFailure {
  const _PcmFailure(this.generation, this.message);
  final int generation;
  final String message;
}

void _pitchWorkerMain(SendPort events) {
  final commands = ReceivePort();
  final analyzer = PitchAnalyzer();
  StreamingPcmResampler? resampler;
  var generation = -1;
  var samplesAnalyzed = 0;
  var segmentStartTime = 0.0;
  events.send(commands.sendPort);
  commands.listen((dynamic event) {
    if (event is! _PcmRequest) return;
    try {
      if (generation != event.generation ||
          event.discontinuity ||
          resampler?.inputSampleRate != event.sampleRate) {
        analyzer.reset();
        resampler = StreamingPcmResampler(event.sampleRate);
        samplesAnalyzed = 0;
        segmentStartTime = event.sourceStartTime;
        generation = event.generation;
      }
      analyzer.threshold = event.threshold;
      final samples = resampler!.addPcm(event.data.materialize().asUint8List());
      final frames = <PitchFrame>[];
      for (final sample in samples) {
        samplesAnalyzed++;
        if (analyzer.addSample(sample)) {
          frames.add(
            PitchFrame(
              frequency: analyzer.peakFrequency,
              level: analyzer.level,
              spectrum: analyzer.spectrum,
              timeSeconds:
                  segmentStartTime + samplesAnalyzed / PitchAnalyzer.sampleRate,
            ),
          );
        }
      }
      events.send(_PcmResult(event.generation, frames));
    } catch (error) {
      analyzer.reset();
      resampler = null;
      events.send(_PcmFailure(event.generation, error.toString()));
    }
  });
}
