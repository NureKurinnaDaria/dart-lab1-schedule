import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lab4_schedule/lab4_schedule.dart';
import 'package:test/test.dart';

const sample =
    '[{"date":"2026-08-24","localName":"День Незалежності України",'
    '"name":"Independence Day","countryCode":"UA","global":true}]';

HolidayClient clientWith(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = holidayRequestTimeout,
}) => HolidayClient(client: MockClient(handler), timeout: timeout);

http.Response json(String body, [int status = 200]) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('HolidayClient', () {
    test('розбирає відповідь і звертається за правильною адресою', () async {
      Uri? requested;
      final client = clientWith((request) async {
        requested = request.url;
        return json(sample);
      });

      final holidays = await client.fetch(2026);

      expect(
        requested.toString(),
        'https://date.nager.at/api/v3/PublicHolidays/2026/UA',
      );
      expect(holidays.single.date, DateTime(2026, 8, 24));
      expect(holidays.single.name, 'Independence Day');
    });

    test('декодує українські назви як UTF-8 без charset', () async {
      final client = clientWith((_) async => json(sample));

      final holidays = await client.fetch(2026);

      expect(holidays.single.localName, 'День Незалежності України');
    });

    test('статус 204 дає порожній список', () async {
      final client = clientWith((_) async => http.Response('', 204));

      expect(await client.fetch(2026), isEmpty);
    });

    for (final status in [404, 500]) {
      test('статус $status дає HolidayStatusException', () async {
        final client = clientWith((_) async => http.Response('', status));

        await expectLater(
          client.fetch(2026),
          throwsA(
            isA<HolidayStatusException>().having(
              (error) => error.statusCode,
              'statusCode',
              status,
            ),
          ),
        );
      });
    }

    test('тіло, що не є JSON, дає HolidayFormatException', () async {
      final client = clientWith((_) async => json('це не JSON'));

      await expectLater(
        client.fetch(2026),
        throwsA(isA<HolidayFormatException>()),
      );
    });

    test('JSON не у вигляді масиву дає HolidayFormatException', () async {
      final client = clientWith((_) async => json('{"date":"2026-08-24"}'));

      await expectLater(
        client.fetch(2026),
        throwsA(isA<HolidayFormatException>()),
      );
    });

    test('елемент без обов’язкового поля дає HolidayFormatException', () async {
      final client = clientWith((_) async => json('[{"date":"2026-08-24"}]'));

      await expectLater(
        client.fetch(2026),
        throwsA(isA<HolidayFormatException>()),
      );
    });

    test('відсутність з’єднання дає HolidayNetworkException', () async {
      final client = clientWith(
        (_) async => throw const SocketException('немає мережі'),
      );

      await expectLater(
        client.fetch(2026),
        throwsA(isA<HolidayNetworkException>()),
      );
    });

    test('перевищення часу очікування дає HolidayNetworkException', () async {
      final client = clientWith((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return json('[]');
      }, timeout: const Duration(milliseconds: 20));

      await expectLater(
        client.fetch(2026),
        throwsA(isA<HolidayNetworkException>()),
      );
    });
  });
}
