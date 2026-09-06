

import 'package:bytebeam_fleet_consloe/core/constants.dart';
import 'package:bytebeam_fleet_consloe/domain/models/signal.dart';

class SignalVerdictResolver {
  const SignalVerdictResolver();

  SignalVerdict? verdict({
    required double? value,
    required DateTime? eventTime,
    required SignalKind kind,
    required DateTime now,
    required bool alertCondition,
  }) {
    if (value == null && eventTime == null) return null;
    if (eventTime == null) return null;
    if (now.difference(eventTime) > FleetConstants.staleAfter) {
      return SignalVerdict.stale;
    }
    if (alertCondition) return SignalVerdict.alert;
    return SignalVerdict.normal;
  }

  bool isAlertCondition(SignalKind kind, double? value) {
    if (value == null) return false;
    return switch (kind) {
      SignalKind.soc => value < FleetConstants.lowBatterySoc,
      SignalKind.batteryTemp => value > FleetConstants.overheatCelsius,
      _ => false,
    };
  }
}
