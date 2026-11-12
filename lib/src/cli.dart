import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import 'analysis.dart';
import 'csv_reader.dart';
import 'holiday.dart';
import 'holiday_client.dart';
import 'lesson.dart';
import 'lesson_storage.dart';
import 'report.dart';

/// Назва програми в довідці.
const cliName = 'schedule';

/// Успішне завершення.
const exitOk = 0;

/// Некоректні аргументи командного рядка.
const exitUsage = 64;

/// Некоректні або відсутні дані.
const exitDataError = 65;

/// Зовнішній сервіс недоступний або відповів помилкою.
const exitUnavailable = 69;

/// Помилка читання чи запису файлу.
const exitIoError = 74;

/// Запускає консольний застосунок і повертає код завершення.
///
/// Звичайний вивід іде в [out], повідомлення про помилки — в [err].
/// Через [httpClient] тести підміняють мережу.
Future<int> runCli(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
  http.Client? httpClient,
}) async {
  final runner = _ScheduleRunner(out)
    ..argParser.addOption(
      'data-dir',
      defaultsTo: defaultDataDirectory,
      help: 'Каталог із JSON-файлом розкладу.',
    )
    ..argParser.addOption(
      'file',
      defaultsTo: defaultScheduleFileName,
      help: "Ім'я JSON-файлу розкладу.",
    )
    ..addCommand(ImportCommand(out, err))
    ..addCommand(ReportCommand(out, err))
    ..addCommand(HolidaysCommand(out, err, httpClient));

  try {
    return await runner.run(arguments) ?? exitOk;
  } on UsageException catch (error) {
    err
      ..writeln(error.message)
      ..writeln()
      ..writeln(error.usage);
    return exitUsage;
  } on HolidayException catch (error) {
    err.writeln('Не вдалося отримати свята: ${error.message}');
    return error is HolidayFormatException ? exitDataError : exitUnavailable;
  } on FormatException catch (error) {
    err.writeln('Некоректні дані: ${error.message}');
    return exitDataError;
  } on FileSystemException catch (error) {
    err.writeln('Помилка файлу ${error.path ?? ''}: ${error.message}');
    return exitIoError;
  }
}

/// Диспетчер команд, який друкує довідку у вказаний [out], а не в `print`.
class _ScheduleRunner extends CommandRunner<int> {
  _ScheduleRunner(this._out)
    : super(cliName, 'Розклад занять групи ПЗПІ-23-9.');

  final StringSink _out;

  @override
  void printUsage() => _out.writeln(usage);
}

/// Спільна основа команд: доступ до виводу та до файлу розкладу.
abstract class ScheduleCommand extends Command<int> {
  /// Створює команду зі стандартним виводом [out] і потоком помилок [err].
  ScheduleCommand(this.out, this.err);

  /// Звичайний вивід.
  final StringSink out;

  /// Повідомлення про помилки.
  final StringSink err;

  /// Сховище, налаштоване глобальними опціями `--data-dir` і `--file`.
  LessonFileStorage get storage {
    final global = globalResults;
    return LessonFileStorage(
      directory: global?['data-dir'] as String? ?? defaultDataDirectory,
      fileName: global?['file'] as String? ?? defaultScheduleFileName,
    );
  }

  @override
  void printUsage() => out.writeln(usage);
}

/// Команда `import`: читає CSV-файл і зберігає заняття у JSON-сховище.
class ImportCommand extends ScheduleCommand {
  /// Створює команду імпорту.
  ImportCommand(super.out, super.err) {
    argParser.addOption(
      'separator',
      abbr: 's',
      defaultsTo: defaultSeparator,
      help: 'Роздільник полів у рядках CSV.',
    );
  }

  @override
  String get name => 'import';

  @override
  String get description =>
      'Імпортує заняття з CSV-файлу в JSON-сховище (замінює його вміст).';

