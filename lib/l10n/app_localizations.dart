import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @recordingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get recordingLibrary;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @showPitchHistory.
  ///
  /// In en, this message translates to:
  /// **'Switch to pitch history'**
  String get showPitchHistory;

  /// No description provided for @showFftSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Switch to FFT spectrum'**
  String get showFftSpectrum;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @freezeResumeGraph.
  ///
  /// In en, this message translates to:
  /// **'Freeze / resume graph'**
  String get freezeResumeGraph;

  /// No description provided for @preparingMonitor.
  ///
  /// In en, this message translates to:
  /// **'Preparing pitch monitor…'**
  String get preparingMonitor;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @resumeGraph.
  ///
  /// In en, this message translates to:
  /// **'Resume graph'**
  String get resumeGraph;

  /// No description provided for @freezeGraph.
  ///
  /// In en, this message translates to:
  /// **'Freeze graph'**
  String get freezeGraph;

  /// No description provided for @retrySaveRecording.
  ///
  /// In en, this message translates to:
  /// **'Retry saving recording'**
  String get retrySaveRecording;

  /// No description provided for @startListening.
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get startListening;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @saveRecordingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Save recording, {time} recorded'**
  String saveRecordingSemantics(String time);

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @pausePlayback.
  ///
  /// In en, this message translates to:
  /// **'Pause playback'**
  String get pausePlayback;

  /// No description provided for @playRecording.
  ///
  /// In en, this message translates to:
  /// **'Play recording'**
  String get playRecording;

  /// No description provided for @dismissMessage.
  ///
  /// In en, this message translates to:
  /// **'Dismiss message'**
  String get dismissMessage;

  /// No description provided for @importWav.
  ///
  /// In en, this message translates to:
  /// **'Import WAV'**
  String get importWav;

  /// No description provided for @noRecordings.
  ///
  /// In en, this message translates to:
  /// **'No recordings yet\nRecord on the monitor screen or import a PCM 16-bit WAV file'**
  String get noRecordings;

  /// No description provided for @deleteRecording.
  ///
  /// In en, this message translates to:
  /// **'Delete recording'**
  String get deleteRecording;

  /// No description provided for @deleteRecordingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete recording?'**
  String get deleteRecordingConfirmation;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @customScale.
  ///
  /// In en, this message translates to:
  /// **'Custom tuning'**
  String get customScale;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTuning.
  ///
  /// In en, this message translates to:
  /// **'Tuning'**
  String get settingsTuning;

  /// No description provided for @settingsChooseTuning.
  ///
  /// In en, this message translates to:
  /// **'Choose tuning'**
  String get settingsChooseTuning;

  /// No description provided for @settingsNoScaleSelected.
  ///
  /// In en, this message translates to:
  /// **'None selected'**
  String get settingsNoScaleSelected;

  /// No description provided for @settingsPitchDetection.
  ///
  /// In en, this message translates to:
  /// **'Pitch detection'**
  String get settingsPitchDetection;

  /// No description provided for @settingsVolumeThreshold.
  ///
  /// In en, this message translates to:
  /// **'Volume threshold'**
  String get settingsVolumeThreshold;

  /// No description provided for @settingsVolumeThresholdHint.
  ///
  /// In en, this message translates to:
  /// **'Filter quiet background noise; lower thresholds detect softer sounds'**
  String get settingsVolumeThresholdHint;

  /// No description provided for @settingsEdoScale.
  ///
  /// In en, this message translates to:
  /// **'EDO scale'**
  String get settingsEdoScale;

  /// No description provided for @settingsOctavesOnly.
  ///
  /// In en, this message translates to:
  /// **'Octaves only'**
  String get settingsOctavesOnly;

  /// No description provided for @settingsEdoActiveHint.
  ///
  /// In en, this message translates to:
  /// **'EDO scale is active; 0 shows octave marks only'**
  String get settingsEdoActiveHint;

  /// No description provided for @settingsEdoInactiveHint.
  ///
  /// In en, this message translates to:
  /// **'The tuning configuration is currently active. Select “Use EDO scale” to apply this setting; 0 shows octaves only'**
  String get settingsEdoInactiveHint;

  /// No description provided for @settingsUseEdoScale.
  ///
  /// In en, this message translates to:
  /// **'Use EDO scale'**
  String get settingsUseEdoScale;

  /// No description provided for @settingsUseOctavesOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Octave marks only · Clear the current tuning configuration'**
  String get settingsUseOctavesOnlyDescription;

  /// No description provided for @settingsTunerSmoothing.
  ///
  /// In en, this message translates to:
  /// **'Tuner smoothing'**
  String get settingsTunerSmoothing;

  /// No description provided for @settingsCharts.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get settingsCharts;

  /// No description provided for @settingsFftSpectrum.
  ///
  /// In en, this message translates to:
  /// **'FFT spectrum'**
  String get settingsFftSpectrum;

  /// No description provided for @settingsFftSpectrumHint.
  ///
  /// In en, this message translates to:
  /// **'Logarithmic frequency axis with tuning note names; turn off to show pitch history'**
  String get settingsFftSpectrumHint;

  /// No description provided for @settingsHorizontalZoom.
  ///
  /// In en, this message translates to:
  /// **'Horizontal zoom'**
  String get settingsHorizontalZoom;

  /// No description provided for @settingsVerticalZoom.
  ///
  /// In en, this message translates to:
  /// **'Vertical zoom'**
  String get settingsVerticalZoom;

  /// No description provided for @settingsVerticalZoomHint.
  ///
  /// In en, this message translates to:
  /// **'You can also pinch or spread two fingers vertically on the chart'**
  String get settingsVerticalZoomHint;

  /// No description provided for @settingsScrollSpeed.
  ///
  /// In en, this message translates to:
  /// **'Scroll speed'**
  String get settingsScrollSpeed;

  /// No description provided for @settingsAutoFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow pitch range automatically'**
  String get settingsAutoFollow;

  /// No description provided for @settingsAutoFollowHint.
  ///
  /// In en, this message translates to:
  /// **'Dragging or pinching pauses following; resume it with one tap on the chart'**
  String get settingsAutoFollowHint;

  /// No description provided for @settingsShowTuner.
  ///
  /// In en, this message translates to:
  /// **'Show tuner scale'**
  String get settingsShowTuner;

  /// No description provided for @settingsShowTunerHint.
  ///
  /// In en, this message translates to:
  /// **'Show note marks and the current pitch indicator; off by default'**
  String get settingsShowTunerHint;

  /// No description provided for @settingsBeat.
  ///
  /// In en, this message translates to:
  /// **'Beat'**
  String get settingsBeat;

  /// No description provided for @settingsTempo.
  ///
  /// In en, this message translates to:
  /// **'Tempo BPM'**
  String get settingsTempo;

  /// No description provided for @settingsTimeSignature.
  ///
  /// In en, this message translates to:
  /// **'Time signature'**
  String get settingsTimeSignature;

  /// No description provided for @settingsNoTimeSignature.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsNoTimeSignature;

  /// No description provided for @settingsShowBeatLines.
  ///
  /// In en, this message translates to:
  /// **'Show beat lines'**
  String get settingsShowBeatLines;

  /// No description provided for @settingsVisualMetronome.
  ///
  /// In en, this message translates to:
  /// **'Visual metronome'**
  String get settingsVisualMetronome;

  /// No description provided for @settingsVisualMetronomeHint.
  ///
  /// In en, this message translates to:
  /// **'Flash on each beat without playing a sound'**
  String get settingsVisualMetronomeHint;

  /// No description provided for @settingsColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get settingsColors;

  /// No description provided for @settingsPitchCurve.
  ///
  /// In en, this message translates to:
  /// **'Pitch curve'**
  String get settingsPitchCurve;

  /// No description provided for @settingsBeatLines.
  ///
  /// In en, this message translates to:
  /// **'Beat lines'**
  String get settingsBeatLines;

  /// No description provided for @settingsScaleColorsHint.
  ///
  /// In en, this message translates to:
  /// **'When using a tuning file, scale grid and note colors are determined by its grayscale values.'**
  String get settingsScaleColorsHint;

  /// No description provided for @settingsQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get settingsQuickActions;

  /// No description provided for @settingsShowFreeze.
  ///
  /// In en, this message translates to:
  /// **'Show freeze button'**
  String get settingsShowFreeze;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About PitchVisual'**
  String get settingsAbout;

  /// No description provided for @settingsOfflineMonitor.
  ///
  /// In en, this message translates to:
  /// **'Offline pitch monitoring · Flutter'**
  String get settingsOfflineMonitor;

  /// No description provided for @settingsAboutDescription.
  ///
  /// In en, this message translates to:
  /// **'iOS and Android use the same tuning and pitch algorithms.\nRecordings stay on this device and can be up to 5 minutes long.\nSupported input: voice or a monophonic instrument.'**
  String get settingsAboutDescription;

  /// No description provided for @settingsOpenSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get settingsOpenSourceLicenses;

  /// No description provided for @settingsDefaultTuningDescription.
  ///
  /// In en, this message translates to:
  /// **'Default · Seven equal divisions of the octave'**
  String get settingsDefaultTuningDescription;

  /// No description provided for @settingsImportTuning.
  ///
  /// In en, this message translates to:
  /// **'Import tuning file'**
  String get settingsImportTuning;

  /// No description provided for @settingsTuningFileFormat.
  ///
  /// In en, this message translates to:
  /// **'xen-tuner text configuration (.txt / .json)'**
  String get settingsTuningFileFormat;

  /// No description provided for @settingsTuningImportHint.
  ///
  /// In en, this message translates to:
  /// **'Tuning files are copied and saved on this device. Import again after changing the original file.'**
  String get settingsTuningImportHint;

  /// No description provided for @graphPitchRangeHint.
  ///
  /// In en, this message translates to:
  /// **'Spread two fingers vertically to zoom in, pinch to zoom out, or drag up and down to adjust the pitch range. Manual adjustments pause automatic following.'**
  String get graphPitchRangeHint;

  /// No description provided for @graphNoPitch.
  ///
  /// In en, this message translates to:
  /// **'no pitch'**
  String get graphNoPitch;

  /// No description provided for @graphFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get graphFrozen;

  /// No description provided for @graphResumeAutoFollow.
  ///
  /// In en, this message translates to:
  /// **'Resume following pitch range'**
  String get graphResumeAutoFollow;

  /// No description provided for @graphRangeUp.
  ///
  /// In en, this message translates to:
  /// **'Move pitch range up'**
  String get graphRangeUp;

  /// No description provided for @graphRangeDown.
  ///
  /// In en, this message translates to:
  /// **'Move pitch range down'**
  String get graphRangeDown;

  /// No description provided for @graphSpectrumAxis.
  ///
  /// In en, this message translates to:
  /// **'FFT · Pitch / log₂'**
  String get graphSpectrumAxis;

  /// No description provided for @graphSpectrumIntensity.
  ///
  /// In en, this message translates to:
  /// **'Spectrum intensity: −90 to 0 dBFS'**
  String get graphSpectrumIntensity;

  /// No description provided for @graphSpectrumEmpty.
  ///
  /// In en, this message translates to:
  /// **'Start listening to see fundamentals and overtones\nEqual height per octave · Brightness shows intensity'**
  String get graphSpectrumEmpty;

  /// No description provided for @settingsEdoDivisions.
  ///
  /// In en, this message translates to:
  /// **'{count} divisions'**
  String settingsEdoDivisions(int count);

  /// No description provided for @settingsUseEdoDescription.
  ///
  /// In en, this message translates to:
  /// **'{count} equal divisions of the octave · Clear the current tuning configuration'**
  String settingsUseEdoDescription(int count);

  /// No description provided for @settingsCurrentTuning.
  ///
  /// In en, this message translates to:
  /// **'Current: {name}\n{count} notes · Period {period} cents'**
  String settingsCurrentTuning(String name, int count, String period);

  /// No description provided for @graphCurrentTuning.
  ///
  /// In en, this message translates to:
  /// **'Current tuning: {name}'**
  String graphCurrentTuning(String name);

  /// No description provided for @graphTempo.
  ///
  /// In en, this message translates to:
  /// **'Tempo: {bpm} beats per minute'**
  String graphTempo(int bpm);

  /// No description provided for @graphPitchHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Pitch history chart. Current: {note}. The vertical axis shows tuning note names; the horizontal axis shows time.'**
  String graphPitchHistoryDescription(String note);

  /// No description provided for @graphDeviation.
  ///
  /// In en, this message translates to:
  /// **'Deviation: {cents} cents'**
  String graphDeviation(String cents);

  /// No description provided for @graphSpectrumDescription.
  ///
  /// In en, this message translates to:
  /// **'Scrolling FFT spectrum. The vertical axis shows logarithmic frequency labeled with {name} note names, with equal height per octave. The horizontal axis shows time. Colors from dark blue through orange-yellow to white represent −90 to 0 dBFS.'**
  String graphSpectrumDescription(String name);

  /// No description provided for @noticeTuningRestored.
  ///
  /// In en, this message translates to:
  /// **'Tuning restored from cache'**
  String get noticeTuningRestored;

  /// No description provided for @noticeSettingsRestored.
  ///
  /// In en, this message translates to:
  /// **'Some local settings could not be read. The default tuning has been restored.'**
  String get noticeSettingsRestored;

  /// No description provided for @noticeRecordingSaved.
  ///
  /// In en, this message translates to:
  /// **'Recording saved: {name}'**
  String noticeRecordingSaved(String name);

  /// No description provided for @noticeRecordingImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {name}'**
  String noticeRecordingImported(String name);

  /// No description provided for @noticeScaleApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied {name}'**
  String noticeScaleApplied(String name);

  /// No description provided for @noticeAudioDeviceChanged.
  ///
  /// In en, this message translates to:
  /// **'The audio device changed. Recording has stopped.'**
  String get noticeAudioDeviceChanged;

  /// No description provided for @noticePlaybackInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Playback was interrupted by the system. Tap Play to resume.'**
  String get noticePlaybackInterrupted;

  /// No description provided for @noticeAudioInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Audio was interrupted by the system. Tap Start to continue.'**
  String get noticeAudioInterrupted;

  /// No description provided for @errorWavInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'The WAV file is empty, damaged, or larger than 64 MB.'**
  String get errorWavInvalidFile;

  /// No description provided for @errorWavPcmRequired.
  ///
  /// In en, this message translates to:
  /// **'Select an uncompressed 16-bit PCM WAV file.'**
  String get errorWavPcmRequired;

  /// No description provided for @errorWavIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The WAV file is incomplete.'**
  String get errorWavIncomplete;

  /// No description provided for @errorWavInvalidLength.
  ///
  /// In en, this message translates to:
  /// **'The WAV data length is invalid.'**
  String get errorWavInvalidLength;

  /// No description provided for @errorWavUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'Only 16-bit PCM WAV is supported. Compressed and floating-point audio are not supported.'**
  String get errorWavUnsupportedFormat;

  /// No description provided for @errorWavIncompleteChunk.
  ///
  /// In en, this message translates to:
  /// **'A WAV data chunk is incomplete.'**
  String get errorWavIncompleteChunk;

  /// No description provided for @errorWavInvalidAudio.
  ///
  /// In en, this message translates to:
  /// **'The WAV sample rate, channels, or audio data is invalid.'**
  String get errorWavInvalidAudio;

  /// No description provided for @errorRecordingTooLong.
  ///
  /// In en, this message translates to:
  /// **'Recordings can be at most 5 minutes long.'**
  String get errorRecordingTooLong;

  /// No description provided for @errorWavTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The WAV file exceeds 64 MB.'**
  String get errorWavTooLarge;

  /// No description provided for @errorTuningTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The tuning file cannot exceed 1 MB.'**
  String get errorTuningTooLarge;

  /// No description provided for @errorInvalidRecordingPath.
  ///
  /// In en, this message translates to:
  /// **'The recording path is invalid.'**
  String get errorInvalidRecordingPath;

  /// No description provided for @errorMicrophonePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is required for live pitch detection. Enable it in system settings.'**
  String get errorMicrophonePermission;

  /// No description provided for @errorRequestBusy.
  ///
  /// In en, this message translates to:
  /// **'Another permission request or file picker is already open.'**
  String get errorRequestBusy;

  /// No description provided for @errorAppInactive.
  ///
  /// In en, this message translates to:
  /// **'Open the app to use the microphone.'**
  String get errorAppInactive;

  /// No description provided for @errorRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get errorRequestCancelled;

  /// No description provided for @errorCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'Microphone capture failed. Check the audio device and try again.'**
  String get errorCaptureFailed;

  /// No description provided for @errorPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Audio playback failed. Try selecting the recording again.'**
  String get errorPlaybackFailed;

  /// No description provided for @errorRecordingDecode.
  ///
  /// In en, this message translates to:
  /// **'The recording could not be decoded.'**
  String get errorRecordingDecode;

  /// No description provided for @errorFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The selected file could not be read.'**
  String get errorFileReadFailed;

  /// No description provided for @errorDeviceDetails.
  ///
  /// In en, this message translates to:
  /// **'Device operation failed: {details}'**
  String errorDeviceDetails(String details);

  /// No description provided for @errorInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid file format: {details}'**
  String errorInvalidFormat(String details);

  /// No description provided for @errorFileOperation.
  ///
  /// In en, this message translates to:
  /// **'File operation failed: {details}'**
  String errorFileOperation(String details);

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {details}'**
  String errorUnexpected(String details);

  /// No description provided for @octaveScale.
  ///
  /// In en, this message translates to:
  /// **'Octave guides'**
  String get octaveScale;

  /// No description provided for @errorAudioDevice.
  ///
  /// In en, this message translates to:
  /// **'The audio device encountered an error.'**
  String get errorAudioDevice;

  /// No description provided for @tianganScale.
  ///
  /// In en, this message translates to:
  /// **'Tiangan scale'**
  String get tianganScale;

  /// No description provided for @errorTuningMissingLines.
  ///
  /// In en, this message translates to:
  /// **'The tuning needs a reference note line and a pitch line.'**
  String get errorTuningMissingLines;

  /// No description provided for @errorTuningInvalidReference.
  ///
  /// In en, this message translates to:
  /// **'The reference note must use the format \"C4: 261.63\".'**
  String get errorTuningInvalidReference;

  /// No description provided for @errorTuningInvalidFrequency.
  ///
  /// In en, this message translates to:
  /// **'Invalid reference frequency: {detail}'**
  String errorTuningInvalidFrequency(String detail);

  /// No description provided for @errorTuningMissingPitch.
  ///
  /// In en, this message translates to:
  /// **'The tuning needs at least one scale pitch and an equave.'**
  String get errorTuningMissingPitch;

  /// No description provided for @errorTuningTooManyNotes.
  ///
  /// In en, this message translates to:
  /// **'A tuning can contain at most 4096 notes.'**
  String get errorTuningTooManyNotes;

  /// No description provided for @errorTuningInvalidPitch.
  ///
  /// In en, this message translates to:
  /// **'Cannot parse pitch: {detail}'**
  String errorTuningInvalidPitch(String detail);

  /// No description provided for @errorTuningZeroEquave.
  ///
  /// In en, this message translates to:
  /// **'The equave size must be non-zero.'**
  String get errorTuningZeroEquave;

  /// No description provided for @errorTuningReferenceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Reference note \"{detail}\" is not in the scale.'**
  String errorTuningReferenceNotFound(String detail);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
