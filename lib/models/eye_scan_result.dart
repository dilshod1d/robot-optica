import 'eye_side.dart';

class EyeScanResult {
  String? id;
  String? date;
  String? pd;
  EyeSide right;
  EyeSide left;

  EyeScanResult({
    this.id,
    required this.date,
    required this.pd,
    required this.right,
    required this.left,
  });

  factory EyeScanResult.fromJson(Map<String, dynamic> json) {
    final rightRaw = json['right'];
    final leftRaw = json['left'];

    return EyeScanResult(
      date: json['date']?.toString(),
      pd: json['pd']?.toString(),
      right: EyeSide.fromJson(
        rightRaw is Map
            ? rightRaw.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{},
      ),
      left: EyeSide.fromJson(
        leftRaw is Map
            ? leftRaw.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{},
      ),
    );
  }

  EyeScanResult copy() {
    return EyeScanResult(
      id: id,
      date: date,
      pd: pd,
      right: right.copy(),
      left: left.copy(),
    );
  }
}





