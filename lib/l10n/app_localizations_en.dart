// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get recordingLibrary => 'Recordings';

  @override
  String get moreOptions => 'More options';

  @override
  String get showPitchHistory => 'Switch to pitch history';

  @override
  String get showFftSpectrum => 'Switch to FFT spectrum';

  @override
  String get settings => 'Settings';

  @override
  String get freezeResumeGraph => 'Freeze / resume graph';

  @override
  String get preparingMonitor => 'Preparing pitch monitor…';

  @override
  String get retry => 'Retry';

  @override
  String get resumeGraph => 'Resume graph';

  @override
  String get freezeGraph => 'Freeze graph';

  @override
  String get retrySaveRecording => 'Retry saving recording';

  @override
  String get startListening => 'Start listening';

  @override
  String get record => 'Record';

  @override
  String saveRecordingSemantics(String time) {
    return 'Save recording, $time recorded';
  }

  @override
  String get stop => 'Stop';

  @override
  String get pausePlayback => 'Pause playback';

  @override
  String get playRecording => 'Play recording';

  @override
  String get dismissMessage => 'Dismiss message';

  @override
  String get importWav => 'Import WAV';

  @override
  String get noRecordings =>
      'No recordings yet\nRecord on the monitor screen or import a PCM 16-bit WAV file';

  @override
  String get deleteRecording => 'Delete recording';

  @override
  String get deleteRecordingConfirmation => 'Delete recording?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get customScale => 'Custom tuning';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTuning => 'Tuning';

  @override
  String get settingsChooseTuning => 'Choose tuning';

  @override
  String get settingsNoScaleSelected => 'None selected';

  @override
  String get settingsPitchDetection => 'Pitch detection';

  @override
  String get settingsVolumeThreshold => 'Volume threshold';

  @override
  String get settingsVolumeThresholdHint =>
      'Filter quiet background noise; lower thresholds detect softer sounds';

  @override
  String get settingsEdoScale => 'EDO scale';

  @override
  String get settingsOctavesOnly => 'Octaves only';

  @override
  String get settingsEdoActiveHint =>
      'EDO scale is active; 0 shows octave marks only';

  @override
  String get settingsEdoInactiveHint =>
      'The tuning configuration is currently active. Select “Use EDO scale” to apply this setting; 0 shows octaves only';

  @override
  String get settingsUseEdoScale => 'Use EDO scale';

  @override
  String get settingsUseOctavesOnlyDescription =>
      'Octave marks only · Clear the current tuning configuration';

  @override
  String get settingsTunerSmoothing => 'Tuner smoothing';

  @override
  String get settingsCharts => 'Charts';

  @override
  String get settingsFftSpectrum => 'FFT spectrum';

  @override
  String get settingsFftSpectrumHint =>
      'Logarithmic frequency axis with tuning note names; turn off to show pitch history';

  @override
  String get settingsHorizontalZoom => 'Horizontal zoom';

  @override
  String get settingsVerticalZoom => 'Vertical zoom';

  @override
  String get settingsVerticalZoomHint =>
      'You can also pinch or spread two fingers vertically on the chart';

  @override
  String get settingsScrollSpeed => 'Scroll speed';

  @override
  String get settingsAutoFollow => 'Follow pitch range automatically';

  @override
  String get settingsAutoFollowHint =>
      'Dragging or pinching pauses following; resume it with one tap on the chart';

  @override
  String get settingsShowTuner => 'Show tuner scale';

  @override
  String get settingsShowTunerHint =>
      'Show note marks and the current pitch indicator; off by default';

  @override
  String get settingsBeat => 'Beat';

  @override
  String get settingsTempo => 'Tempo BPM';

  @override
  String get settingsTimeSignature => 'Time signature';

  @override
  String get settingsNoTimeSignature => 'None';

  @override
  String get settingsShowBeatLines => 'Show beat lines';

  @override
  String get settingsVisualMetronome => 'Visual metronome';

  @override
  String get settingsVisualMetronomeHint =>
      'Flash on each beat without playing a sound';

  @override
  String get settingsColors => 'Colors';

  @override
  String get settingsPitchCurve => 'Pitch curve';

  @override
  String get settingsBeatLines => 'Beat lines';

  @override
  String get settingsScaleColorsHint =>
      'When using a tuning file, scale grid and note colors are determined by its grayscale values.';

  @override
  String get settingsQuickActions => 'Quick actions';

  @override
  String get settingsShowFreeze => 'Show freeze button';

  @override
  String get settingsAbout => 'About PitchVisual';

  @override
  String get settingsOfflineMonitor => 'Offline pitch monitoring · Flutter';

  @override
  String get settingsAboutDescription =>
      'iOS and Android use the same tuning and pitch algorithms.\nRecordings stay on this device and can be up to 5 minutes long.\nSupported input: voice or a monophonic instrument.';

  @override
  String get settingsOpenSourceLicenses => 'Open source licenses';

  @override
  String get settingsDefaultTuningDescription =>
      'Default · Seven equal divisions of the octave';

  @override
  String get settingsImportTuning => 'Import tuning file';

  @override
  String get settingsTuningFileFormat =>
      'xen-tuner text configuration (.txt / .json)';

  @override
  String get settingsTuningImportHint =>
      'Tuning files are copied and saved on this device. Import again after changing the original file.';

  @override
  String get graphPitchRangeHint =>
      'Spread two fingers vertically to zoom in, pinch to zoom out, or drag up and down to adjust the pitch range. Manual adjustments pause automatic following.';

  @override
  String get graphNoPitch => 'no pitch';

  @override
  String get graphFrozen => 'Frozen';

  @override
  String get graphResumeAutoFollow => 'Resume following pitch range';

  @override
  String get graphRangeUp => 'Move pitch range up';

  @override
  String get graphRangeDown => 'Move pitch range down';

  @override
  String get graphSpectrumAxis => 'FFT · Pitch / log₂';

  @override
  String get graphSpectrumIntensity => 'Spectrum intensity: −90 to 0 dBFS';

  @override
  String get graphSpectrumEmpty =>
      'Start listening to see fundamentals and overtones\nEqual height per octave · Brightness shows intensity';

  @override
  String settingsEdoDivisions(int count) {
    return '$count divisions';
  }

  @override
  String settingsUseEdoDescription(int count) {
    return '$count equal divisions of the octave · Clear the current tuning configuration';
  }

  @override
  String settingsCurrentTuning(String name, int count, String period) {
    return 'Current: $name\n$count notes · Period $period cents';
  }

  @override
  String graphCurrentTuning(String name) {
    return 'Current tuning: $name';
  }

  @override
  String graphTempo(int bpm) {
    return 'Tempo: $bpm beats per minute';
  }

  @override
  String graphPitchHistoryDescription(String note) {
    return 'Pitch history chart. Current: $note. The vertical axis shows tuning note names; the horizontal axis shows time.';
  }

  @override
  String graphDeviation(String cents) {
    return 'Deviation: $cents cents';
  }

  @override
  String graphSpectrumDescription(String name) {
    return 'Scrolling FFT spectrum. The vertical axis shows logarithmic frequency labeled with $name note names, with equal height per octave. The horizontal axis shows time. Colors from dark blue through orange-yellow to white represent −90 to 0 dBFS.';
  }

  @override
  String get noticeTuningRestored => 'Tuning restored from cache';

  @override
  String get noticeSettingsRestored =>
      'Some local settings could not be read. The default tuning has been restored.';

  @override
  String noticeRecordingSaved(String name) {
    return 'Recording saved: $name';
  }

  @override
  String noticeRecordingImported(String name) {
    return 'Imported $name';
  }

  @override
  String noticeScaleApplied(String name) {
    return 'Applied $name';
  }

  @override
  String get noticeAudioDeviceChanged =>
      'The audio device changed. Recording has stopped.';

  @override
  String get noticePlaybackInterrupted =>
      'Playback was interrupted by the system. Tap Play to resume.';

  @override
  String get noticeAudioInterrupted =>
      'Audio was interrupted by the system. Tap Start to continue.';

  @override
  String get errorWavInvalidFile =>
      'The WAV file is empty, damaged, or larger than 64 MB.';

  @override
  String get errorWavPcmRequired =>
      'Select an uncompressed 16-bit PCM WAV file.';

  @override
  String get errorWavIncomplete => 'The WAV file is incomplete.';

  @override
  String get errorWavInvalidLength => 'The WAV data length is invalid.';

  @override
  String get errorWavUnsupportedFormat =>
      'Only 16-bit PCM WAV is supported. Compressed and floating-point audio are not supported.';

  @override
  String get errorWavIncompleteChunk => 'A WAV data chunk is incomplete.';

  @override
  String get errorWavInvalidAudio =>
      'The WAV sample rate, channels, or audio data is invalid.';

  @override
  String get errorRecordingTooLong =>
      'Recordings can be at most 5 minutes long.';

  @override
  String get errorWavTooLarge => 'The WAV file exceeds 64 MB.';

  @override
  String get errorTuningTooLarge => 'The tuning file cannot exceed 1 MB.';

  @override
  String get errorInvalidRecordingPath => 'The recording path is invalid.';

  @override
  String get errorMicrophonePermission =>
      'Microphone access is required for live pitch detection. Enable it in system settings.';

  @override
  String get errorRequestBusy =>
      'Another permission request or file picker is already open.';

  @override
  String get errorAppInactive => 'Open the app to use the microphone.';

  @override
  String get errorRequestCancelled => 'The request was cancelled.';

  @override
  String get errorCaptureFailed =>
      'Microphone capture failed. Check the audio device and try again.';

  @override
  String get errorPlaybackFailed =>
      'Audio playback failed. Try selecting the recording again.';

  @override
  String get errorRecordingDecode => 'The recording could not be decoded.';

  @override
  String get errorFileReadFailed => 'The selected file could not be read.';

  @override
  String errorDeviceDetails(String details) {
    return 'Device operation failed: $details';
  }

  @override
  String errorInvalidFormat(String details) {
    return 'Invalid file format: $details';
  }

  @override
  String errorFileOperation(String details) {
    return 'File operation failed: $details';
  }

  @override
  String errorUnexpected(String details) {
    return 'Operation failed: $details';
  }

  @override
  String get octaveScale => 'Octave guides';

  @override
  String get errorAudioDevice => 'The audio device encountered an error.';

  @override
  String get tianganScale => 'Tiangan scale';

  @override
  String get errorTuningMissingLines =>
      'The tuning needs a reference note line and a pitch line.';

  @override
  String get errorTuningInvalidReference =>
      'The reference note must use the format \"C4: 261.63\".';

  @override
  String errorTuningInvalidFrequency(String detail) {
    return 'Invalid reference frequency: $detail';
  }

  @override
  String get errorTuningMissingPitch =>
      'The tuning needs at least one scale pitch and an equave.';

  @override
  String get errorTuningTooManyNotes =>
      'A tuning can contain at most 4096 notes.';

  @override
  String errorTuningInvalidPitch(String detail) {
    return 'Cannot parse pitch: $detail';
  }

  @override
  String get errorTuningZeroEquave => 'The equave size must be non-zero.';

  @override
  String errorTuningReferenceNotFound(String detail) {
    return 'Reference note \"$detail\" is not in the scale.';
  }
}
