import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:lab3_schedule/analysis.dart';
import 'package:lab3_schedule/async_repository.dart';
import 'package:lab3_schedule/data.dart';
import 'package:lab3_schedule/heavy.dart';
import 'package:lab3_schedule/lesson.dart';
import 'package:lab3_schedule/report.dart';
import 'package:lab3_schedule/schedule_events.dart';

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

/// Глобальний лічильник: кожен ізолят має власну копію.
int globalCounter = 0;

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
  await _uncaughtErrorDemo();
  await _streamGeneratorDemo(lessons);
  await _controllerDemo(lessons);
  await _streamErrorDemo();
  await _singleVsBroadcastDemo();
  await _pipelineDemo(lessons);
  await _isolateDemo();
  await _isolateGlobalDemo();
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

/// Показує, що `try/catch` без `await` не ловить помилку асинхронної операції.
Future<void> _uncaughtErrorDemo() async {
  Future<void> failLater() async {
    await Future<void>.delayed(operationDelay);
    throw Exception('помилка після затримки');
  }

  stdout.writeln('\nБез await:');
  await runZonedGuarded(
    () async {
      try {
        // ignore: unawaited_futures
        failLater();
        stdout.writeln('  try завершився без помилки');
      } on Exception catch (error) {
        stdout.writeln('  catch спіймав: $error');
      }
      await Future<void>.delayed(operationDelay * 2);
    },
    (error, stack) {
      stdout.writeln('  потрапила в зону: $error');
    },
  );

  stdout.writeln('З await:');
  try {
    await failLater();
  } on Exception catch (error) {
    stdout.writeln('  catch спіймав: $error');
  }
}

/// Показує генератор `async*`, його споживання через `await for` і лінивість.
Future<void> _streamGeneratorDemo(List<Lesson> lessons) async {
  final repository = AsyncRepository<Lesson>();
  for (final lesson in lessons.take(3)) {
    await repository.save(lesson);
  }

  stdout.writeln('\nasync* через await for:');
  await for (final lesson in repository.watchAll()) {
    stdout.writeln('  надійшло: $lesson');
  }

  Stream<int> lazyNumbers() async* {
    stdout.writeln('  тіло генератора почало виконуватись');
    yield 1;
  }

  stdout.writeln('Лінивість:');
  final stream = lazyNumbers();
  stdout.writeln('  потік створено, підписки ще немає');
  await Future<void>.delayed(operationDelay);
  stdout.writeln('  підписуємось');
  await for (final value in stream) {
    stdout.writeln('  отримано: $value');
  }
}

/// Показує буферизацію `StreamController` і підписку через `listen`.
Future<void> _controllerDemo(List<Lesson> lessons) async {
  final source = ScheduleEventSource();

  for (final lesson in lessons.take(3)) {
    source.add(LessonAdded(lesson));
  }
  stdout.writeln('\nТри події додано до підписки');

  final received = <ScheduleEvent>[];
  final subscription = source.events.listen(received.add);
  await Future<void>.delayed(Duration.zero);
  stdout.writeln('Після підписки отримано подій: ${received.length}');
  for (final event in received) {
    stdout.writeln('  $event');
  }

  await subscription.cancel();
  source.add(LessonRemoved(lessons.first));
  await Future<void>.delayed(Duration.zero);
  stdout.writeln('Після скасування отримано подій: ${received.length}');
  await source.close();
}

/// Потік, у середині якого виникає помилка: 1, 2, помилка.
Stream<int> _numbersWithError() async* {
  yield 1;
  yield 2;
  throw Exception('помилка посеред потоку');
}

/// Порівнює поведінку `await for` і `listen` з `cancelOnError: false`.
Future<void> _streamErrorDemo() async {
  stdout.writeln('\nawait for:');
  try {
    await for (final value in _numbersWithError()) {
      stdout.writeln('  отримано: $value');
    }
  } on Exception catch (error) {
    stdout.writeln('  потік перервано: $error');
  }

  final controller = StreamController<int>();
  stdout.writeln('listen з cancelOnError: false:');
  final subscription = controller.stream.listen(
    (value) => stdout.writeln('  отримано: $value'),
    onError: (Object error) => stdout.writeln('  помилка: $error'),
    cancelOnError: false,
  );
  controller
    ..add(1)
    ..add(2)
    ..addError(Exception('помилка посеред потоку'))
    ..add(3)
    ..add(4);
  await controller.close();
  await subscription.cancel();
}

/// Показує різницю між потоком одноразової підписки та широкомовним.
Future<void> _singleVsBroadcastDemo() async {
  stdout.writeln('\nОдноразова підписка:');
  final single = StreamController<int>();
  final first = single.stream.listen((value) => stdout.writeln('  1: $value'));
  try {
    // ignore: cancel_subscriptions
    single.stream.listen((value) => stdout.writeln('  2: $value'));
  } on StateError catch (error) {
    stdout.writeln('  друга підписка: $error');
  }
  await first.cancel();
  await single.close();

  stdout.writeln('Широкомовна підписка:');
  final broadcast = StreamController<int>.broadcast();
  final a = broadcast.stream.listen((value) => stdout.writeln('  a: $value'));
  final b = broadcast.stream.listen((value) => stdout.writeln('  b: $value'));
  broadcast.add(1);
  await Future<void>.delayed(Duration.zero);
  await a.cancel();
  await b.cancel();
  await broadcast.close();
}

/// Будує конвеєр над подіями: фільтр, перетворення, обмеження.
Future<void> _pipelineDemo(List<Lesson> lessons) async {
  final source = ScheduleEventSource();
  for (final lesson in lessons.take(5)) {
    source.add(LessonAdded(lesson));
  }
  source.add(LessonRemoved(lessons.first));

  stdout.writeln('\nКонвеєр where → map → take:');
  final labels = source.events
      .where((event) => event is LessonAdded)
      .map(
        (event) => switch (event) {
          LessonAdded(:final lesson) => 'нове заняття: $lesson',
          LessonRemoved(:final lesson) => 'видалено: $lesson',
        },
      )
      .take(3);
  await for (final label in labels) {
    stdout.writeln('  $label');
  }
  await source.close();
}

/// Порівнює важке обчислення в основному ізоляті й в `Isolate.run`.
Future<void> _isolateDemo() async {
  var ticks = 0;
  final timer = Timer.periodic(
    const Duration(milliseconds: 10),
    (_) => ticks++,
  );

  final syncWatch = Stopwatch()..start();
  final syncResult = countConflicts(slotCount);
  syncWatch.stop();
  final ticksDuringSync = ticks;

  ticks = 0;
  final isolateWatch = Stopwatch()..start();
  final isolateResult = await Isolate.run(() => countConflicts(slotCount));
  isolateWatch.stop();
  final ticksDuringIsolate = ticks;
  timer.cancel();

  stdout
    ..writeln(
      '\nОсновний ізолят: ${syncWatch.elapsedMilliseconds} мс, '
      'результат $syncResult, тактів таймера: $ticksDuringSync',
    )
    ..writeln(
      'Isolate.run: ${isolateWatch.elapsedMilliseconds} мс, '
      'результат $isolateResult, тактів таймера: $ticksDuringIsolate',
    );
}

/// Показує, що зміна глобальної змінної в ізоляті не видна в основному.
Future<void> _isolateGlobalDemo() async {
  globalCounter = 1;
  final (before, after) = await Isolate.run(() {
    final before = globalCounter;
    globalCounter = 100;
    return (before, globalCounter);
  });
  stdout
    ..writeln('\nУсередині ізолята: було $before, стало $after')
    ..writeln('В основному ізоляті: $globalCounter');
}
