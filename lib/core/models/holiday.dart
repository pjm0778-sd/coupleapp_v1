class Holiday {
  final DateTime date;
  final String name;
  final bool isNationwide;

  Holiday({
    required this.date,
    required this.name,
    this.isNationwide = false,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      date: DateTime.parse(json['date'] as String),
      name: json['name'] as String,
      isNationwide: json['is_nationwide'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'name': name,
      'is_nationwide': isNationwide,
    };
  }
}
