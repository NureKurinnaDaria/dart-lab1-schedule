import 'package:lab3_schedule/data.dart';
import 'package:lab3_schedule/lesson.dart';
import 'package:test/test.dart';

void main() {
  group('Lesson', () {
    test('fromCsv повертає той самий об’єкт для того самого рядка', () {
      final a = Lesson.fromCsv(rawLessons.first);
      final b = Lesson.fromCsv(rawLessons.first);
      expect(identical(a, b), isTrue);
    });

    test('fromCsv кидає FormatException для некоректного рядка', () {
      expect(() => Lesson.fromCsv('це не заняття'), throwsFormatException);
    });

    test('однакові поля дають рівність і однаковий hashCode', () {
      final a = Lesson.fromCsv(rawLessons.first);
      final b = Lesson.fromCsv(rawLessons.first);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
