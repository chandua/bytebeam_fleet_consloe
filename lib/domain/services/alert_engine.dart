

import 'package:bytebeam_fleet_consloe/core/constants.dart';
import 'package:bytebeam_fleet_consloe/domain/models/alert.dart';
import 'package:bytebeam_fleet_consloe/domain/models/signal.dart';

/// Pure rules for turning fresh signal values into alert intents.
///
/// SOC < 10% and SOC < 20% collapse into one escalating low-battery alert.
class AlertEngine {
  const AlertEngine();

  List<AlertIntent> evaluate({
    required String vehicleId,
    required Map<SignalKind, SignalSnapshot> latest,
    required DateTime now,
    Duration staleAfter = FleetConstants.staleAfter,
  }) {
    final intents = <AlertIntent>[];

    final soc = latest[SignalKind.soc];
    if (soc != null && soc.isFresh(now, staleAfter) && soc.value != null) {
      if (soc.value! < FleetConstants.criticalBatterySoc) {
        intents.add(
          AlertIntent(
            vehicleId: vehicleId,
            kind: AlertKind.lowBattery,
            severity: AlertSeverity.critical,
            message:
                'Battery critically low (${soc.value!.toStringAsFixed(0)}%)',
            conditionActive: true,
          ),
        );
      } else if (soc.value! < FleetConstants.lowBatterySoc) {
        intents.add(
          AlertIntent(
            vehicleId: vehicleId,
            kind: AlertKind.lowBattery,
            severity: AlertSeverity.warning,
            message: 'Low battery (${soc.value!.toStringAsFixed(0)}%)',
            conditionActive: true,
          ),
        );
      } else {
        intents.add(
          AlertIntent(
            vehicleId: vehicleId,
            kind: AlertKind.lowBattery,
            severity: AlertSeverity.warning,
            message: 'Low battery cleared',
            conditionActive: false,
          ),
        );
      }
    }

    final temp = latest[SignalKind.batteryTemp];
    if (temp != null && temp.isFresh(now, staleAfter) && temp.value != null) {
      if (temp.value! > FleetConstants.overheatCelsius) {
        intents.add(
          AlertIntent(
            vehicleId: vehicleId,
            kind: AlertKind.overheating,
            severity: AlertSeverity.critical,
            message:
                'Battery overheating (${temp.value!.toStringAsFixed(1)} °C)',
            conditionActive: true,
          ),
        );
      } else {
        intents.add(
          AlertIntent(
            vehicleId: vehicleId,
            kind: AlertKind.overheating,
            severity: AlertSeverity.critical,
            message: 'Overheating cleared',
            conditionActive: false,
          ),
        );
      }
    }

    return intents;
  }
}

class SignalSnapshot {
  const SignalSnapshot({required this.value, required this.eventTime});

  final double? value;
  final DateTime eventTime;

  bool isFresh(DateTime now, Duration staleAfter) =>
      now.difference(eventTime) <= staleAfter;
}

class AlertIntent {
  const AlertIntent({
    required this.vehicleId,
    required this.kind,
    required this.severity,
    required this.message,
    required this.conditionActive,
  });

  final String vehicleId;
  final AlertKind kind;
  final AlertSeverity severity;
  final String message;
  final bool conditionActive;
}
