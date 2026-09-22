import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/models/app_exception.dart';
import 'l10n.dart';

/// Stores a message independently of locale, including messages already visible
/// when the operating system language changes.
class AppMessage {
  AppMessage(this._resolve);

  final String Function(AppLocalizations) _resolve;

  String resolve(AppLocalizations strings) => _resolve(strings);

  factory AppMessage.error(Object error) => AppMessage((strings) {
    if (error is AppFormatException) {
      return switch (error.code) {
        AppFormatError.wavInvalidFile => strings.errorWavInvalidFile,
        AppFormatError.wavPcmRequired => strings.errorWavPcmRequired,
        AppFormatError.wavIncomplete => strings.errorWavIncomplete,
        AppFormatError.wavInvalidLength => strings.errorWavInvalidLength,
        AppFormatError.wavUnsupportedFormat =>
          strings.errorWavUnsupportedFormat,
        AppFormatError.wavIncompleteChunk => strings.errorWavIncompleteChunk,
        AppFormatError.wavInvalidAudio => strings.errorWavInvalidAudio,
        AppFormatError.recordingTooLong => strings.errorRecordingTooLong,
        AppFormatError.wavTooLarge => strings.errorWavTooLarge,
        AppFormatError.tuningTooLarge => strings.errorTuningTooLarge,
        AppFormatError.tuningMissingLines => strings.errorTuningMissingLines,
        AppFormatError.tuningInvalidReference =>
          strings.errorTuningInvalidReference,
        AppFormatError.tuningInvalidFrequency =>
          strings.errorTuningInvalidFrequency(error.detail),
        AppFormatError.tuningMissingPitch => strings.errorTuningMissingPitch,
        AppFormatError.tuningTooManyNotes => strings.errorTuningTooManyNotes,
        AppFormatError.tuningInvalidPitch => strings.errorTuningInvalidPitch(
          error.detail,
        ),
        AppFormatError.tuningZeroEquave => strings.errorTuningZeroEquave,
        AppFormatError.tuningReferenceNotFound =>
          strings.errorTuningReferenceNotFound(error.detail),
      };
    }
    if (error is InvalidRecordingPathException) {
      return strings.errorInvalidRecordingPath;
    }
    if (error is PlatformException) {
      return switch (error.code) {
        'permissionDenied' ||
        'permission_denied' => strings.errorMicrophonePermission,
        'busy' => strings.errorRequestBusy,
        'inactive' => strings.errorAppInactive,
        'cancelled' => strings.errorRequestCancelled,
        'captureFailed' || 'capture' => strings.errorCaptureFailed,
        'playback' => strings.errorPlaybackFailed,
        'decode' => strings.errorRecordingDecode,
        'fileReadFailed' => strings.errorFileReadFailed,
        _ => strings.errorDeviceDetails(error.message ?? error.code),
      };
    }
    if (error is FormatException) {
      return strings.errorInvalidFormat(error.message);
    }
    if (error is FileSystemException) {
      return strings.errorFileOperation(error.message);
    }
    return strings.errorUnexpected(error.toString());
  });

  factory AppMessage.audioError({String? code, String? details}) {
    if (code == null && (details == null || details.isEmpty)) {
      return AppMessage((strings) => strings.errorAudioDevice);
    }
    return AppMessage.error(
      PlatformException(code: code ?? 'audio', message: details),
    );
  }
}
