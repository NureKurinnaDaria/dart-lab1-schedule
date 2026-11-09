import 'package:lab3_schedule/async_repository.dart';
import 'package:lab3_schedule/data.dart';
import 'package:lab3_schedule/lesson.dart';
import 'package:test/test.dart';

Lecture _lecture(String teacher) => Lecture(
  subject: 'Програмування мовою Dart',
  teacher: teacher,
  weekday: DateTime.thursday,
  startMinutes: 11 * minutesPerHour + 15,
  room: onlineRoom,
  firstDate: DateTime(2026, 9, 3),
);

void main() {
  final first = Lesson.fromCsv(rawLessons[0]);
  final second = Lesson.fromCsv(rawLessons[1]);
  var repository = AsyncRepository<Lesson>();

  setUp(() {
    repository = AsyncRepository<Lesson>();
  });

  group('AsyncRepository', () {
    test('save і load повертають збережене заняття', () async {
      await repository.save(first);
      expect(await repository.load(first.id), first);
    });

    test('load неіснуючого id повертає null', () async {
      expect(await repository.load('немає'), isNull);
    });

    test('delete видаляє заняття, повторне видалення дає false', () async {
      await repository.save(first);
      expect(await repository.delete(first.id), isTrue);
      expect(await repository.delete(first.id), isFalse);
      expect(await repository.load(first.id), isNull);
    });

    test(
      'різні викладачі дають різні id, обидва заняття зберігаються',
      () async {
        final a = _lecture('Баличев М. Д.');
        final b = _lecture('Шевченко О. Л.');
        expect(a.id, isNot(b.id));
        await repository.save(a);
        await repository.save(b);
        expect(repository.length, 2);
      },
    );
  });

  group('watchAll', () {
    test('видає заняття в порядку збереження', () async {
      await repository.save(first);
      await repository.save(second);
      await expectLater(
        repository.watchAll(),
        emitsInOrder([first, second, emitsDone]),
      );
    });
  });
}
