enum MaintenanceState { ok, upcoming, due }

class MaintenanceStatus {
  final String type;
  final int lastMileage;
  final int nextDueMileage;
  final int remainingKm;
  final MaintenanceState state;

  MaintenanceStatus({
    required this.type,
    required this.lastMileage,
    required this.nextDueMileage,
    required this.remainingKm,
    required this.state,
  });
}
