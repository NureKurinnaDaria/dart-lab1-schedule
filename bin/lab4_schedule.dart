import 'dart:io';

import 'package:lab4_schedule/lab4_schedule.dart';

void main(List<String> arguments) {
  stdout.writeln(Lesson.fromCsv(rawLessons.first));
}
