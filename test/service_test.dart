import 'dart:convert';
import 'dart:io';

import 'package:lab4_schedule/lab4_schedule.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

final lessons = [for (final line in rawLessons.take(4)) Lesson.fromCsv(line)];

Future<LessonFileStorage> makeStorage() async {
  final dir = await Directory.systemTemp.createTemp('lab4_service_');
  addTearDown(() => dir.delete(recursive: true));
  return LessonFileStorage(directory: dir.path);
}

Future<Handler> makeHandler({List<String>? logs}) async {
  final service = ScheduleService(await makeStorage(), initial: lessons);
  return buildHandler(service, log: logs?.add);
}

Future<Response> send(
  Handler handler,
  String method,
  String path, {
  Object? body,
}) async {
  final payload = body is String
      ? body
      : (body == null ? null : jsonEncode(body));
  return handler(
    Request(method, Uri.parse('http://localhost$path'), body: payload),
  );
}

Future<Object?> readJson(Response response) async =>
    jsonDecode(await response.readAsString());

final newLesson = Lesson.fromCsv(rawLessons[7]).toJson();

void main() {
  group('GET /items', () {
    test('повертає всі заняття з номерами', () async {
      final handler = await makeHandler();

      final response = await send(handler, 'GET', '/items');
      final items = await readJson(response) as List<Object?>;

      expect(response.statusCode, 200);
      expect(items, hasLength(4));
      expect((items.first as Map<String, Object?>)['id'], 1);
    });

    test('фільтрує за днем тижня', () async {
      final handler = await makeHandler();

      final response = await send(handler, 'GET', '/items?weekday=2');
      final items = await readJson(response) as List<Object?>;

      expect(items, hasLength(2));
      expect(
        items.every((item) => (item as Map<String, Object?>)['weekday'] == 2),
        isTrue,
      );
    });

    test('фільтрує за викладачем без урахування регістру', () async {
      final handler = await makeHandler();

      final response = await send(handler, 'GET', '/items?teacher=демчук');
      final items = await readJson(response) as List<Object?>;

      expect(items, hasLength(1));
    });

    test('некоректний weekday дає 400', () async {
      final handler = await makeHandler();

      final response = await send(handler, 'GET', '/items?weekday=9');

      expect(response.statusCode, 400);
    });

    test(
      'відповідь має content-type з UTF-8 і кирилицю без екранування',
      () async {
        final handler = await makeHandler();

        final response = await send(handler, 'GET', '/items');

        expect(
          response.headers['content-type'],
          'application/json; charset=utf-8',
        );
        expect(
          await response.readAsString(),
          contains('Якість ПЗ та тестування'),
        );
      },
    );
  });

  group('GET /items/<id>', () {
    test('повертає заняття за номером', () async {
      final handler = await makeHandler();

      final response = await send(handler, 'GET', '/items/1');
      final item = await readJson(response) as Map<String, Object?>;

      expect(response.statusCode, 200);
      expect(item['subject'], 'Якість ПЗ та тестування');
    });

    test('відсутній або нечисловий id дає 404', () async {
      final handler = await makeHandler();

      expect((await send(handler, 'GET', '/items/99')).statusCode, 404);
      expect((await send(handler, 'GET', '/items/abc')).statusCode, 404);
    });
  });

  group('POST /items', () {
    test('створює заняття, повертає 201 і Location', () async {
      final handler = await makeHandler();

      final response = await send(handler, 'POST', '/items', body: newLesson);
      final list = await send(handler, 'GET', '/items');

      expect(response.statusCode, 201);
      expect(response.headers['location'], '/items/5');
      expect(await readJson(list), hasLength(5));
    });

    test('зберігає розклад у файл', () async {
      final storage = await makeStorage();
      final handler = buildHandler(ScheduleService(storage));

      await send(handler, 'POST', '/items', body: newLesson);

      expect(await storage.load(), hasLength(1));
    });

    test('тіло, що не є JSON, дає 400', () async {
      final handler = await makeHandler();

      final response = await send(handler, 'POST', '/items', body: 'не JSON');

      expect(response.statusCode, 400);
    });

    test('об’єкт без обов’язкових полів дає 400', () async {
      final handler = await makeHandler();

      final response = await send(
        handler,
        'POST',
        '/items',
        body: {'type': 'практика'},
      );

      expect(response.statusCode, 400);
    });

    test('дублікат дає 409', () async {
      final handler = await makeHandler();

      final response = await send(
        handler,
        'POST',
        '/items',
        body: lessons.first.toJson(),
      );

      expect(response.statusCode, 409);
    });
  });

  group('загальна поведінка', () {
    test('невідомий маршрут дає 404 у форматі JSON', () async {
      final handler = await makeHandler();

      final response = await send(handler, 'GET', '/unknown');

      expect(response.statusCode, 404);
      expect(await readJson(response), {'error': 'Маршрут не знайдено'});
    });

    test('middleware журналює запит зі статусом', () async {
      final logs = <String>[];
      final handler = await makeHandler(logs: logs);

      await send(handler, 'GET', '/items?weekday=2');

      expect(logs.single, contains('GET /items?weekday=2 → 200'));
    });
  });
}
