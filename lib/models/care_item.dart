class CareItem {
  final String id;
  final String title;
  final String instruction;
  final int dosage;
  final int? duration;

  CareItem({
    required this.id,
    required this.title,
    required this.instruction,
    required this.dosage,
    this.duration,
  });

  factory CareItem.fromMap(Map<String, dynamic> map, String id) {
    return CareItem(
      id: id,
      title: map['title'] ?? '',
      instruction: map['instruction'] ?? '',
      dosage: _parseInt(map['dosage']),
      duration: _parseNullableInt(map['duration']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'instruction': instruction,
    'dosage': dosage,
    'duration': duration,
  };
}
