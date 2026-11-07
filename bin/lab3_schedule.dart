import 'dart:async';
import 'dart:io';

import 'package:lab3_schedule/analysis.dart';
import 'package:lab3_schedule/async_repository.dart';
import 'package:lab3_schedule/data.dart';
import 'package:lab3_schedule/lesson.dart';
import 'package:lab3_schedule/report.dart';

/// Кількість занять, починаючи з якої викладач вважається завантаженим.
const heavyLoad = 3;

/// Дисципліна, про яку виводиться окрема інформація.
const featuredSubject = 'Програмування мовою Dart';

/// Роздільник колонок у звіті з масками.
const maskedSeparator = ' / ';

/// Скільки викладачів показувати в звіті з масками.
const maskedTopCount = 2;

/// Тривалість однієї імітованої операції в порівнянні режимів виконання.
const operationDelay = Duration(milliseconds: 500);

/// Розбирає розклад, перевіряє його й виводить статистику та звіти.
Future<void> main() async {
  final now = DateTime.now();
  final lessons = parseAndValidate(rawLessons);

  stdout.writeln('Проблемні записи:');
  _printProblems(rawLessons);
  stdout.writeln(
    'Коректних записів: ${lessons.length} із ${rawLessons.length}',
  );

  stdout.writeln('\nЧетвер:');
  final thursday = filterLessons(lessons, onWeekday(DateTime.thursday));
  for (final line in toTimetableLines(sortLessons(thursday))) {
    stdout.writeln('  $line');
  }

  final lectures = filterLessons(lessons, ofType(lectureType));
  stdout.writeln('Лекцій: ${lectures.length}');

  final lectureAverage = averageStart(lessons, ofType(lectureType));
  if (lectureAverage != null) {
    stdout.writeln(
      'Середній початок лекцій: ${formatTime(lectureAverage.round())}',
    );
  }

  final stats = startTimeStats(lessons);
  if (stats != null) {
    stdout.writeln(
      'Час початку: найраніше ${formatTime(stats.earliest)}, '
      'найпізніше ${formatTime(stats.latest)}, '
      'середнє ${formatTime(stats.average.round())}',
    );
  }

  final featured = firstOfSubject(lessons, featuredSubject);
  if (featured != null) {
    final days = timeSinceFirst(featured, now: now).inDays;
    stdout.writeln(
      'Перше заняття з $featuredSubject (${weekdayName(featured.weekday)}) '
      'відбулося $days дн. тому',
    );
  }

  stdout.writeln('\nНайбільше навантаження:');
  for (final entry in countByTeacher(lessons).entries) {
    if (entry.value >= heavyLoad) {
      stdout.writeln('  ${entry.key}: ${entry.value}');
    }
  }

  stdout
    ..writeln()
    ..write(buildReport(lessons))
    ..writeln()
    ..write(
      buildReport(
        lessons,
        maskTeachers: true,
        descending: true,
        separator: maskedSeparator,
        topCount: maskedTopCount,
      ),
    );

  _printExtras(lessons);
  await _printAsyncDemo(lessons);
  await _forgottenAwaitDemo(lessons);
  await _timingDemo();
  await _parallelErrorDemo();
}

/// Виводить причину для кожного запису, що не пройшов розбір чи перевірку.
void _printProblems(List<String> lines) {
  final nextNumber = makeCounter();
  for (final line in lines) {
    final number = nextNumber();
    final (:lesson, :error) = parseLine(line);
    if (lesson == null) {
      stdout.writeln('  Запис $number: не розібрано, $error');
      continue;
    }
    final violations = validateLesson(lesson);
    if (violations.isNotEmpty) {
      stdout.writeln('  Запис $number: ${violations.join('; ')}');
    }
  }
}

/// Показує роботу фабрики `fromCsv`, сховища, розширення й домішки.
void _printExtras(List<Lesson> lessons) {
  final sample = Lesson.fromCsv(rawLessons.first);
  final again = Lesson.fromCsv(rawLessons.first);
  stdout
    ..writeln('\nfromCsv: $sample')
    ..writeln('Кеш повертає той самий об’єкт: ${identical(sample, again)}');

  final repository = Repository<Lesson>();
  lessons.forEach(repository.add);
  stdout.writeln('\nУ сховищі: ${repository.length} занять');

  stdout.writeln('П’ятниця:');
  for (final lesson in lessons.onDay(Weekday.friday)) {
    final place = lesson is RemoteCapable
        ? lesson.placeLabel
        : 'ауд. ${lesson.room}';
    stdout.writeln(
      '  ${shortLabel(lesson)} · ${timeNote(lesson)} · $place: '
      '${lesson.subject}',
    );
  }
}

/// Показує асинхронне сховище: збереження, завантаження й видалення.
Future<void> _printAsyncDemo(List<Lesson> lessons) async {
  final repository = AsyncRepository<Lesson>();
  for (final lesson in lessons.take(3)) {
    await repository.save(lesson);
  }
  stdout.writeln('\nАсинхронне сховище: ${repository.length} занять');

  final first = lessons.first;
  final loaded = await repository.load(first.id);
  stdout.writeln('load: ${loaded ?? 'не знайдено'}');

  final removed = await repository.delete(first.id);
  final again = await repository.load(first.id);
  stdout.writeln(
    'delete: $removed, після видалення: ${again ?? 'не знайдено'}',
  );
}

/// Показує помилку «забутий await»: без нього результат ще не готовий.
Future<void> _forgottenAwaitDemo(List<Lesson> lessons) async {
  final repository = AsyncRepository<Lesson>();

  // ignore: unawaited_futures
  repository.save(lessons.first);
  stdout.writeln('\nБез await: ${repository.length} занять');

  await repository.save(lessons.first);
  stdout.writeln('З await: ${repository.length} занять');
}

/// Порівнює час послідовного й одночасного виконання трьох операцій.
Future<void> _timingDemo() async {
  Future<void> operation() => Future<void>.delayed(operationDelay);

  final sequential = Stopwatch()..start();
  await operation();
  await operation();
  await operation();
  sequential.stop();

  final concurrent = Stopwatch()..start();
  await Future.wait([operation(), operation(), operation()]);
  concurrent.stop();

  stdout
    ..writeln('\nПослідовно: ${sequential.elapsedMilliseconds} мс')
    ..writeln('Одночасно: ${concurrent.elapsedMilliseconds} мс');
}

/// Порівнює обробку помилок через `Future.wait` і розширення `.wait`.
Future<void> _parallelErrorDemo() async {
  Future<int> succeed(int id) async {
    await Future<void>.delayed(operationDelay);
    return id;
  }

  Future<int> fail(int id) async {
    await Future<void>.delayed(operationDelay);
    throw Exception('операція $id завершилась помилкою');
  }

  stdout.writeln('\nFuture.wait:');
  try {
    await Future.wait([succeed(1), fail(2), fail(3)]);
  } on Exception catch (error) {
    stdout.writeln('  помилка: $error');
  }

  stdout.writeln('.wait:');
  try {
    await [succeed(1), fail(2), fail(3)].wait;
  } on ParallelWaitError<List<int?>, List<AsyncError?>> catch (error) {
    stdout.writeln('  значення: ${error.values}');
    stdout.writeln('  помилки: ${error.errors.map((e) => e?.error).toList()}');
  }
}
