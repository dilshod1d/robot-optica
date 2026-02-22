import 'eye_side_result.dart';

class EyeReport {
  final String? date;
  final EyeSideResult right;
  final EyeSideResult left;
  final String? pd;

  EyeReport({
    this.date,
    required this.right,
    required this.left,
    this.pd,
  });
}
