import 'dart:io';

import 'package:lab1_schedule/analysis.dart';
import 'package:lab1_schedule/data.dart';
import 'package:lab1_schedule/lesson.dart';
import 'package:lab1_schedule/report.dart';

/// Кількість занять, починаючи з якої викладач вважається завантаженим.
const heavyLoad = 3;

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

  stdout.writeln('Лекцій: ${filterLessons(lessons, ofType('лекція')).length}');

  final stats = startTimeStats(lessons);
  if (stats != null) {
    stdout.writeln(
      'Час початку: найраніше ${formatTime(stats.earliest)}, '
      'найпізніше ${formatTime(stats.latest)}, '
      'середнє ${formatTime(stats.average.round())}',
    );
  }

  final dart = firstOfSubject(lessons, 'Програмування мовою Dart');
  if (dart != null) {
    final days = timeSinceFirst(dart, now: now).inDays;
    stdout.writeln(
      'Перше заняття з Dart (${weekdayName(dart.weekday)}) '
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
        separator: ' / ',
        topCount: 2,
      ),
    );
}

/// Виводить причину для кожного запису, що не пройшов розбір чи перевірку.
void _printProblems(List<String> lines) {
  final nextNumber = makeCounter();
  for (final line in lines) {
    final number = nextNumber();
    final result = parseLine(line);
    final lesson = result.lesson;
    if (lesson == null) {
      stdout.writeln('  Запис $number: не розібрано, ${result.error}');
      continue;
    }
    final violations = validateLesson(lesson);
    if (violations.isNotEmpty) {
      stdout.writeln('  Запис $number: ${violations.join('; ')}');
    }
  }
}
