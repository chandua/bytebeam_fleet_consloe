import 'package:fleet_console/data/repositories/alert_repository.dart';
import 'package:fleet_console/data/repositories/geofence_repository.dart';
import 'package:fleet_console/data/repositories/telemetry_repository.dart';
import 'package:fleet_console/data/repositories/trip_repository.dart';
import 'package:fleet_console/domain/models/signal.dart';
import 'package:fleet_console/domain/services/alert_engine.dart';
import 'package:fleet_console/domain/services/geofence_engine.dart';

/// Single write path: telemetry → DuckDB, then derive alerts / fences / trips.
class TelemetryIngestor {
  TelemetryIngestor({
    required this.telemetry,
    required this.alerts,
    required this.geofences,
    required this.trips,
  });

  final TelemetryRepository telemetry;
  final AlertRepository alerts;
  final GeofenceRepository geofences;
  final TripRepository trips;

  Future<void> ingest({
    required String vehicleId,
    required DateTime eventTime,
    required Map<SignalKind, double> values,
  }) async {
    await telemetry.ingestPacket(
      vehicleId: vehicleId,
      eventTime: eventTime,
      values: values,
    );

    final latest = await telemetry.latestMap(vehicleId);
    await alerts.evaluateFromLatest(
      vehicleId,
      {
        for (final e in latest.entries)
          e.key: SignalSnapshot(
            value: e.value.value,
            eventTime: e.value.eventTime,
          ),
      },
    );

    final hasLocation =
        values.containsKey(SignalKind.lat) && values.containsKey(SignalKind.lng);
    if (hasLocation) {
      final history = await telemetry.locationHistory(vehicleId);
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
        vehicleId: vehicleId,
        samples: samples,
      );
      await trips.applyTransitions(
        vehicleId: vehicleId,
        confirmed: transitions,
      );
    }
  }
}
