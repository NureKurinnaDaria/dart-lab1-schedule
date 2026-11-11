import 'package:lab4_schedule/lab4_schedule.dart';
import 'package:test/test.dart';

void main() {
  final lesson = Lesson.fromCsv(rawLessons.first);

  group('Lesson JSON', () {
    test('toJson і fromJson повертають рівне заняття', () {
      expect(Lesson.fromJson(lesson.toJson()), lesson);
    });

    test('fromJson кидає FormatException для невідомого типу', () {
      final json = lesson.toJson()..['type'] = 'семінар';
      expect(() => Lesson.fromJson(json), throwsFormatException);
    });

    test('fromJson кидає FormatException, якщо поле має неправильний тип', () {
      final json = lesson.toJson()..['weekday'] = 'понеділок';
      expect(() => Lesson.fromJson(json), throwsFormatException);
    });

    test('fromJson кидає FormatException, якщо поле відсутнє', () {
      final json = lesson.toJson()..remove('room');
      expect(() => Lesson.fromJson(json), throwsFormatException);
    });
  });
}
