class ColorMapping {
  final String id;
  final String colorHex;
  final String workType;

  const ColorMapping({
    required this.id,
    required this.colorHex,
    required this.workType,
  });

  factory ColorMapping.fromMap(Map<String, dynamic> map) => ColorMapping(
        id: map['id'] as String,
        colorHex: map['color_hex'] as String,
        workType: map['work_type'] as String,
      );

  Map<String, dynamic> toMap() => {
        'color_hex': colorHex,
        'work_type': workType,
      };
}
