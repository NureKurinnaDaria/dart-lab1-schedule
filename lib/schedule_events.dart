import 'dart:async';

import 'lesson.dart';

/// Подія змін у розкладі.
sealed class ScheduleEvent {
  const ScheduleEvent();
}

/// Заняття додано до розкладу.
class LessonAdded extends ScheduleEvent {
  const LessonAdded(this.lesson);

  /// Додане заняття.
  final Lesson lesson;

  @override
  String toString() => 'додано: $lesson';
}

/// Заняття видалено з розкладу.
class LessonRemoved extends ScheduleEvent {
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

  /// Завершує потік.
  Future<void> close() => _controller.close();
}
