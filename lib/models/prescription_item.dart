class PrescriptionItem {
  final String careItemId;
  final String title;
  final String instruction;
  final int dosage;
  final int duration;
  final String? notes;

  PrescriptionItem({
    required this.careItemId,
    required this.title,
    required this.instruction,
    required this.dosage,
    required this.duration,
    this.notes,
  });

  factory PrescriptionItem.fromMap(Map<String, dynamic> map) {
    return PrescriptionItem(
      careItemId: map['careItemId'] ?? '',
      title: map['title'] ?? '',
      instruction: map['instruction'] ?? '',
      dosage: _parseInt(map['dosage']),
      duration: _parseInt(map['duration']),
      notes: map['notes'],
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }


  Map<String, dynamic> toMap() => {
    'careItemId': careItemId,
    'title': title,
    'instruction': instruction,
    'dosage': dosage,
    'duration': duration,
    'notes': notes,
  };
}
