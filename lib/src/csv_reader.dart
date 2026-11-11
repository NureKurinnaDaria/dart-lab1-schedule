import 'dart:convert';
import 'dart:io';

import 'lesson.dart';

/// Результат читання CSV-файлу: коректні заняття й описи проблемних рядків.
typedef ImportResult = ({List<Lesson> lessons, List<String> problems});

/// Читає заняття з текстового файлу [path] рядок за рядком.
///
/// Файл не завантажується в пам'ять цілком: потік байтів проходить крізь
/// декодер UTF-8 і розбивач на рядки. Порожні рядки та коментарі (рядки, що
/// починаються з `#`) пропускаються. Некоректний рядок не зупиняє читання:
/// його опис потрапляє до `problems`.
///
/// Якщо файлу немає, викидає [FileSystemException].
Future<ImportResult> readLessonsFromCsv(
  String path, {
  String separator = defaultSeparator,
}) async {
  final lines = File(path)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  final lessons = <Lesson>[];
  final problems = <String>[];
  var number = 0;
  await for (final line in lines) {
    number++;
    final text = line.trim();
    if (text.isEmpty || text.startsWith('#')) continue;

    final result = parseLine(text, separator: separator);
    final lesson = result.lesson;
    if (lesson == null) {
      problems.add('рядок $number: ${result.error}');
      continue;
    }
    final errors = validateLesson(lesson);
    if (errors.isNotEmpty) {
      problems.add('рядок $number: ${errors.join(', ')}');
      continue;
    }
    lessons.add(lesson);
  }
  return (lessons: lessons, problems: problems);
}
