/// Домішка для занять, що можуть проходити дистанційно.
mixin RemoteCapable on Lesson {
  /// Чи проходить заняття дистанційно.
  bool get isOnline => room == onlineRoom;

  /// Підпис місця проведення для виводу.
  String get placeLabel => isOnline ? 'дистанційно' : 'ауд. $room';
}

/// День тижня з номером за ISO 8601 (1 — понеділок).
enum Weekday {
  monday(DateTime.monday, 'Понеділок'),
  tuesday(DateTime.tuesday, 'Вівторок'),
  wednesday(DateTime.wednesday, 'Середа'),
  thursday(DateTime.thursday, 'Четвер'),
  friday(DateTime.friday, 'П’ятниця'),
  saturday(DateTime.saturday, 'Субота'),
  sunday(DateTime.sunday, 'Неділя');

  const Weekday(this.number, this.label);

  /// Номер дня тижня (1-7).
  final int number;

  /// Українська назва дня.
  final String label;

  /// Повертає день за номером або `null`, якщо номер поза діапазоном 1-7.
  static Weekday? fromNumber(int number) {
    for (final day in values) {
      if (day.number == number) return day;
    }
    return null;
  }

  /// Чи є день вихідним.
  bool get isWeekend => this == saturday || this == sunday;
}

/// Домішка: усе, що стосується місця заняття в тижневій сітці.
mixin Scheduled {
  /// Номер дня тижня (1-7).
  int get weekday;

  /// Початок заняття у хвилинах від початку доби.
  int get startMinutes;

  /// Назва дня тижня або `?`, якщо номер поза діапазоном.
  String get dayName => Weekday.fromNumber(weekday)?.label ?? '?';

  /// Початок заняття у форматі `ГГ:ХХ`.
  String get startTime => formatTime(startMinutes);
}

/// Базове заняття розкладу; конкретний тип задає підклас.
sealed class Lesson with Scheduled {
  Lesson({
    required this.subject,
    required this.teacher,
    required this.weekday,
    required this.startMinutes,
    required this.room,
    required this.firstDate,
  });

  /// Кеш уже розібраних рядків: заняття незмінні, тому той самий рядок
  /// безпечно повертає той самий об'єкт.
  static final Map<String, Lesson> _cache = {};

  /// Розбирає рядок [line] у заняття; для повторного рядка повертає
  /// об'єкт із кешу.
  ///
  /// Викидає [FormatException], якщо рядок некоректний.
  factory Lesson.fromCsv(String line, {String separator = defaultSeparator}) {
    final key = '$separator$line';
    final cached = _cache[key];
    if (cached != null) return cached;

    final result = parseLine(line, separator: separator);
    final lesson = result.lesson;
    if (lesson == null) {
      throw FormatException(result.error ?? 'некоректний рядок', line);
    }
    return _cache[key] = lesson;
  }

  final String subject;
  final String teacher;
  @override
  final int weekday;
  @override
  final int startMinutes;
  final String room;
  final DateTime firstDate;

  /// Назва типу заняття; у кожному підкласі своя.
  String get type;

  /// Тривалість заняття в хвилинах; у кожному підкласі своя.
  int get durationMinutes;

  /// Створює підклас за назвою типу або повертає `null`, якщо тип невідомий.
  static Lesson? create(
    String type, {
    required String subject,
    required String teacher,
    required int weekday,
    required int startMinutes,
    required String room,
    required DateTime firstDate,
  }) {
    switch (type) {
      case lectureType:
        return Lecture(
          subject: subject,
          teacher: teacher,
          weekday: weekday,
          startMinutes: startMinutes,
          room: room,
          firstDate: firstDate,
        );
      case practiceType:
        return Practice(
          subject: subject,
          teacher: teacher,
          weekday: weekday,
          startMinutes: startMinutes,
          room: room,
          firstDate: firstDate,
        );
      case labType:
        return Lab(
          subject: subject,
          teacher: teacher,
          weekday: weekday,
          startMinutes: startMinutes,
          room: room,
          firstDate: firstDate,
        );
      case consultationType:
        return Consultation(
          subject: subject,
          teacher: teacher,
          weekday: weekday,
          startMinutes: startMinutes,
          room: room,
          firstDate: firstDate,
        );
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Lesson &&
      other.runtimeType == runtimeType &&
      other.subject == subject &&
      other.teacher == teacher &&
      other.weekday == weekday &&
      other.startMinutes == startMinutes &&
      other.room == room &&
      other.firstDate == firstDate;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    subject,
    teacher,
    weekday,
    startMinutes,
    room,
    firstDate,
  );

  @override
  String toString() => '$dayName $startTime · $type: $subject ($room)';
}

/// Лекція.
class Lecture extends Lesson with RemoteCapable {
  Lecture({
    required super.subject,
    required super.teacher,
    required super.weekday,
    required super.startMinutes,
    required super.room,
    required super.firstDate,
  });

