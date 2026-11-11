/// Кількість слотів розкладу в переборі варіантів.
const slotCount = 20000;

/// Множник першого слота в умові конфлікту.
const firstSlotWeight = 31;

/// Множник другого слота в умові конфлікту.
const secondSlotWeight = 17;

/// Дільник, за яким визначається конфлікт пари слотів.
const conflictModulus = 97;

/// Рахує «конфліктні» пари слотів повним перебором.
///
/// Імітує важке синхронне обчислення: перебір усіх пар слотів розкладу.
int countConflicts(int slots) {
  var conflicts = 0;
  for (var i = 0; i < slots; i++) {
    for (var j = i + 1; j < slots; j++) {
      final weighted = i * firstSlotWeight + j * secondSlotWeight;
      if (weighted % conflictModulus == 0) conflicts++;
    }
  }
  return conflicts;
}
