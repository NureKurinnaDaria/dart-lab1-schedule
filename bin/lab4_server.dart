import 'dart:io';

import 'package:lab4_schedule/lab4_schedule.dart';

Future<void> main() async {
  final port =
      int.tryParse(Platform.environment['PORT'] ?? '') ?? defaultServicePort;
  final service = await ScheduleService.open(LessonFileStorage());
  final server = await serveSchedule(service, port: port, log: stdout.writeln);
  stdout.writeln('Сервіс слухає http://localhost:${server.port}');
}
