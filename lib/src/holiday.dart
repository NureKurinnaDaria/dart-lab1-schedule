/// Державне свято з відповіді сервісу Nager.Date.
class Holiday {
  /// Створює свято з датою [date] та назвами [localName] і [name].
  const Holiday({
    required this.date,
    required this.localName,
    required this.name,
  });

  /// Створює свято з JSON-об'єкта відповіді.
  ///
  /// Викидає [FormatException], якщо поле відсутнє чи має неправильний тип.
  factory Holiday.fromJson(Map<String, Object?> json) {
    try {
      return Holiday(
        date: DateTime.parse(json['date'] as String),
        localName: json['localName'] as String,
        name: json['name'] as String,
      );
    } on TypeError {
      throw FormatException('поле свята відсутнє або неправильного типу', json);
    }
  }

  /// Дата свята.
  final DateTime date;

  /// Назва мовою країни.
  final String localName;

  /// Загальноприйнята англійська назва.
  final String name;

  @override
  String toString() => '${date.toIso8601String().substring(0, 10)} $localName';
}
