import 'dart:io';

import 'package:lab4_schedule/lab4_schedule.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<String> writeTempFile(String content) async {
  final dir = await Directory.systemTemp.createTemp('lab4_csv_');
  addTearDown(() => dir.delete(recursive: true));
  final path = p.join(dir.path, 'lessons.csv');
  await File(path).writeAsString(content);
  return path;
}

void main() {
  group('readLessonsFromCsv', () {
    test('читає коректні рядки й пропускає порожні та коментарі', () async {
      final path = await writeTempFile(
        ['# коментар', rawLessons[0], '', rawLessons[1]].join('\n'),
      );

      final result = await readLessonsFromCsv(path);

      expect(result.lessons, hasLength(2));
      expect(result.problems, isEmpty);
    });

    test('некоректний рядок потрапляє до problems з номером', () async {
      final path = await writeTempFile(
        [rawLessons[0], 'пошкоджений рядок', rawLessons[1]].join('\n'),
      );

      final result = await readLessonsFromCsv(path);

      expect(result.lessons, hasLength(2));
      expect(result.problems.single, startsWith('рядок 2:'));
    });

    test('читає великий файл рядок за рядком', () async {
      final path = await writeTempFile(
        List.filled(5000, rawLessons.first).join('\n'),
      );

      final result = await readLessonsFromCsv(path);

      expect(result.lessons, hasLength(5000));
    });

    test('для відсутнього файлу кидає FileSystemException', () async {
      await expectLater(
        readLessonsFromCsv('no/such/file.csv'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
