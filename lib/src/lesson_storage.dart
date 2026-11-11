import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'lesson.dart';

/// Каталог із даними розкладу за замовчуванням.
const defaultDataDirectory = 'data';

/// Ім'я файлу з розкладом за замовчуванням.
const defaultScheduleFileName = 'schedule.json';

/// Зберігає розклад у JSON-файлі та завантажує його назад.
class LessonFileStorage {
  /// Створює сховище, що працює з файлом [fileName] у каталозі [directory].
  LessonFileStorage({
    this.directory = defaultDataDirectory,
    this.fileName = defaultScheduleFileName,
  });

  /// Каталог, у якому лежить файл.
  final String directory;

  /// Ім'я файлу.
  final String fileName;

  /// Повний шлях до файлу, побудований через `p.join`.
  String get path => p.join(directory, fileName);

  /// Записує [lessons] у файл; створює каталог, якщо його немає.
  Future<void> save(List<Lesson> lessons) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final json = [for (final lesson in lessons) lesson.toJson()];
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }

  /// Читає розклад із файлу; якщо файлу немає, повертає порожній список.
  ///
  /// Викидає [FormatException], якщо вміст не є коректним JSON-масивом
  /// занять.
  Future<List<Lesson>> load() async {
    final file = File(path);
    if (!await file.exists()) return [];

    // jsonDecode повертає dynamic, тому результат одразу перевіряється
    // й перетворюється на модель.
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! List<Object?>) {
      throw FormatException('очікувався масив занять', decoded);
    }

    final lessons = <Lesson>[];
    for (final item in decoded) {
      if (item is! Map<String, Object?>) {
        throw FormatException('елемент масиву не є об’єктом', item);
      }
      lessons.add(Lesson.fromJson(item));
    }
    return lessons;
  }
}
