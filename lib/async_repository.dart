import 'lesson.dart';

/// Затримка завантаження сутності з імітованого джерела даних.
const loadDelay = Duration(milliseconds: 300);

/// Затримка збереження сутності в імітованому джерелі даних.
const saveDelay = Duration(milliseconds: 200);

/// Затримка видалення сутності з імітованого джерела даних.
const deleteDelay = Duration(milliseconds: 200);

/// Асинхронне сховище сутностей предметної області.
class AsyncRepository<T extends Identifiable> {
  final Map<String, T> _items = {};

  /// Кількість збережених елементів.
  int get length => _items.length;

  /// Повертає сутність за ідентифікатором [id] або `null`.
  Future<T?> load(String id) async {
    await Future<void>.delayed(loadDelay);
    return _items[id];
  }

  /// Зберігає [item]; елемент із таким самим ідентифікатором замінюється.
  Future<void> save(T item) async {
    await Future<void>.delayed(saveDelay);
    _items[item.id] = item;
  }

  /// Видаляє елемент за [id]; повертає `true`, якщо він існував.
  Future<bool> delete(String id) async {
    await Future<void>.delayed(deleteDelay);
    return _items.remove(id) != null;
  }
}
