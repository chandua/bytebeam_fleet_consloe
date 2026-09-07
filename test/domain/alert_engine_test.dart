import 'package:bytebeam_fleet_consloe/core/constants.dart';
import 'package:bytebeam_fleet_consloe/domain/models/alert.dart';
import 'package:bytebeam_fleet_consloe/domain/models/signal.dart';
import 'package:bytebeam_fleet_consloe/domain/services/alert_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = AlertEngine();
  final now = DateTime.utc(2026, 9, 6, 12);

  SignalSnapshot snap(double value, {Duration age = Duration.zero}) =>
      SignalSnapshot(value: value, eventTime: now.subtract(age));

  test('critical SOC escalates over warning on the same kind', () {
    final critical = engine.evaluate(
      vehicleId: 'v1',
      latest: {SignalKind.soc: snap(8)},
      now: now,
    );
    expect(critical.single.kind, AlertKind.lowBattery);
    expect(critical.single.severity, AlertSeverity.critical);
    expect(critical.single.conditionActive, isTrue);

    final warning = engine.evaluate(
      vehicleId: 'v1',
      latest: {SignalKind.soc: snap(15)},
      now: now,
    );
    expect(warning.single.severity, AlertSeverity.warning);
  });

  test('SOC recovery emits a clear intent', () {
    final intents = engine.evaluate(
      vehicleId: 'v1',
      latest: {SignalKind.soc: snap(55)},
      now: now,
    );
    expect(intents.single.kind, AlertKind.lowBattery);
    expect(intents.single.conditionActive, isFalse);
  });

  test('stale readings do not open alerts', () {
    final intents = engine.evaluate(
      vehicleId: 'v1',
      latest: {
        SignalKind.soc: snap(
          5,
          age: FleetConstants.staleAfter + const Duration(minutes: 1),
        ),
        SignalKind.batteryTemp: snap(
          50,
          age: FleetConstants.staleAfter + const Duration(minutes: 1),
        ),
      },
      now: now,
    );
    expect(intents, isEmpty);
  });

  test('overheating threshold', () {
    final hot = engine.evaluate(
      vehicleId: 'v1',
      latest: {SignalKind.batteryTemp: snap(46)},
      now: now,
    );
    expect(hot.single.kind, AlertKind.overheating);
    expect(hot.single.conditionActive, isTrue);

    final cool = engine.evaluate(
      vehicleId: 'v1',
      latest: {SignalKind.batteryTemp: snap(40)},
      now: now,
    );
    expect(cool.single.conditionActive, isFalse);
  });
}
