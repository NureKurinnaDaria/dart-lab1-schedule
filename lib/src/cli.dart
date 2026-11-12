import 'dart:io';

import 'package:args/command_runner.dart';

import 'csv_reader.dart';
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

/// Помилка читання чи запису файлу.
const exitIoError = 74;

/// Запускає консольний застосунок і повертає код завершення.
///
/// Звичайний вивід іде в [out], повідомлення про помилки — в [err].
Future<int> runCli(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
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
    ..addCommand(ReportCommand(out, err));

  try {
    return await runner.run(arguments) ?? exitOk;
  } on UsageException catch (error) {
    err
      ..writeln(error.message)
      ..writeln()
      ..writeln(error.usage);
    return exitUsage;
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
