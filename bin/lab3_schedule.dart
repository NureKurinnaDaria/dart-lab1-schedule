import 'dart:io';

import 'package:lab3_schedule/analysis.dart';
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

/// Розбирає розклад, перевіряє його й виводить статистику та звіти.
void main() {
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
