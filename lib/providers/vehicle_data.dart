class VehicleMonitorState {
  final String? vehicleId;
  final String? make;
  final String? model;
  final double speed;
  final double acceleration;
  final double distance;

  final List<double> speedHistory;
  final List<double> accelerationHistory;

  VehicleMonitorState({
    this.vehicleId,
    this.make,
    this.model,
    this.speed = 0.0,
    this.acceleration = 0.0,
    this.distance = 0.0,
    this.speedHistory = const [],
    this.accelerationHistory = const [],
  });

  VehicleMonitorState copyWith({
    String? vehicleId,
    String? make,
    String? model,
    double? speed,
    double? acceleration,
    double? distance,
    List<double>? speedHistory,
    List<double>? accelerationHistory,
  }) {
    return VehicleMonitorState(
      vehicleId: vehicleId ?? this.vehicleId,
      make: make ?? this.make,
      model: model ?? this.model,
      speed: speed ?? this.speed,
      acceleration: acceleration ?? this.acceleration,
      distance: distance ?? this.distance,
      speedHistory: speedHistory ?? this.speedHistory,
      accelerationHistory: accelerationHistory ?? this.accelerationHistory,
    );
  }
}
