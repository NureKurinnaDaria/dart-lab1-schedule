import 'analysis.dart';
import 'lesson.dart';

/// Скільки викладачів показувати в рейтингу за замовчуванням.
const defaultTopCount = 3;

/// Роздільник колонок за замовчуванням.
const defaultColumnSeparator = ' | ';

/// Ширина лінії-розділювача.
const reportRuleWidth = 40;

/// Символ для прихованих літер прізвища.
const maskChar = '*';

/// Скільки перших літер прізвища лишається видимими.
const visibleSurnameChars = 1;

/// Маскує прізвище: `Баличев М. Д.` стає `Б****** М. Д.`.
///
/// Якщо рядок не відповідає формату «Прізвище І. Б.», повертає його без змін.
String maskTeacher(String teacher) {
  final match = teacherPattern.firstMatch(teacher);
  if (match == null) return teacher;
  final surname = match.namedGroup('surname') ?? '';
  final visible = surname.substring(0, visibleSurnameChars);
  final hidden = maskChar * (surname.length - visibleSurnameChars);
  return '$visible$hidden ${match.namedGroup('first')}. '
      '${match.namedGroup('second')}.';
}

/// Формує текстовий звіт про розклад.
String buildReport(
  List<Lesson> items, {
  int topCount = defaultTopCount,
  bool descending = false,
  String separator = defaultColumnSeparator,
  bool maskTeachers = false,
}) {
  String teacherName(String teacher) =>
      maskTeachers ? maskTeacher(teacher) : teacher;

  final buffer = StringBuffer()
    ..writeln('РОЗКЛАД (занять: ${items.length})')
    ..writeln('=' * reportRuleWidth);

  final byDay = groupBy<int, Lesson>(
    sortLessons(items, descending: descending),
    (lesson) => lesson.weekday,
  );
  for (final MapEntry(key: day, value: dayLessons) in byDay.entries) {
    buffer.writeln(weekdayName(day));
    for (final lesson in dayLessons) {
      final columns = [
        formatTime(lesson.startMinutes),
        lesson.subject,
        lesson.type,
        teacherName(lesson.teacher),
      ];
      buffer.writeln('  ${columns.join(separator)}');
    }
  }

  final load = countByTeacher(items).entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  buffer
    ..writeln('-' * reportRuleWidth)
    ..writeln('Найбільше занять:');
  for (final entry in load.take(topCount)) {
    buffer.writeln('  ${teacherName(entry.key)}$separator${entry.value}');
  }
  return buffer.toString();
}
