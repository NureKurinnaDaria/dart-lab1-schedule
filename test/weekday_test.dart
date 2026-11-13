import 'package:lab4_schedule/lab4_schedule.dart';
import 'package:test/test.dart';

void main() {
  group('weekdayName', () {
    test('повертає назву дня за номером', () {
      expect(weekdayName(DateTime.monday), 'Понеділок');
      expect(weekdayName(DateTime.sunday), 'Неділя');
    });

    test('збігається з Weekday для всіх днів тижня', () {
      for (final day in Weekday.values) {
        expect(weekdayName(day.number), day.label);
      }
    });

    test('для номера поза діапазоном повертає знак питання', () {
      expect(weekdayName(0), '?');
      expect(weekdayName(8), '?');
    });
  });
}
