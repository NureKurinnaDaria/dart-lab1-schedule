/// Тип одного заняття розкладу. Це запис (record), а не клас: у ЛР 1 класи
/// не використовуються.
typedef Lesson = ({
  String subject,
  String teacher,
  String type,
  int weekday,
  int startMinutes,
  String room,
  DateTime firstDate,
});

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

/// Індекси полів у розібраному рядку.
const _subjectIndex = 0;
const _teacherIndex = 1;
const _typeIndex = 2;
const _weekdayIndex = 3;
const _timeIndex = 4;
const _roomIndex = 5;
const _dateIndex = 6;

/// Допустимі типи занять.
const lessonTypes = {lectureType, 'практика', 'лабораторна', 'консультація'};

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

  return (
    lesson: (
      subject: subject,
      teacher: teacher,
      type: parts[_typeIndex],
      weekday: weekday,
      startMinutes: startMinutes,
      room: parts[_roomIndex],
      firstDate: firstDate,
    ),
    error: null,
  );
}

/// Перевіряє значення заняття й повертає перелік порушень.
///
/// Порожній список означає, що заняття коректне.
List<String> validateLesson(Lesson lesson) {
  final problems = <String>[];

  if (!lessonTypes.contains(lesson.type)) {
    problems.add('невідомий тип заняття «${lesson.type}»');
  }
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
