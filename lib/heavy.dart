/// Кількість слотів розкладу в переборі варіантів.
const slotCount = 20000;

/// Рахує «конфліктні» пари слотів повним перебором.
///
/// Імітує важке синхронне обчислення: перебір усіх пар слотів розкладу.
int countConflicts(int slots) {
  var conflicts = 0;
  for (var i = 0; i < slots; i++) {
    for (var j = i + 1; j < slots; j++) {
      if ((i * 31 + j * 17) % 97 == 0) conflicts++;
    }
  }
  return conflicts;
}
