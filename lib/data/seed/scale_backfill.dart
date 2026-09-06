import 'dart:math';

import 'package:bytebeam_fleet_consloe/core/constants.dart';
import 'package:bytebeam_fleet_consloe/data/database/fleet_database.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/telemetry_repository.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/vehicle_repository.dart';
import 'package:bytebeam_fleet_consloe/domain/models/signal.dart';

import 'package:uuid/uuid.dart';

/// Debug/scale action: 500 vehicles and ~2M signal rows.
class ScaleBackfill {
  ScaleBackfill(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _vehicles = VehicleRepository(_db, clock: clock),
        _telemetry = TelemetryRepository(_db, clock: clock);

  final FleetDatabase _db;
  final DateTime Function() _clock;
  final VehicleRepository _vehicles;
  final TelemetryRepository _telemetry;
  final _uuid = const Uuid();

  Future<ScaleBackfillResult> run({
    void Function(double progress, String label)? onProgress,
  }) async {
    final started = DateTime.now();
    final now = _clock().toUtc();
    final rng = Random(7);
    const models = ['Volvo FH Electric', 'Tesla Semi', 'BYD 8TT', 'eActros'];

    onProgress?.call(0.02, 'Creating vehicles…');
    for (var i = 0; i < FleetConstants.scaleVehicleCount; i++) {
      final id = 'scale-${(i + 1).toString().padLeft(4, '0')}';
      await _vehicles.upsertVehicle(
        id: id,
        regNumber: 'SC-${(10000 + i)}',
        model: models[i % models.length],
      );
      if (i % 50 == 0) {
        onProgress?.call(0.02 + (i / FleetConstants.scaleVehicleCount) * 0.08, 'Vehicles $i');
      }
    }

    // ~2M rows across vehicles. Each packet writes several signal rows.
    const signalsPerPacket = 6;
    final packetsNeeded =
        (FleetConstants.scaleSignalRows / signalsPerPacket).ceil();
    final packetsPerVehicle =
        (packetsNeeded / FleetConstants.scaleVehicleCount).ceil();

    onProgress?.call(0.12, 'Writing signal history…');
    var written = 0;
    final batch = <SignalInsert>[];

    for (var v = 0; v < FleetConstants.scaleVehicleCount; v++) {
      final vehicleId = 'scale-${(v + 1).toString().padLeft(4, '0')}';
      for (var p = 0; p < packetsPerVehicle; p++) {
        final event = now.subtract(Duration(minutes: p * 3 + (v % 5)));
        final ingested = event.add(Duration(seconds: rng.nextInt(40)));
        final soc = 20 + rng.nextDouble() * 70;

        void add(SignalKind kind, double? value) {
          batch.add(
            SignalInsert(
              id: _uuid.v4(),
              vehicleId: vehicleId,
              signal: kind,
              value: value,
              eventTime: event,
              ingestedAt: ingested,
            ),
          );
        }

        add(SignalKind.soc, soc);
        add(SignalKind.rangeKm, soc * 3);
        add(SignalKind.speed, rng.nextDouble() * 60);
        add(SignalKind.batteryTemp, 25 + rng.nextDouble() * 15);
        add(SignalKind.odometer, 10000 + v * 10.0 + p);
        add(SignalKind.lastPing, 1);

        if (batch.length >= 2000) {
          written += batch.length;
          await _telemetry.ingestMany(batch);
          batch.clear();
          onProgress?.call(
            0.12 + (written / FleetConstants.scaleSignalRows).clamp(0, 1) * 0.85,
            'Signals ~$written',
          );
        }
      }
    }

    if (batch.isNotEmpty) {
      written += batch.length;
      await _telemetry.ingestMany(batch);
    }

    await _db.execute('''
      INSERT INTO meta (key, value) VALUES ('scale_backfill', '1')
      ON CONFLICT (key) DO UPDATE SET value = '1'
    ''');

    final elapsed = DateTime.now().difference(started);
    final signalCount = await _telemetry.signalCount();
    onProgress?.call(1, 'Done');

    return ScaleBackfillResult(
      vehicles: FleetConstants.scaleVehicleCount,
      signalRows: signalCount,
      elapsed: elapsed,
    );
  }
}

class ScaleBackfillResult {
  const ScaleBackfillResult({
    required this.vehicles,
    required this.signalRows,
    required this.elapsed,
  });

  final int vehicles;
  final int signalRows;
  final Duration elapsed;
}
