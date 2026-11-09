import 'package:lab3_schedule/data.dart';
import 'package:lab3_schedule/lesson.dart';
import 'package:lab3_schedule/schedule_events.dart';
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

  group('потік з помилкою', () {
    test('помилка потрапляє до споживача після значень', () async {
      Stream<int> failing() async* {
        yield 1;
        throw StateError('збій');
      }

      await expectLater(
        failing(),
        emitsInOrder([1, emitsError(isA<StateError>())]),
      );
    });
  });
}
