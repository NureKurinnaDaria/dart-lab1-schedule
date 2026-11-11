import 'package:lab4_schedule/lab4_schedule.dart';
import 'package:test/test.dart';

void main() {
  final lesson = Lesson.fromCsv(rawLessons.first);
  var source = ScheduleEventSource();

  setUp(() {
    source = ScheduleEventSource();
  });

  group('ScheduleEventSource', () {
    test('події приходять у порядку додавання', () async {
      final expectation = expectLater(
        source.events,
        emitsInOrder([isA<LessonAdded>(), isA<LessonRemoved>(), emitsDone]),
      );
      source
        ..add(LessonAdded(lesson))
        ..add(LessonRemoved(lesson));
      await source.close();
      await expectation;
    });

    test('події, додані до підписки, не губляться', () async {
      source
        ..add(LessonAdded(lesson))
        ..add(LessonAdded(lesson));
      final closed = source.close();
      expect(await source.events.length, 2);
      await closed;
    });
  });

  group('addedLabels', () {
    test('відкидає LessonRemoved і обрізає потік за take', () async {
      source
        ..add(LessonAdded(lesson))
        ..add(LessonRemoved(lesson))
        ..add(LessonAdded(lesson))
        ..add(LessonAdded(lesson));
      final labels = await addedLabels(source.events, count: 2).toList();
      expect(labels, hasLength(2));
      expect(labels, everyElement(startsWith('нове заняття')));
    });

    test('помилка джерела проходить крізь конвеєр після значень', () async {
      final expectation = expectLater(
        addedLabels(source.events, count: 5),
        emitsInOrder([
          startsWith('нове заняття'),
          emitsError(isA<StateError>()),
        ]),
      );
      source
        ..add(LessonAdded(lesson))
        ..addError(StateError('збій джерела'));
      await expectation;
    });
  });
}
