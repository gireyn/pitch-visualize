import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_visual/data/repositories/recording_repository.dart';
import 'package:pitch_visual/domain/models/wave_data.dart';

import 'fakes.dart';

void main() {
  late Directory folder;
  late FakePlatformService platform;
  late RecordingRepository repository;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('pitch-recording-test-');
    platform = FakePlatformService(folder.path);
    repository = RecordingRepository(platform);
  });
  tearDown(() async {
    await platform.close();
    await folder.delete(recursive: true);
  });
  final wave = WaveData(
    pcm: Uint8List.fromList([0, 0, 255, 127]),
    sampleRate: 44100,
  );

  test(
    'save/load retains samples and duplicate names keep both recordings',
    () async {
      final first = await repository.save(wave, name: 'vocal.wav');
      final second = await repository.save(wave, name: 'vocal.wav');
      expect(first.name, 'vocal.wav');
      expect(second.name, 'vocal_1.wav');
      expect((await repository.list()).length, 2);
      expect((await repository.load(first)).pcm, wave.pcm);
      expect(
        (await folder.list().toList()).any(
          (file) => file.path.endsWith('.partial'),
        ),
        isFalse,
      );
    },
  );
  test(
    'unsafe suggested filenames stay inside the recording directory',
    () async {
      final entry = await repository.save(wave, name: '../../voice.wav');
      expect(File(entry.path).parent.path, folder.path);
      expect(File(entry.path).existsSync(), isTrue);
    },
  );
  test(
    'list ignores unrelated files and delete removes only selected recording',
    () async {
      final first = await repository.save(wave, name: 'one');
      final second = await repository.save(wave, name: 'two');
      await File('${folder.path}/notes.txt').writeAsString('keep');
      await Directory('${folder.path}/folder.wav').create();
      expect((await repository.list()).length, 2);
      await repository.delete(first);
      expect((await repository.list()).single.path, second.path);
      expect(File('${folder.path}/notes.txt').existsSync(), isTrue);
    },
  );
  test(
    'out of directory entries and symlinks cannot be loaded or deleted',
    () async {
      final outside = await Directory.systemTemp.createTemp(
        'pitch-outside-test-',
      );
      try {
        final target = await File(
          '${outside.path}/outside.wav',
        ).writeAsBytes(wave.encode());
        final entry = RecordingEntry(
          target.path,
          'outside.wav',
          DateTime.now(),
          48,
        );
        await expectLater(
          repository.load(entry),
          throwsA(isA<FileSystemException>()),
        );
        await expectLater(
          repository.delete(entry),
          throwsA(isA<FileSystemException>()),
        );
        final link = await Link('${folder.path}/link.wav').create(target.path);
        final linkedEntry = RecordingEntry(
          link.path,
          'link.wav',
          DateTime.now(),
          48,
        );
        await expectLater(
          repository.load(linkedEntry),
          throwsA(isA<FileSystemException>()),
        );
        expect((await repository.list()), isEmpty);
        expect(target.existsSync(), isTrue);
      } finally {
        await outside.delete(recursive: true);
      }
    },
  );
}