  @override
  String get invocation => '$cliName import [параметри] <файл.csv>';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.length != 1) usageException('Вкажіть рівно один CSV-файл.');

    final result = await readLessonsFromCsv(
      rest.first,
      separator: argResults?['separator'] as String? ?? defaultSeparator,
    );
    for (final problem in result.problems) {
      err.writeln('Пропущено, $problem');
    }
    await storage.save(result.lessons);
    out.writeln(
      'Імпортовано занять: ${result.lessons.length}, '
      'пропущено: ${result.problems.length}. Файл: ${storage.path}',
    );
    return exitOk;
  }
}

/// Команда `report`: друкує звіт про розклад зі збереженого файлу.
class ReportCommand extends ScheduleCommand {
  /// Створює команду звіту.
  ReportCommand(super.out, super.err) {
    argParser
      ..addOption(
        'top',
        abbr: 't',
        defaultsTo: '$defaultTopCount',
        help: 'Скільки викладачів показати в рейтингу.',
      )
      ..addFlag(
        'descending',
        negatable: false,
        help: 'Сортувати заняття за спаданням.',
      )
      ..addFlag(
        'mask-teachers',
        negatable: false,
        help: 'Маскувати прізвища викладачів.',
      );
  }

  @override
  String get name => 'report';

  @override
  String get description => 'Друкує звіт про розклад зі збереженого файлу.';

  @override
  Future<int> run() async {
    final top = int.tryParse(argResults?['top'] as String? ?? '');
    if (top == null || top < 1) {
      usageException('--top має бути додатним цілим числом.');
    }

    final lessons = await storage.load();
    if (lessons.isEmpty) {
      err.writeln('Розклад порожній: спершу виконайте команду import.');
      return exitDataError;
    }
    out.write(
      buildReport(
        lessons,
        topCount: top,
        descending: argResults?['descending'] as bool? ?? false,
        maskTeachers: argResults?['mask-teachers'] as bool? ?? false,
      ),
    );
    return exitOk;
  }
}

/// Команда `holidays`: завантажує державні свята із сервісу Nager.Date.
class HolidaysCommand extends ScheduleCommand {
  /// Створює команду; [httpClient] підміняють у тестах.
  HolidaysCommand(super.out, super.err, this._httpClient) {
    argParser
      ..addOption(
        'year',
        abbr: 'y',
        defaultsTo: '${DateTime.now().year}',
        help: 'Рік, за який потрібні свята.',
      )
      ..addOption(
        'country',
        abbr: 'c',
        defaultsTo: defaultCountryCode,
        help: 'Код країни (ISO 3166-1 alpha-2).',
      )
      ..addFlag(
        'check',
        negatable: false,
        help: 'Показати, скільки занять розкладу припадає на день свята.',
      );
  }

  final http.Client? _httpClient;

  @override
  String get name => 'holidays';

  @override
  String get description => 'Завантажує державні свята із сервісу Nager.Date.';

  @override
  Future<int> run() async {
    final year = int.tryParse(argResults?['year'] as String? ?? '');
    if (year == null || year < 1) {
      usageException('--year має бути додатним цілим числом.');
    }
    final country = (argResults?['country'] as String? ?? defaultCountryCode)
        .toUpperCase();
    final check = argResults?['check'] as bool? ?? false;

    final client = HolidayClient(client: _httpClient);
    final List<Holiday> holidays;
    try {
      holidays = await client.fetch(year, countryCode: country);
    } finally {
      client.close();
    }
    if (holidays.isEmpty) {
      err.writeln('Для $country за $year свят не знайдено.');
      return exitDataError;
    }

    final lessons = check ? await storage.load() : const <Lesson>[];
    if (check && lessons.isEmpty) {
      err.writeln('Розклад порожній: спершу виконайте команду import.');
    }
    for (final holiday in holidays) {
      final line = StringBuffer(
        '$holiday (${weekdayName(holiday.date.weekday)})',
      );
      if (check) {
        final affected = lessons
            .where(
              (lesson) =>
                  lesson.weekday == holiday.date.weekday &&
                  !lesson.firstDate.isAfter(holiday.date),
            )
            .length;
        line.write(': занять у цей день тижня — $affected');
      }
      out.writeln(line);
    }
    return exitOk;
  }
}
