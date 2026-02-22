import 'eye_measurement.dart';

class EyeSideResult {
  final List<EyeMeasurement> readings;
  final EyeMeasurement? avg;
  final String? se;

  EyeSideResult({
    required this.readings,
    this.avg,
    this.se,
  });
}
