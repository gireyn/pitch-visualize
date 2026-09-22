import Flutter
import AVFoundation
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PitchPlatformPlugin") {
      PitchPlatformPlugin.register(with: registrar)
    }
  }
}

/// Device I/O for the shared Dart application, registered on Flutter's actual implicit engine.
private final class PitchPlatformPlugin: NSObject, FlutterPlugin, FlutterStreamHandler,
  AVAudioPlayerDelegate, UIDocumentPickerDelegate {
  private weak var registrar: FlutterPluginRegistrar?
  private var eventSink: FlutterEventSink?
  private var audioEngine: AVAudioEngine?
  private var sampleRate = 44100
  private var player: AVAudioPlayer?
  private var playerURL: URL?
  private var lastPlaybackPositionMs = 0
  private var pendingPermission: FlutterResult?
  private var permissionGeneration = 0
  private var pickerResult: FlutterResult?
  private var pickerLimit = 0
  private var observers: [NSObjectProtocol] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PitchPlatformPlugin()
    instance.registrar = registrar
    let methods = FlutterMethodChannel(name: "pitch_visual/platform", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "pitch_visual/audio", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
    registrar.publish(instance)
    instance.observeInterruptions()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    do {
      switch call.method {
      case "startCapture": requestCapture(result)
      case "stopCapture":
        permissionGeneration += 1
        pendingPermission?(FlutterError(code: "cancelled", message: "Microphone request was cancelled.", details: nil))
        pendingPermission = nil
        stopCapture()
        result(nil)
      case "play":
        guard let path = arguments["path"] as? String else { throw deviceError("Missing playback path.") }
        try play(path: path, positionMs: arguments["positionMs"] as? Int ?? 0)
        result(nil)
      case "pausePlayback":
        player?.pause()
        if let player { lastPlaybackPositionMs = Int(player.currentTime * 1000) }
        result(lastPlaybackPositionMs)
      case "stopPlayback": stopPlayback(); result(nil)
      case "getStorageDirectory": result(try storageDirectory().path)
      case "pickFile": try pickFile(kind: arguments["kind"] as? String ?? "tuning", result: result)
      case "loadPreferences": result(UserDefaults.standard.string(forKey: "pitch_visual.settings"))
      case "savePreferences":
        guard let json = arguments["json"] as? String else { throw deviceError("Missing settings JSON.") }
        UserDefaults.standard.set(json, forKey: "pitch_visual.settings")
        result(nil)
      case "setKeepScreenOn":
        UIApplication.shared.isIdleTimerDisabled = arguments["enabled"] as? Bool ?? false
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    } catch {
      let code = call.method == "play" ? "playback" : "platformError"
      result(FlutterError(code: code, message: error.localizedDescription, details: nil))
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    permissionGeneration += 1
    pendingPermission?(FlutterError(code: "cancelled", message: "Microphone request was cancelled.", details: nil))
    pendingPermission = nil
    stopCapture()
    stopPlayback()
    return nil
  }

  private func requestCapture(_ result: @escaping FlutterResult) {
    if audioEngine != nil { result(sampleRate); return }
    guard pendingPermission == nil else {
      result(FlutterError(code: "busy", message: "A microphone permission request is already open.", details: nil))
      return
    }
    pendingPermission = result
    permissionGeneration += 1
    let generation = permissionGeneration
    let completion: (Bool) -> Void = { [weak self] granted in
      DispatchQueue.main.async {
        guard let self, self.permissionGeneration == generation, let callback = self.pendingPermission else { return }
        self.pendingPermission = nil
        guard granted else {
          callback(FlutterError(code: "permissionDenied", message: "Microphone access is required for live pitch detection. Enable it in system settings.", details: nil))
          return
        }
        guard UIApplication.shared.applicationState != .background else {
          callback(FlutterError(code: "inactive", message: "Open the application to use the microphone.", details: nil))
          return
        }
        do { callback(try self.startCapture()) }
        catch { callback(FlutterError(code: "captureFailed", message: error.localizedDescription, details: nil)) }
      }
    }
    if #available(iOS 17.0, *) { AVAudioApplication.requestRecordPermission(completionHandler: completion) }
    else { AVAudioSession.sharedInstance().requestRecordPermission(completion) }
  }

  private func startCapture() throws -> Int {
    stopPlayback()
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
    try session.setPreferredSampleRate(44100)
    try session.setPreferredIOBufferDuration(0.023)
    try session.setActive(true)
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0,
      format.commonFormat == .pcmFormatFloat32 else {
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw deviceError("No supported microphone input is available.")
    }
    let rate = Int(format.sampleRate.rounded())
    input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self, weak engine] buffer, _ in
      guard let channels = buffer.floatChannelData else { return }
      let count = Int(buffer.frameLength)
      let channelCount = Int(buffer.format.channelCount)
      var bytes = Data(count: count * MemoryLayout<Int16>.size)
      bytes.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
        let destination = raw.bindMemory(to: Int16.self)
        for index in 0..<count {
          var value: Float = 0
          for channel in 0..<channelCount {
            value += buffer.format.isInterleaved ? channels[0][index * channelCount + channel] : channels[channel][index]
          }
          value = max(-1, min(1, value / Float(channelCount)))
          destination[index] = Int16(value * 32767).littleEndian
        }
      }
      DispatchQueue.main.async { [weak self, weak engine] in
        guard let self, let engine, self.audioEngine === engine else { return }
        self.eventSink?(["type": "pcm", "data": FlutterStandardTypedData(bytes: bytes), "sampleRate": rate])
      }
    }
    do {
      engine.prepare()
      try engine.start()
      audioEngine = engine
      sampleRate = rate
      return rate
    } catch {
      input.removeTap(onBus: 0)
      engine.stop()
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw error
    }
  }

  private func stopCapture() {
    guard let engine = audioEngine else { return }
    audioEngine = nil
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    if player == nil { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
  }

  private func play(path: String, positionMs: Int) throws {
    let url = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
    let storage = try storageDirectory().resolvingSymlinksInPath()
    guard url.path.hasPrefix(storage.path + "/"), FileManager.default.fileExists(atPath: url.path) else {
      throw deviceError("Recording does not exist in application storage.")
    }
    stopCapture()
    if playerURL != url { stopPlayback() }
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default)
    try session.setActive(true)
    do {
      let current = try player ?? AVAudioPlayer(contentsOf: url)
      current.delegate = self
      current.currentTime = min(current.duration, Double(max(0, positionMs)) / 1000)
      current.prepareToPlay()
      guard current.play() else { throw deviceError("Could not start playback.") }
      player = current
      playerURL = url
    } catch {
      stopPlayback()
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw error
    }
  }

  private func stopPlayback() {
    let wasPlaying = player != nil
    player?.stop()
    player = nil
    playerURL = nil
    lastPlaybackPositionMs = 0
    if wasPlaying && audioEngine == nil { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    guard self.player === player else { return }
    stopPlayback()
    emit(flag ? "playbackComplete" : "error", message: flag ? nil : "Audio playback failed.", code: flag ? nil : "playback")
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    guard self.player === player else { return }
    stopPlayback()
    emit("error", message: error?.localizedDescription ?? "Could not decode the recording.", code: "playback")
  }

  private func storageDirectory() throws -> URL {
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("PitchVisual", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func pickFile(kind: String, result: @escaping FlutterResult) throws {
    guard kind == "audio" || kind == "tuning" else { throw deviceError("Unknown document type.") }
    guard pickerResult == nil else { throw deviceError("A document picker is already open.") }
    guard var controller = registrar?.viewController else { throw deviceError("The document picker is unavailable.") }
    while let presented = controller.presentedViewController { controller = presented }
    let types: [UTType] = kind == "audio" ? [.audio, .data] : [.plainText, .json, .data]
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    pickerLimit = kind == "audio" ? 64 * 1024 * 1024 : 1024 * 1024
    pickerResult = result
    controller.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = pickerResult
    pickerResult = nil
    result?(nil)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let callback = pickerResult, let url = urls.first else {
      documentPickerWasCancelled(controller)
      return
    }
    let limit = pickerLimit
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let accessed = url.startAccessingSecurityScopedResource()
      defer { if accessed { url.stopAccessingSecurityScopedResource() } }
      do {
        let resources = try url.resourceValues(forKeys: [.fileSizeKey])
        guard (resources.fileSize ?? 0) <= limit else { throw Self.fileError("Selected file is too large.") }
        guard let input = InputStream(url: url) else { throw Self.fileError("Could not open the selected document.") }
        input.open()
        defer { input.close() }
        var bytes = Data()
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
          let count = input.read(&buffer, maxLength: buffer.count)
          if count == 0 { break }
          if count < 0 { throw input.streamError ?? Self.fileError("Could not read the selected document.") }
          guard bytes.count + count <= limit else { throw Self.fileError("Selected file is too large.") }
          bytes.append(contentsOf: buffer.prefix(count))
        }
        DispatchQueue.main.async {
          self?.pickerResult = nil
          callback(["name": url.lastPathComponent, "bytes": FlutterStandardTypedData(bytes: bytes)])
        }
      } catch {
        DispatchQueue.main.async {
          self?.pickerResult = nil
          callback(FlutterError(code: "fileReadFailed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func observeInterruptions() {
    for name in [UIApplication.didEnterBackgroundNotification, UIScene.didEnterBackgroundNotification] {
      observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.interruptAudio(reason: "background")
      })
    }
    observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
      object: nil, queue: .main) { [weak self] _ in self?.interruptAudio() })
    observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
      object: nil, queue: .main) { [weak self] notification in
        if notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSession.InterruptionType.began.rawValue {
          self?.interruptAudio()
        }
      })
    observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification,
      object: nil, queue: .main) { [weak self] notification in
        if notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
          self?.interruptAudio()
        }
      })
  }

  private func interruptAudio(reason: String = "audio") {
    guard audioEngine != nil || player != nil else { return }
    let interrupted = audioEngine != nil || player?.isPlaying == true
    let position = player.map { Int($0.currentTime * 1000) }
    stopCapture()
    stopPlayback()
    if let position { lastPlaybackPositionMs = position }
    if interrupted { emit("interrupted", message: "Audio was interrupted. Resume when ready.", reason: reason, positionMs: position) }
  }

  private func emit(_ type: String, message: String? = nil, reason: String? = nil, positionMs: Int? = nil, code: String? = nil) {
    var event: [String: Any] = ["type": type]
    if let message { event["message"] = message }
    if let reason { event["reason"] = reason }
    if let positionMs { event["positionMs"] = positionMs }
    if let code { event["code"] = code }
    eventSink?(event)
  }

  private func deviceError(_ message: String) -> NSError { Self.fileError(message) }
  private static func fileError(_ message: String) -> NSError {
    NSError(domain: "PitchVisual", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
    audioEngine?.stop()
    player?.stop()
  }
}
