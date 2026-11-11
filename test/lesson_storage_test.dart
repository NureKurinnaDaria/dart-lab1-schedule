import 'dart:io';

import 'package:lab4_schedule/lab4_schedule.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<Directory> makeTempDir() async {
  final dir = await Directory.systemTemp.createTemp('lab4_');
  addTearDown(() => dir.delete(recursive: true));
  return dir;
}

void main() {
  final lessons = [for (final line in rawLessons.take(3)) Lesson.fromCsv(line)];

  group('LessonFileStorage', () {
    test('save і load повертають ті самі заняття', () async {
      final dir = await makeTempDir();
      final storage = LessonFileStorage(directory: dir.path);

      await storage.save(lessons);

      expect(await storage.load(), lessons);
    });

    test('save створює каталог, якого ще немає', () async {
      final dir = await makeTempDir();
      final storage = LessonFileStorage(
        directory: p.join(dir.path, 'nested', 'data'),
      );

      await storage.save(lessons);

      expect(File(storage.path).existsSync(), isTrue);
    });

    test('load повертає порожній список, якщо файлу немає', () async {
      final dir = await makeTempDir();
      final storage = LessonFileStorage(directory: dir.path);

      expect(await storage.load(), isEmpty);
    });

    test('load кидає FormatException для пошкодженого файлу', () async {
      final dir = await makeTempDir();
      final storage = LessonFileStorage(directory: dir.path);
      await File(storage.path).writeAsString('це не JSON');

      await expectLater(storage.load(), throwsFormatException);
    });
  });
}
