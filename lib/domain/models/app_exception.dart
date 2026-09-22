import 'dart:io';

/// Stable error identifiers let the UI resolve a diagnostic in its current locale.
enum AppFormatError {
  wavInvalidFile,
  wavPcmRequired,
  wavIncomplete,
  wavInvalidLength,
  wavUnsupportedFormat,
  wavIncompleteChunk,
  wavInvalidAudio,
  recordingTooLong,
  wavTooLarge,
  tuningTooLarge,
  tuningMissingLines,
  tuningInvalidReference,
  tuningInvalidFrequency,
  tuningMissingPitch,
  tuningTooManyNotes,
  tuningInvalidPitch,
  tuningZeroEquave,
  tuningReferenceNotFound,
}

class AppFormatException extends FormatException {
  const AppFormatException(this.code, super.message, {this.detail = ''});

  final AppFormatError code;
  final String detail;
}

class InvalidRecordingPathException extends FileSystemException {
  const InvalidRecordingPathException() : super('Invalid recording path');
}
