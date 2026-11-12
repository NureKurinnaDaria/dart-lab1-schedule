import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lab4_schedule/lab4_schedule.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const sample =
    '[{"date":"2026-10-01","localName":"День захисників і захисниць України",'
    '"name":"Defenders Day"}]';

typedef CliResult = ({int code, String out, String err});

Future<CliResult> run(List<String> arguments, http.Client client) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(arguments, out: out, err: err, httpClient: client);
  return (code: code, out: out.toString(), err: err.toString());
}

MockClient answering(String body, [int status = 200]) => MockClient(
  (_) async => http.Response.bytes(
    utf8.encode(body),
    status,
    headers: {'content-type': 'application/json'},
  ),
);

void main() {
  group('команда holidays', () {
    test('друкує свята з днем тижня', () async {
      final result = await run([
        'holidays',
        '--year',
        '2026',
      ], answering(sample));

      expect(result.code, exitOk);
      expect(
        result.out,
        contains('2026-10-01 День захисників і захисниць України (Четвер)'),
      );
    });

    test('--check враховує дату першого заняття', () async {
      final dir = await Directory.systemTemp.createTemp('lab4_holidays_');
      addTearDown(() => dir.delete(recursive: true));
      final csv = File(p.join(dir.path, 'lessons.csv'));
      // Три заняття в четвер: перші два почалися до 1 жовтня, третє після.
      await csv.writeAsString(
        [rawLessons[9], rawLessons[10], rawLessons[11]].join('\n'),
      );
      await run(['--data-dir', dir.path, 'import', csv.path], answering('[]'));

      final result = await run([
        '--data-dir',
        dir.path,
        'holidays',
        '--year',
        '2026',
        '--check',
      ], answering(sample));

      expect(result.code, exitOk);
      expect(result.out, contains('(Четвер): занять у цей день тижня — 2'));
    });

    test('відсутність мережі дає код exitUnavailable', () async {
      final client = MockClient(
        (_) async => throw const SocketException('немає мережі'),
      );

      final result = await run(['holidays'], client);

      expect(result.code, exitUnavailable);
      expect(result.err, contains('Не вдалося отримати свята'));
    });

    test('статус 500 дає код exitUnavailable', () async {
      final result = await run(['holidays'], answering('', 500));

      expect(result.code, exitUnavailable);
      expect(result.err, contains('500'));
    });

    test('некоректна відповідь дає код exitDataError', () async {
      final result = await run(['holidays'], answering('це не JSON'));

      expect(result.code, exitDataError);
    });

    test('--year не число дає код exitUsage', () async {
      final result = await run([
        'holidays',
        '--year',
        'abc',
      ], answering(sample));

      expect(result.code, exitUsage);
    });
  });
}
