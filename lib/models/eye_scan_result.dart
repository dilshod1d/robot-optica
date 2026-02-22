import 'eye_side.dart';

class EyeScanResult {
  String? date;
  String? pd;
  EyeSide right;
  EyeSide left;

  EyeScanResult({
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
}






