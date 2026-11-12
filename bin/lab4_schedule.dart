import 'dart:io';

import 'package:lab4_schedule/lab4_schedule.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments, out: stdout, err: stderr);
}
