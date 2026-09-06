import 'dart:math';

import 'package:bytebeam_fleet_consloe/core/constants.dart';
import 'package:bytebeam_fleet_consloe/core/sql.dart';
import 'package:bytebeam_fleet_consloe/data/database/fleet_database.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/alert_repository.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/geofence_repository.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/telemetry_repository.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/trip_repository.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/vehicle_repository.dart';
import 'package:bytebeam_fleet_consloe/domain/models/signal.dart';
import 'package:bytebeam_fleet_consloe/domain/services/alert_engine.dart';
import 'package:bytebeam_fleet_consloe/domain/services/geofence_engine.dart';
import 'package:uuid/uuid.dart';

/// Seeds a small, realistic demo fleet the first time the DB is empty.
class DemoSeed {
  DemoSeed({
    required FleetDatabase db,
    DateTime Function()? clock,
  })  : _db = db,
        _clock = clock ?? DateTime.now,
        vehicles = VehicleRepository(db, clock: clock),
        telemetry = TelemetryRepository(db, clock: clock),
        alerts = AlertRepository(db, clock: clock),
        geofences = GeofenceRepository(db, clock: clock),
        trips = TripRepository(db, clock: clock);

  final FleetDatabase _db;
  final DateTime Function() _clock;
  final VehicleRepository vehicles;
  final TelemetryRepository telemetry;
  final AlertRepository alerts;
  final GeofenceRepository geofences;
  final TripRepository trips;
  final _uuid = const Uuid();

  Future<bool> needsSeed() async {
    final flag = await _db.fetchScalar(
      "SELECT value FROM meta WHERE key = 'seeded'",
    );
    if (flag == '1') return false;
    return (await vehicles.vehicleCount()) == 0;
  }

  Future<void> runIfNeeded() async {
    if (!await needsSeed()) return;
    await run();
  }

  Future<void> run() async {
    final now = _clock().toUtc();
    final rng = Random(42);

    final depotId = await geofences.create(
      name: 'Depot North',
      lat: 12.9716,
      lng: 77.5946,
      radiusMeters: 400,
    );
    final hubId = await geofences.create(
      name: 'City Hub',
      lat: 12.9352,
      lng: 77.6245,
      radiusMeters: 350,
    );
    final yardId = await geofences.create(
      name: 'South Yard',
      lat: 12.9081,
      lng: 77.6512,
      radiusMeters: 500,
    );

    // Keep a deactivated fence around for trip history demos.
    final oldId = await geofences.create(
      name: 'Old Staging (retired)',
      lat: 12.9600,
      lng: 77.5800,
      radiusMeters: 300,
    );
    await geofences.deactivate(oldId);

    final fenceCenters = [
      (depotId, 12.9716, 77.5946),
      (hubId, 12.9352, 77.6245),
      (yardId, 12.9081, 77.6512),
    ];

    const models = [
      'Volvo FH Electric',
      'Tesla Semi',
      'BYD 8TT',
      'Mercedes eActros',
      'Scania 40R',
    ];

    for (var i = 0; i < FleetConstants.demoVehicleCount; i++) {
      final id = 'veh-${(i + 1).toString().padLeft(3, '0')}';
      final reg = 'KA01-EV-${(1000 + i).toString()}';
      final model = models[i % models.length];
      await vehicles.upsertVehicle(id: id, regNumber: reg, model: model);

      final statusRoll = i % 5;
      final ageMinutes = switch (statusRoll) {
        0 => 45, // offline
        1 => 2, // moving
        2 => 3, // idle
        3 => 4, // stopped
        _ => 1,
      };

      final eventTime = now.subtract(Duration(minutes: ageMinutes));
      final soc = switch (i % 7) {
        0 => 8.0 + rng.nextDouble() * 2, // critical
        1 => 15.0 + rng.nextDouble() * 3, // warning
        _ => 35.0 + rng.nextDouble() * 55,
      };
      final temp = i % 11 == 0 ? 47.0 + rng.nextDouble() * 3 : 28.0 + rng.nextDouble() * 10;
      final speed = statusRoll == 1 ? 20.0 + rng.nextDouble() * 40 : 0.0;
      final ignition = statusRoll == 3 ? 0.0 : (statusRoll == 0 ? 0.0 : 1.0);

      final fence = fenceCenters[i % fenceCenters.length];
      // Moving trucks sit slightly outside their "home" fence.
      final lat = fence.$2 + (statusRoll == 1 ? 0.01 : 0.0005 * rng.nextDouble());
      final lng = fence.$3 + (statusRoll == 1 ? 0.008 : 0.0005 * rng.nextDouble());

      await telemetry.ingestPacket(
        vehicleId: id,
        eventTime: eventTime,
        values: {
          SignalKind.soc: soc,
          SignalKind.rangeKm: soc * 3.2,
          SignalKind.speed: speed,
          SignalKind.batteryTemp: temp,
          SignalKind.odometer: 12000 + i * 337.0 + rng.nextDouble() * 50,
          SignalKind.ignition: ignition,
          SignalKind.lat: lat,
          SignalKind.lng: lng,
          SignalKind.gpsAccuracy: 8 + rng.nextDouble() * 10,
        },
      );

      // A short trail so geofence confirmation has two samples.
      final earlier = eventTime.subtract(const Duration(minutes: 2));
      await telemetry.ingestPacket(
        vehicleId: id,
        eventTime: earlier,
        values: {
          SignalKind.soc: soc + 1,
          SignalKind.rangeKm: (soc + 1) * 3.2,
          SignalKind.speed: speed,
          SignalKind.batteryTemp: temp,
          SignalKind.odometer: 12000 + i * 337.0,
          SignalKind.ignition: ignition,
          SignalKind.lat: lat - 0.0002,
          SignalKind.lng: lng - 0.0001,
          SignalKind.gpsAccuracy: 10,
        },
      );

      final latest = await telemetry.latestMap(id);
      await alerts.evaluateFromLatest(
        id,
        {
          for (final e in latest.entries)
            e.key: SignalSnapshot(value: e.value.value, eventTime: e.value.eventTime),
        },
      );

      final history = await telemetry.locationHistory(id);
      final samples = history
          .map(
            (p) => LocationSample(
              lat: p.lat,
              lng: p.lng,
              eventTime: p.eventTime,
              accuracyMeters: p.accuracyMeters,
            ),
          )
          .toList();
      final transitions = await geofences.recomputeVehicle(
        vehicleId: id,
        samples: samples,
      );
      await trips.applyTransitions(vehicleId: id, confirmed: transitions);

      // Seed one completed trip for a handful of trucks.
      if (i % 6 == 0) {
        final startKey = '$id|seed-start|$i';
        final endKey = '$id|seed-end|$i';
        await _db.execute('''
          INSERT INTO trips (
            id, vehicle_id, origin_geofence_id, destination_geofence_id,
            started_at, ended_at, status, source_start_key, source_end_key
          ) VALUES (
            ${sqlString(_uuid.v4())},
            ${sqlString(id)},
            ${sqlString(depotId)},
            ${sqlString(hubId)},
            ${sqlTimestamp(now.subtract(Duration(hours: 5 + i % 3)))},
            ${sqlTimestamp(now.subtract(Duration(hours: 3 + i % 2)))},
            'completed',
            ${sqlString(startKey)},
            ${sqlString(endKey)}
          )
        ''');
      }
    }

    await _db.execute('''
      INSERT INTO meta (key, value) VALUES ('seeded', '1')
      ON CONFLICT (key) DO UPDATE SET value = '1'
    ''');
  }
}
