class VehicleMonitorState {
  final String? vehicleId;
  final String? make;
  final String? model;
  final double speed;
  final double acceleration;
  final double distance;

  VehicleMonitorState({
    this.vehicleId,
    this.make,
    this.model,
    this.speed = 0.0,
    this.acceleration = 0.0,
    this.distance = 0.0,
  });

  VehicleMonitorState copyWith({
    String? vehicleId,
    String? make,
    String? model,
    double? speed,
    double? acceleration,
    double? distance,
  }) {
    return VehicleMonitorState(
      vehicleId: vehicleId ?? this.vehicleId,
      make: make ?? this.make,
      model: model ?? this.model,
      speed: speed ?? this.speed,
      acceleration: acceleration ?? this.acceleration,
      distance: distance ?? this.distance,
    );
  }
}
