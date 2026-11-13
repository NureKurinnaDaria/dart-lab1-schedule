import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'lesson.dart';
import 'lesson_storage.dart';

/// Порт сервісу за замовчуванням.
const defaultServicePort = 8080;

/// Заняття з номером, під яким його віддає сервіс.
typedef NumberedLesson = ({int number, Lesson lesson});

/// Розклад у пам'яті з записом на диск після кожного додавання.
class ScheduleService {
  /// Створює сервіс із початковими заняттями [initial].
  ScheduleService(this._storage, {List<Lesson> initial = const []})
    : _lessons = [...initial];

  /// Створює сервіс і завантажує заняття зі сховища [storage].
  static Future<ScheduleService> open(LessonFileStorage storage) async =>
      ScheduleService(storage, initial: await storage.load());

  final LessonFileStorage _storage;
  final List<Lesson> _lessons;
  Future<void> _pending = Future<void>.value();

  /// Заняття, що відповідають фільтрам; порожній фільтр не обмежує вибірку.
  ///
  /// [teacher] шукається як підрядок без урахування регістру.
  List<NumberedLesson> list({int? weekday, String? type, String? teacher}) {
    final needle = teacher?.toLowerCase();
    return [
      for (var i = 0; i < _lessons.length; i++)
        if ((weekday == null || _lessons[i].weekday == weekday) &&
            (type == null || _lessons[i].type == type) &&
            (needle == null ||
                _lessons[i].teacher.toLowerCase().contains(needle)))
          (number: i + 1, lesson: _lessons[i]),
    ];
  }

  /// Заняття за номером або `null`, якщо такого запису немає.
  Lesson? byNumber(int number) =>
      number >= 1 && number <= _lessons.length ? _lessons[number - 1] : null;

  /// Додає [lesson] і зберігає розклад; повертає номер нового запису
  /// або `null`, якщо таке заняття вже є.
  Future<int?> add(Lesson lesson) {
    if (_lessons.any((existing) => existing.id == lesson.id)) {
      return Future<int?>.value();
    }
    _lessons.add(lesson);
    final number = _lessons.length;
    return _exclusive(() async {
      await _storage.save(List.of(_lessons));
      return number;
    });
  }

  /// Виконує [action] після завершення попередніх записів.
  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

/// Проміжний обробник, який передає в [log] рядок про кожен запит:
/// метод, адресу, статус відповіді та тривалість.
Middleware requestLogger(void Function(String message) log) =>
    (Handler inner) => (Request request) async {
      final stopwatch = Stopwatch()..start();
      final label = '${request.method} /${request.url}';
      try {
        final response = await inner(request);
        log(
          '$label → ${response.statusCode} '
          '(${stopwatch.elapsedMilliseconds} мс)',
        );
        return response;
      } catch (error) {
        log('$label → помилка: $error');
        rethrow;
      }
    };

/// Будує обробник HTTP-запитів до [service].
///
/// Маршрути: `GET /items`, `GET /items/<id>`, `POST /items`.
/// Рядки журналу запитів передаються в [log], якщо його вказано.
Handler buildHandler(
  ScheduleService service, {
  void Function(String message)? log,
}) {
  final router =
      Router(notFoundHandler: (_) => _error(404, 'Маршрут не знайдено'))
        ..get('/items', (Request request) => _list(service, request))
        ..get('/items/<id>', (Request request, String id) => _get(service, id))
        ..post('/items', (Request request) => _create(service, request));

  return const Pipeline()
      .addMiddleware(requestLogger(log ?? (_) {}))
      .addHandler(router.call);
}

/// Запускає сервіс на локальній адресі й порту [port].
Future<HttpServer> serveSchedule(
  ScheduleService service, {
  int port = defaultServicePort,
  void Function(String message)? log,
}) => shelf_io.serve(
  buildHandler(service, log: log),
  InternetAddress.loopbackIPv4,
  port,
);

Response _list(ScheduleService service, Request request) {
  final query = request.url.queryParameters;
  int? weekday;
  final rawWeekday = query['weekday'];
  if (rawWeekday != null) {
    weekday = int.tryParse(rawWeekday);
    if (weekday == null || weekday < 1 || weekday > 7) {
      return _error(400, 'weekday має бути числом від 1 до 7');
    }
  }
  final items = service.list(
    weekday: weekday,
    type: query['type'],
    teacher: query['teacher'],
  );
  return _json([for (final item in items) _toJson(item)]);
}

Response _get(ScheduleService service, String id) {
  final number = int.tryParse(id);
  final lesson = number == null ? null : service.byNumber(number);
  if (number == null || lesson == null) {
    return _error(404, 'Заняття $id не знайдено');
  }
  return _json(_toJson((number: number, lesson: lesson)));
}

Future<Response> _create(ScheduleService service, Request request) async {
  final Lesson lesson;
  try {
    final Object? body = jsonDecode(await request.readAsString());
    if (body is! Map<String, Object?>) {
      return _error(400, 'Тіло запиту має бути JSON-об’єктом');
    }
    lesson = Lesson.fromJson(body);
  } on FormatException catch (error) {
    return _error(400, 'Некоректне тіло запиту: ${error.message}');
  }

  final problems = validateLesson(lesson);
  if (problems.isNotEmpty) return _error(400, problems.join('; '));

  final number = await service.add(lesson);
  if (number == null) return _error(409, 'Таке заняття вже є в розкладі');
  return _json(
    _toJson((number: number, lesson: lesson)),
    status: 201,
    headers: {'location': '/items/$number'},
  );
}

Map<String, Object?> _toJson(NumberedLesson item) => {
  'id': item.number,
  ...item.lesson.toJson(),
};

Response _json(
  Object? body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8', ...headers},
);

Response _error(int status, String message) =>
    _json({'error': message}, status: status);
