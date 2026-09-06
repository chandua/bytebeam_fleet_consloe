enum TripStatus { inProgress, completed }

class Trip {
  const Trip({
    required this.id,
    required this.vehicleId,
    required this.originGeofenceId,
    required this.startedAt,
    required this.status,
    this.destinationGeofenceId,
    this.endedAt,
    this.originName,
    this.destinationName,
  });

  final String id;
  final String vehicleId;
  final String originGeofenceId;
  final String? destinationGeofenceId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final TripStatus status;
  final String? originName;
  final String? destinationName;

  bool get isActive => status == TripStatus.inProgress;
}
