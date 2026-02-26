class EyeMeasurement {
  String sphere;
  String cylinder;
  String axis;

  EyeMeasurement({
    required this.sphere,
    required this.cylinder,
    required this.axis,
  });

  factory EyeMeasurement.fromJson(Map<String, dynamic> json) {
    String readAny(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) {
          return value.toString();
        }
      }
      return '';
    }

    return EyeMeasurement(
      sphere: readAny(['sphere', 'sph', 's']),
      cylinder: readAny(['cylinder', 'cyl', 'c']),
      axis: readAny(['axis', 'ax', 'a']),
    );
  }

  EyeMeasurement copy() {
    return EyeMeasurement(
      sphere: sphere,
      cylinder: cylinder,
      axis: axis,
    );
  }
}
