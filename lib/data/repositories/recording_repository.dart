import 'dart:io';

import '../../domain/models/app_exception.dart';
import '../../domain/models/wave_data.dart';
import '../services/platform_service.dart';

class RecordingEntry {
  const RecordingEntry(this.path, this.name, this.modified, this.size);
  final String path, name;
  final DateTime modified;
  final int size;
}

class RecordingRepository {
  RecordingRepository(this.platform);
  final PlatformService platform;
  Directory? _directory;
  Future<Directory> get directory async =>
      _directory ??= await Directory(await platform.getStorageDirectory())
          .create(recursive: true);

  Future<List<RecordingEntry>> list() async {
    final entries = <RecordingEntry>[];
    await for (final entity in (await directory).list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.wav')) {
        continue;
      }
      final stat = await entity.stat();
      entries.add(
        RecordingEntry(
          entity.path,
          entity.uri.pathSegments.last,
          stat.modified,
          stat.size,
        ),
      );
    }
    entries.sort((a, b) => b.modified.compareTo(a.modified));
    return entries;
  }

  Future<RecordingEntry> save(WaveData wave, {String? name}) async {
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final clean = (name ?? 'PitchVisual_$stamp').replaceAll(
      RegExp(r'[/\\:\x00-\x1f]'),
      '_',
    );
    final base = clean.toLowerCase().endsWith('.wav')
        ? clean.substring(0, clean.length - 4)
        : clean;
    final folder = await directory;
    var file = File('${folder.path}/$base.wav');
    var suffix = 1;
    while (await file.exists()) {
      file = File('${folder.path}/${base}_${suffix++}.wav');
    }
    final temp = File('${file.path}.partial');
    await temp.writeAsBytes(wave.encode(), flush: true);
    await temp.rename(file.path);
    final stat = await file.stat();
    return RecordingEntry(
      file.path,
      file.uri.pathSegments.last,
      stat.modified,
      stat.size,
    );
  }

  Future<WaveData> load(RecordingEntry entry) async {
    final file = await _checkedFile(entry);
    if (await file.length() > WaveData.maxFileBytes) {
      throw const AppFormatException(
        AppFormatError.wavTooLarge,
        'WAV file exceeds 64 MB',
      );
    }
    return WaveData.decode(await file.readAsBytes());
  }

  Future<void> delete(RecordingEntry entry) async =>
      (await _checkedFile(entry)).delete();
  Future<File> _checkedFile(RecordingEntry entry) async {
    final folder = await directory;
    final file = File(entry.path);
    if (file.parent.absolute.path != folder.absolute.path ||
        await FileSystemEntity.isLink(entry.path)) {
      throw const InvalidRecordingPathException();
    }
    return file;
  }
}
