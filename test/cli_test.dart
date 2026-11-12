import 'dart:io';

import 'package:lab4_schedule/lab4_schedule.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

typedef CliResult = ({int code, String out, String err});

Future<CliResult> run(List<String> arguments) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(arguments, out: out, err: err);
  return (code: code, out: out.toString(), err: err.toString());
}

Future<Directory> makeTempDir() async {
  final dir = await Directory.systemTemp.createTemp('lab4_cli_');
  addTearDown(() => dir.delete(recursive: true));
  return dir;
}

Future<String> writeCsv(Directory dir, List<String> lines) async {
  final path = p.join(dir.path, 'lessons.csv');
  await File(path).writeAsString(lines.join('\n'));
  return path;
}

void main() {
  group('runCli', () {
    test('--help друкує довідку з усіма командами', () async {
      final result = await run(['--help']);

      expect(result.code, exitOk);
      expect(result.out, contains('import'));
      expect(result.out, contains('report'));
    });

    test('невідома команда дає код exitUsage і текст у stderr', () async {
      final result = await run(['unknown']);

      expect(result.code, exitUsage);
      expect(result.err, contains('unknown'));
    });

    test('import зберігає заняття, а report друкує їх', () async {
      final dir = await makeTempDir();
      final csv = await writeCsv(dir, rawLessons.take(3).toList());

      final imported = await run(['--data-dir', dir.path, 'import', csv]);
      final report = await run(['--data-dir', dir.path, 'report']);

      expect(imported.code, exitOk);
      expect(imported.out, contains('Імпортовано занять: 3'));
      expect(report.code, exitOk);
      expect(report.out, contains('РОЗКЛАД (занять: 3)'));
    });

    test(
      'import пропускає некоректний рядок і пише про нього в stderr',
      () async {
        final dir = await makeTempDir();
        final csv = await writeCsv(dir, [
          rawLessons.first,
          'пошкоджений рядок',
        ]);

        final result = await run(['--data-dir', dir.path, 'import', csv]);

        expect(result.code, exitOk);
        expect(result.err, contains('Пропущено, рядок 2'));
        expect(result.out, contains('пропущено: 1'));
      },
    );

    test('import відсутнього файлу дає код exitIoError', () async {
      final dir = await makeTempDir();

      final result = await run([
        '--data-dir',
        dir.path,
        'import',
        p.join(dir.path, 'no_such.csv'),
      ]);

      expect(result.code, exitIoError);
      expect(result.err, contains('Помилка файлу'));
    });

    test('report без імпортованих даних дає код exitDataError', () async {
      final dir = await makeTempDir();

      final result = await run(['--data-dir', dir.path, 'report']);

      expect(result.code, exitDataError);
      expect(result.err, contains('import'));
    });

    test('report --top 0 дає код exitUsage', () async {
      final dir = await makeTempDir();

      final result = await run([
        '--data-dir',
        dir.path,
        'report',
        '--top',
        '0',
      ]);

      expect(result.code, exitUsage);
    });

    test('report --mask-teachers ховає прізвища', () async {
      final dir = await makeTempDir();
      final csv = await writeCsv(dir, [rawLessons.first]);
      await run(['--data-dir', dir.path, 'import', csv]);

      final result = await run([
        '--data-dir',
        dir.path,
        'report',
        '--mask-teachers',
      ]);

      expect(result.code, exitOk);
      expect(result.out, isNot(contains('Демчук')));
    });
  });
}
