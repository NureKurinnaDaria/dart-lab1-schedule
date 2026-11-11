import 'dart:isolate';

import 'package:lab4_schedule/lab4_schedule.dart';
import 'package:test/test.dart';

void main() {
  group('countConflicts', () {
    test('для 0 і 1 слота конфліктів немає', () {
      expect(countConflicts(0), 0);
      expect(countConflicts(1), 0);
    });

    test('для 98 слотів дає відому кількість пар', () {
      expect(countConflicts(98), 49);
    });

    test('Isolate.run дає той самий результат, що й основний ізолят', () async {
      expect(await Isolate.run(() => countConflicts(200)), countConflicts(200));
    });
  });
}
