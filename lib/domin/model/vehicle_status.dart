enum VehicleStatus {
  offline,
  moving,
  idle,
  stopped;

  String get label => switch (this) {
        VehicleStatus.offline => 'Offline',
        VehicleStatus.moving => 'Moving',
        VehicleStatus.idle => 'Idle',
        VehicleStatus.stopped => 'Stopped',
      };

  /// Matches the SQL CASE order from the brief: first match wins.
  static VehicleStatus resolve({
    required DateTime? lastPing,
    required double? speed,
    required bool? ignitionOn,
    required DateTime now,
    Duration offlineAfter = const Duration(minutes: 10),
  }) {
    if (lastPing == null || now.difference(lastPing) > offlineAfter) {
      return VehicleStatus.offline;
    }
    if ((speed ?? 0) > 0) return VehicleStatus.moving;
    if (ignitionOn == true) return VehicleStatus.idle;
    return VehicleStatus.stopped;
  }

  static VehicleStatus? fromSql(String? raw) {
    if (raw == null) return null;
    return switch (raw.toUpperCase()) {
      'OFFLINE' => VehicleStatus.offline,
      'MOVING' => VehicleStatus.moving,
      'IDLE' => VehicleStatus.idle,
      'STOPPED' => VehicleStatus.stopped,
      _ => null,
    };
  }

  String get sqlValue => name.toUpperCase();
}
