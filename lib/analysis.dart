import 'lesson.dart';

/// Умова відбору елементів.
typedef Predicate<T> = bool Function(T item);

/// Порівняння двох занять для сортування.
typedef LessonComparator = int Function(Lesson a, Lesson b);

/// Лічильник: `count` живе в замиканні й зберігається між викликами.
int Function() makeCounter() {
  var count = 0;
  return () => ++count;
}

/// Умова «заняття в цей день тижня».
Predicate<Lesson> onWeekday(int weekday) =>
    (lesson) => lesson.weekday == weekday;

/// Умова «заняття цього типу».
Predicate<Lesson> ofType(String type) =>
    (lesson) => lesson.type == type;

/// Розбирає рядки й залишає лише коректні заняття.
List<Lesson> parseAndValidate(Iterable<String> lines) => lines
    .map(parseLine)
    .map((result) => result.lesson)
    .nonNulls
    .where((lesson) => validateLesson(lesson).isEmpty)
    .toList();

/// Відбирає заняття за умовою.
List<Lesson> filterLessons(Iterable<Lesson> items, Predicate<Lesson> test) =>
    items.where(test).toList();

/// Перетворює заняття на рядки для виводу.
List<String> toTimetableLines(Iterable<Lesson> items) => items
    .map(
      (lesson) =>
          '${formatTime(lesson.startMinutes)} ${lesson.subject} '
          '(${lesson.type}), ${lesson.teacher}',
    )
    .toList();

/// Найраніший, найпізніший і середній час початку (у хвилинах).
({int earliest, int latest, double average})? startTimeStats(
  List<Lesson> items,
) {
  if (items.isEmpty) return null;
  final first = items.first.startMinutes;
  final totals = items.fold<({int min, int max, int sum})>(
    (min: first, max: first, sum: 0),
    (acc, lesson) => (
      min: lesson.startMinutes < acc.min ? lesson.startMinutes : acc.min,
      max: lesson.startMinutes > acc.max ? lesson.startMinutes : acc.max,
      sum: acc.sum + lesson.startMinutes,
    ),
  );
  return (
    earliest: totals.min,
    latest: totals.max,
    average: totals.sum / items.length,
  );
}

/// Перше заняття з дисципліни або `null`.
Lesson? firstOfSubject(Iterable<Lesson> items, String subject) =>
    items.where((lesson) => lesson.subject == subject).firstOrNull;

/// Групує елементи за ключем.
Map<K, List<T>> groupBy<K, T>(Iterable<T> items, K Function(T) keyOf) {
  final result = <K, List<T>>{};
  for (final item in items) {
    (result[keyOf(item)] ??= []).add(item);
  }
  return result;
}

/// Кількість занять у кожного викладача.
Map<String, int> countByTeacher(Iterable<Lesson> items) =>
    groupBy<String, Lesson>(
      items,
      (lesson) => lesson.teacher,
    ).map((teacher, group) => MapEntry(teacher, group.length));

/// Сортування за днем тижня, потім за часом.
int byTime(Lesson a, Lesson b) {
  final byDay = a.weekday.compareTo(b.weekday);
  return byDay != 0 ? byDay : a.startMinutes.compareTo(b.startMinutes);
}

/// Сортування за дисципліною, потім за часом.
int bySubject(Lesson a, Lesson b) {
  final byName = a.subject.compareTo(b.subject);
  return byName != 0 ? byName : byTime(a, b);
}

/// Повертає відсортовану копію; `descending` змінює напрям.
List<Lesson> sortLessons(
  List<Lesson> items, {
  LessonComparator by = byTime,
  bool descending = false,
}) {
  final sorted = [...items]..sort(by);
  return descending ? sorted.reversed.toList() : sorted;
}

/// Назва дня тижня за номером (1 — понеділок).
String weekdayName(int weekday) => weekdayNames[weekday - DateTime.monday];

/// Час від першого заняття до `now`; від’ємний, якщо воно ще попереду.
Duration timeSinceFirst(Lesson lesson, {DateTime? now}) =>
    (now ?? DateTime.now()).difference(lesson.firstDate);
