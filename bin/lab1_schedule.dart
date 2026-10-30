import 'dart:io';

import 'package:lab1_schedule/data.dart';
import 'package:lab1_schedule/lesson.dart';

void main() {
  var accepted = 0;
  for (final (index, line) in rawLessons.indexed) {
    final number = index + 1;
    final result = parseLine(line);
    final lesson = result.lesson;
    if (lesson == null) {
      stdout.writeln('Рядок $number: не розібрано, ${result.error}');
      continue;
    }
    final violations = validateLesson(lesson);
    if (violations.isEmpty) {
      accepted++;
    } else {
      stdout.writeln('Рядок $number: ${violations.join('; ')}');
    }
  }
  stdout.writeln('Коректних записів: $accepted із ${rawLessons.length}');
}
