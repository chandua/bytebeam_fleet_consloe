import 'vehicle_status.dart';

class Vehicle {
  const Vehicle({
    required this.id,
    required this.regNumber,
    required this.model,
  });

  final String id;
  final String regNumber;
  final String model;
}

class VehicleListItem {
  const VehicleListItem({
    required this.id,
    required this.regNumber,
    required this.model,
    required this.status,
    this.soc,
    this.rangeKm,
    this.speed,
    this.ignitionOn,
    this.lastPing,
    this.activeAlertCount = 0,
    this.currentGeofenceName,
  });

  final String id;
  final String regNumber;
  final String model;
  final VehicleStatus status;
  final double? soc;
  final double? rangeKm;
  final double? speed;
  final bool? ignitionOn;
  final DateTime? lastPing;
  final int activeAlertCount;
  final String? currentGeofenceName;

  bool get hasAlert => activeAlertCount > 0;
}

class FleetFilterCounts {
  const FleetFilterCounts({
    this.all = 0,
    this.moving = 0,
    this.idle = 0,
    this.stopped = 0,
    this.offline = 0,
  });

  final int all;
  final int moving;
  final int idle;
  final int stopped;
  final int offline;

  int forStatus(VehicleStatus? status) => switch (status) {
        null => all,
        VehicleStatus.moving => moving,
        VehicleStatus.idle => idle,
        VehicleStatus.stopped => stopped,
        VehicleStatus.offline => offline,
      };
}
