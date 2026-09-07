import 'package:bytebeam_fleet_consloe/domain/models/vehicle_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 6, 12);

  test('offline wins when last ping is old', () {
    final status = VehicleStatus.resolve(
      lastPing: now.subtract(const Duration(minutes: 11)),
      speed: 40,
      ignitionOn: true,
      now: now,
    );
    expect(status, VehicleStatus.offline);
  });

  test('moving before idle when speed > 0', () {
    final status = VehicleStatus.resolve(
      lastPing: now.subtract(const Duration(minutes: 1)),
      speed: 12,
      ignitionOn: true,
      now: now,
    );
    expect(status, VehicleStatus.moving);
  });

  test('idle when speed 0 and ignition on', () {
    final status = VehicleStatus.resolve(
      lastPing: now,
      speed: 0,
      ignitionOn: true,
      now: now,
    );
    expect(status, VehicleStatus.idle);
  });

  test('stopped when ignition off', () {
    final status = VehicleStatus.resolve(
      lastPing: now,
      speed: 0,
      ignitionOn: false,
      now: now,
    );
    expect(status, VehicleStatus.stopped);
  });
}
