import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'holiday.dart';

/// Хост сервісу державних свят.
const holidayApiHost = 'date.nager.at';

/// Код країни за замовчуванням (ISO 3166-1 alpha-2).
const defaultCountryCode = 'UA';

/// Скільки чекати відповідь сервісу.
const holidayRequestTimeout = Duration(seconds: 10);

/// Помилка отримання свят; підтип показує, на якому рівні сталася відмова.
sealed class HolidayException implements Exception {
  /// Створює помилку з текстом [message].
  const HolidayException(this.message);

  /// Опис помилки для користувача.
  final String message;

  @override
  String toString() => message;
}

/// Немає з'єднання або сервіс не відповів вчасно.
final class HolidayNetworkException extends HolidayException {
  /// Створює мережеву помилку.
  const HolidayNetworkException(super.message);
}

/// Сервіс відповів статусом, відмінним від 2xx.
final class HolidayStatusException extends HolidayException {
  /// Створює помилку статусу [statusCode].
  const HolidayStatusException(this.statusCode)
    : super('Сервіс відповів статусом $statusCode');

  /// HTTP-статус відповіді.
  final int statusCode;
}

/// Тіло відповіді не є очікуваним JSON.
final class HolidayFormatException extends HolidayException {
  /// Створює помилку формату відповіді.
  const HolidayFormatException(super.message);
}

/// Отримує державні свята із сервісу Nager.Date.
class HolidayClient {
  /// Створює клієнт; у тестах сюди передають `MockClient`.
  HolidayClient({http.Client? client, this.timeout = holidayRequestTimeout})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  /// Максимальний час очікування відповіді.
  final Duration timeout;

  /// Адреса запиту свят за [year] для країни [countryCode].
  Uri holidaysUri(int year, String countryCode) =>
      Uri.https(holidayApiHost, '/api/v3/PublicHolidays/$year/$countryCode');

  /// Повертає свята за [year] для країни [countryCode].
  ///
  /// Викидає [HolidayNetworkException], [HolidayStatusException] або
  /// [HolidayFormatException]. Статус 204 (даних немає) дає порожній список.
  Future<List<Holiday>> fetch(
    int year, {
    String countryCode = defaultCountryCode,
  }) async {
    final response = await _get(holidaysUri(year, countryCode));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HolidayStatusException(response.statusCode);
    }
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) return [];

    final holidays = <Holiday>[];
    try {
      // Сервіс може не вказати charset, тому тіло декодується як UTF-8
      // вручну, а не через response.body.
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List<Object?>) {
        throw const FormatException('очікувався масив свят');
      }
      for (final item in decoded) {
        if (item is! Map<String, Object?>) {
          throw FormatException('елемент масиву не є об’єктом', item);
        }
        holidays.add(Holiday.fromJson(item));
      }
    } on FormatException catch (error) {
      throw HolidayFormatException(
        'Некоректна відповідь сервісу: ${error.message}',
      );
    }
    return holidays;
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const HolidayNetworkException('Сервіс не відповів вчасно');
    } on SocketException catch (error) {
      throw HolidayNetworkException('Немає з’єднання: ${error.message}');
    } on http.ClientException catch (error) {
      throw HolidayNetworkException('Помилка з’єднання: ${error.message}');
    }
  }

  /// Закриває клієнт, якщо його створив сам [HolidayClient].
  void close() {
    if (_ownsClient) _client.close();
  }
}
