import 'dart:async';

import 'lesson.dart';

/// Подія змін у розкладі.
sealed class ScheduleEvent {
  const ScheduleEvent();
}

/// Заняття додано до розкладу.
class LessonAdded extends ScheduleEvent {
  /// Створює подію про додане заняття [lesson].
  const LessonAdded(this.lesson);

  /// Додане заняття.
  final Lesson lesson;

  @override
  String toString() => 'додано: $lesson';
}

/// Заняття видалено з розкладу.
class LessonRemoved extends ScheduleEvent {
  /// Створює подію про видалене заняття [lesson].
  const LessonRemoved(this.lesson);

  /// Видалене заняття.
  final Lesson lesson;

  @override
  String toString() => 'видалено: $lesson';
}

/// Джерело подій розкладу на основі `StreamController`.
class ScheduleEventSource {
  final StreamController<ScheduleEvent> _controller =
      StreamController<ScheduleEvent>();

  /// Потік подій; дозволяє лише одну підписку.
  Stream<ScheduleEvent> get events => _controller.stream;

  /// Додає подію до потоку.
  void add(ScheduleEvent event) => _controller.add(event);

  /// Передає в потік помилку [error]; споживач отримає її після значень,
  /// які були додані раніше.
  void addError(Object error) => _controller.addError(error);

  /// Завершує потік.
  Future<void> close() => _controller.close();
}

/// Будує конвеєр над подіями: лишає [LessonAdded], перетворює їх на рядки
/// й обрізає потік після [count] елементів.
Stream<String> addedLabels(Stream<ScheduleEvent> events, {required int count}) {
  return events
      .where((event) => event is LessonAdded)
      .cast<LessonAdded>()
      .map((event) => 'нове заняття: ${event.lesson}')
      .take(count);
}
