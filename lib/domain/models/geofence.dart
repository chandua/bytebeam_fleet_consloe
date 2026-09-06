class Geofence {
  const Geofence({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.active,
    required this.createdAt,
    this.deactivatedAt,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;
  final bool active;
  final DateTime createdAt;
  final DateTime? deactivatedAt;

  Geofence copyWith({
    String? name,
    double? lat,
    double? lng,
    double? radiusMeters,
    bool? active,
    DateTime? deactivatedAt,
  }) {
    return Geofence(
      id: id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      active: active ?? this.active,
      createdAt: createdAt,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
    );
  }
}

class GeofenceWithCount {
  const GeofenceWithCount({
    required this.geofence,
    required this.vehicleCount,
  });

  final Geofence geofence;
  final int vehicleCount;
}

enum GeofenceTransitionType { enter, exit }

class GeofenceTransition {
  const GeofenceTransition({
    required this.id,
    required this.vehicleId,
    required this.geofenceId,
    required this.type,
    required this.eventTime,
    required this.confirmed,
  });

  final String id;
  final String vehicleId;
  final String geofenceId;
  final GeofenceTransitionType type;
  final DateTime eventTime;
  final bool confirmed;
}
