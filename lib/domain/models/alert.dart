enum AlertSeverity { warning, critical }

enum AlertKind {
  lowBattery,
  overheating;

  String get label => switch (this) {
        AlertKind.lowBattery => 'Low battery',
        AlertKind.overheating => 'Battery overheating',
      };

  String get storageKey => switch (this) {
        AlertKind.lowBattery => 'low_battery',
        AlertKind.overheating => 'overheating',
      };

  static AlertKind? fromStorage(String key) => switch (key) {
        'low_battery' => AlertKind.lowBattery,
        'overheating' => AlertKind.overheating,
        _ => null,
      };
}

class FleetAlert {
  const FleetAlert({
    required this.id,
    required this.vehicleId,
    required this.kind,
    required this.severity,
    required this.message,
    required this.triggeredAt,
    this.resolvedAt,
    this.dismissedAt,
    this.dismissReason,
  });

  final String id;
  final String vehicleId;
  final AlertKind kind;
  final AlertSeverity severity;
  final String message;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final DateTime? dismissedAt;
  final String? dismissReason;

  bool get isActive => resolvedAt == null && dismissedAt == null;
}

/// Dismissal reasons shown in the sheet, in the order the brief asks for.
abstract final class DismissReasons {
  static const onIt = 'I am on it';
  static const wrongAlert = 'Wrong alert';
  static const somethingElse = 'Something else…';

  static const ordered = [onIt, wrongAlert, somethingElse];
}