  @override
  String get type => lectureType;

  @override
  int get durationMinutes => pairDurationMinutes;
}

/// Практичне заняття.
class Practice extends Lesson {
  Practice({
    required super.subject,
    required super.teacher,
    required super.weekday,
    required super.startMinutes,
    required super.room,
    required super.firstDate,
  });

  @override
  String get type => practiceType;

  @override
  int get durationMinutes => pairDurationMinutes;
}

/// Лабораторна робота.
class Lab extends Lesson {
  Lab({
    required super.subject,
    required super.teacher,
    required super.weekday,
    required super.startMinutes,
    required super.room,
    required super.firstDate,
  });

  @override
  String get type => labType;

  @override
  int get durationMinutes => pairDurationMinutes;
}

/// Консультація.
class Consultation extends Lesson with RemoteCapable {
  Consultation({
    required super.subject,
    required super.teacher,
    required super.weekday,
    required super.startMinutes,
    required super.room,
    required super.firstDate,
  });

  @override
  String get type => consultationType;

  @override
  int get durationMinutes => pairDurationMinutes;
}

/// Короткий підпис типу заняття для компактних відображень.
String shortLabel(Lesson lesson) => switch (lesson) {
  Lecture() => 'Лк',
  Practice() => 'Пз',
  Lab() => 'Лб',
  Consultation() => 'Конс',
  RemoteCapable() => lesson.type,
};

/// Зручні запити до колекції занять.
extension LessonIterable on Iterable<Lesson> {
  /// Заняття, що проходять у вказаний день тижня.
  Iterable<Lesson> onDay(Weekday day) =>
      where((lesson) => lesson.weekday == day.number);
}

/// Результат розбору рядка: або заняття, або опис помилки.
typedef ParseResult = ({Lesson? lesson, String? error});

/// Ширина поля годин і хвилин у записі часу.
const timeFieldWidth = 2;

/// Символ, яким доповнюється поле до потрібної ширини.
const timePadChar = '0';

/// Кількість частин у записі часу `ГГ:ХХ`.
const timePartCount = 2;

/// Тип заняття «лекція».
const lectureType = 'лекція';

/// Тип заняття «практика».
const practiceType = 'практика';

/// Тип заняття «лабораторна».
const labType = 'лабораторна';

/// Тип заняття «консультація».
const consultationType = 'консультація';

/// Кількість полів у рядку вхідних даних.
const fieldCount = 7;

/// Роздільник полів за замовчуванням.
const defaultSeparator = ';';

/// Роздільник годин і хвилин у записі часу.
const timeSeparator = ':';

/// Позначення дистанційного заняття в полі аудиторії.
const onlineRoom = 'DL';

/// Хвилин в одній годині.
const minutesPerHour = 60;

/// Остання допустима година доби.
const maxHour = 23;

/// Остання допустима хвилина години.
const maxMinute = 59;

/// Довжина дати у форматі `РРРР-ММ-ДД`.
const isoDateLength = 10;

/// Тривалість заняття в хвилинах (спрощення: фактична пара — 95 хв).
const pairDurationMinutes = 90;

/// Індекси полів у розібраному рядку.
const _subjectIndex = 0;
const _teacherIndex = 1;
const _typeIndex = 2;
const _weekdayIndex = 3;
const _timeIndex = 4;
const _roomIndex = 5;
const _dateIndex = 6;

/// Допустимі типи занять.
const lessonTypes = {lectureType, practiceType, labType, consultationType};

/// Початки пар у хвилинах від початку доби:
/// 07:45, 09:30, 11:15, 13:10, 14:55, 16:40.
const pairStartMinutes = {
  7 * minutesPerHour + 45,
  9 * minutesPerHour + 30,
  11 * minutesPerHour + 15,
  13 * minutesPerHour + 10,
  14 * minutesPerHour + 55,
  16 * minutesPerHour + 40,
};

/// Назви днів тижня; індекс на одиницю менший за номер дня.
const weekdayNames = [
  'Понеділок',
  'Вівторок',
  'Середа',
  'Четвер',
  'П’ятниця',
  'Субота',
  'Неділя',
];

/// Формат аудиторії очного заняття: літера корпусу, дефіс, три цифри.
final roomPattern = RegExp(r'^[А-ЯІЇЄҐ]-\d{3}$');

/// Формат викладача: «Прізвище І. Б.» з іменованими групами.
final teacherPattern = RegExp(
  r'^(?<surname>[А-ЯІЇЄҐ][а-яіїєґ’-]+) '
  r'(?<first>[А-ЯІЇЄҐ])\. (?<second>[А-ЯІЇЄҐ])\.$',
);

/// Розбирає час `ГГ:ХХ` у хвилини від початку доби.
///
/// Повертає `null`, якщо рядок не має формату `ГГ:ХХ` або година чи
/// хвилини виходять за межі доби.
int? parseTime(String raw) {
  final parts = raw.split(timeSeparator);
  if (parts.length != timePartCount) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  if (hours < 0 || hours > maxHour || minutes < 0 || minutes > maxMinute) {
    return null;
  }
  return hours * minutesPerHour + minutes;
}

/// Розбирає дату формату `РРРР-ММ-ДД`.
///
/// [DateTime.tryParse] «переносить» неіснуючі дати (місяць 13 стає
/// січнем наступного року), тому результат перевіряється зворотним
/// форматуванням: якщо рядок змінився, дата була некоректною.
DateTime? parseDate(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return null;
  final normalized = date.toIso8601String().substring(0, isoDateLength);
  return normalized == raw ? date : null;
}

/// Перетворює хвилини від початку доби на рядок `ГГ:ХХ`.
String formatTime(int totalMinutes) {
  final hours = (totalMinutes ~/ minutesPerHour).toString().padLeft(
    timeFieldWidth,
    timePadChar,
  );
  final minutes = (totalMinutes % minutesPerHour).toString().padLeft(
    timeFieldWidth,
    timePadChar,
  );
  return '$hours$timeSeparator$minutes';
}

/// Розбирає рядок [line] у заняття.
///
/// Помилки вхідних даних очікувані, тому замість винятків повертається
/// запис, у якому або `lesson`, або `error` дорівнює `null`.
ParseResult parseLine(String line, {String separator = defaultSeparator}) {
  final parts = line.split(separator).map((part) => part.trim()).toList();
  if (parts.length != fieldCount) {
    return (
      lesson: null,
      error: 'очікується $fieldCount полів, знайдено ${parts.length}',
    );
  }

  final subject = parts[_subjectIndex];
  final teacher = parts[_teacherIndex];
  if (subject.isEmpty || teacher.isEmpty) {
    return (lesson: null, error: 'порожня дисципліна або викладач');
  }

  final weekday = int.tryParse(parts[_weekdayIndex]);
  if (weekday == null) {
    return (
      lesson: null,
      error: 'день тижня «${parts[_weekdayIndex]}» не є числом',
    );
  }

  final startMinutes = parseTime(parts[_timeIndex]);
  if (startMinutes == null) {
    return (
      lesson: null,
      error: 'час «${parts[_timeIndex]}» має бути у форматі ГГ:ХХ',
    );
  }

  final firstDate = parseDate(parts[_dateIndex]);
  if (firstDate == null) {
    return (lesson: null, error: 'некоректна дата «${parts[_dateIndex]}»');
  }

  final lesson = Lesson.create(
    parts[_typeIndex],
    subject: subject,
    teacher: teacher,
    weekday: weekday,
    startMinutes: startMinutes,
    room: parts[_roomIndex],
    firstDate: firstDate,
  );
  if (lesson == null) {
    return (
      lesson: null,
      error: 'невідомий тип заняття «${parts[_typeIndex]}»',
    );
  }
  return (lesson: lesson, error: null);
}

/// Перевіряє значення заняття й повертає перелік порушень.
///
/// Порожній список означає, що заняття коректне.
List<String> validateLesson(Lesson lesson) {
  final problems = <String>[];

  if (lesson.weekday < DateTime.monday || lesson.weekday > DateTime.sunday) {
    problems.add('день тижня ${lesson.weekday} поза діапазоном 1–7');
  }
  if (!pairStartMinutes.contains(lesson.startMinutes)) {
    problems.add('час ${formatTime(lesson.startMinutes)} не є початком пари');
  }
  if (lesson.room != onlineRoom && !roomPattern.hasMatch(lesson.room)) {
    problems.add(
      'аудиторія «${lesson.room}» має бути DL або мати формат Л-401',
    );
  }
  if (!teacherPattern.hasMatch(lesson.teacher)) {
    problems.add(
      'викладач «${lesson.teacher}» має мати формат «Прізвище І. Б.»',
    );
  }
  if (lesson.firstDate.weekday != lesson.weekday) {
    problems.add('день тижня не збігається з днем тижня дати');
  }
  return problems;
}
