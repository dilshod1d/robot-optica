import 'eye_measurement.dart';

class EyeSide {
  List<EyeMeasurement> readings;
  EyeMeasurement? avg;
  String? se;

  EyeSide({
    required this.readings,
    this.avg,
    this.se,
  });

  factory EyeSide.fromJson(Map<String, dynamic> json) {
    return EyeSide(
      readings: _parseReadings(json['readings']),
      avg: _measurementFromDynamic(json['avg']),
      se: json['se']?.toString(),
    );
  }

  static List<EyeMeasurement> _parseReadings(dynamic raw) {
    if (raw == null) return [];

    if (raw is List) {
      return raw
          .map(_measurementFromDynamic)
          .whereType<EyeMeasurement>()
          .toList();
    }

    if (raw is Map) {
      final columnar = _parseColumnarReadings(raw);
      if (columnar.isNotEmpty) return columnar;

      final values = raw.values.toList();
      final fromValues = values
          .map(_measurementFromDynamic)
          .whereType<EyeMeasurement>()
          .toList();
      if (fromValues.isNotEmpty) return fromValues;
    }

    return [];
  }

  static List<EyeMeasurement> _parseColumnarReadings(Map<dynamic, dynamic> raw) {
    List<dynamic> spheres = _listify(raw['sphere'] ?? raw['sph'] ?? raw['s']);
    List<dynamic> cylinders =
        _listify(raw['cylinder'] ?? raw['cyl'] ?? raw['c']);
    List<dynamic> axes = _listify(raw['axis'] ?? raw['ax'] ?? raw['a']);

    final maxLen = [
      spheres.length,
      cylinders.length,
      axes.length,
    ].reduce((a, b) => a > b ? a : b);

    if (maxLen == 0) return [];

    return List.generate(maxLen, (i) {
      return EyeMeasurement(
        sphere: _stringAt(spheres, i),
        cylinder: _stringAt(cylinders, i),
        axis: _stringAt(axes, i),
      );
    });
  }

  static List<dynamic> _listify(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return [];
      if (trimmed.contains(',') || trimmed.contains('\n') || trimmed.contains(';')) {
        final parts = trimmed
            .split(RegExp(r'[,\n;]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) return parts;
      }
      return [trimmed];
    }
    return [value];
  }

  static String _stringAt(List<dynamic> list, int index) {
    if (index < 0 || index >= list.length) return '';
    final value = list[index];
    return value == null ? '' : value.toString();
  }

  static EyeMeasurement? _measurementFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is EyeMeasurement) return value;
    if (value is Map) {
      final mapped = <String, dynamic>{};
      value.forEach((key, val) {
        mapped[key.toString()] = val;
      });
      return EyeMeasurement.fromJson(mapped);
    }
    if (value is List) {
      return EyeMeasurement(
        sphere: value.isNotEmpty ? value[0]?.toString() ?? '' : '',
        cylinder: value.length > 1 ? value[1]?.toString() ?? '' : '',
        axis: value.length > 2 ? value[2]?.toString() ?? '' : '',
      );
    }
    return null;
  }

  EyeSide copy() {
    return EyeSide(
      readings: readings.map((m) => m.copy()).toList(),
      avg: avg?.copy(),
      se: se,
    );
  }
}
