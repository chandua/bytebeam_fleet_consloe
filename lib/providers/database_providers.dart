
import 'package:bytebeam_fleet_consloe/data/repositories/geofence_repository.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/telemetry_ingestor.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/telemetry_repository.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/trip_repository.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/vehicle_repository.dart';
import 'package:bytebeam_fleet_consloe/data/seed/demo_seed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/fleet_database.dart' show FleetDatabase;
import '../data/repositories/alert_repository.dart' show AlertRepository;

final fleetDatabaseProvider = FutureProvider<FleetDatabase>((ref) async {
  final db = await FleetDatabase.open();
  ref.onDispose(db.dispose);
  await DemoSeed(db: db).runIfNeeded();
  return db;
});

FleetDatabase _db(Ref ref) {
  final async = ref.watch(fleetDatabaseProvider);
  return async.requireValue;
}

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository(_db(ref));
});

final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  return TelemetryRepository(_db(ref));
});

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepository(_db(ref));
});

final geofenceRepositoryProvider = Provider<GeofenceRepository>((ref) {
  return GeofenceRepository(_db(ref));
});

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(_db(ref));
});

final telemetryIngestorProvider = Provider<TelemetryIngestor>((ref) {
  return TelemetryIngestor(
    telemetry: ref.watch(telemetryRepositoryProvider),
    alerts: ref.watch(alertRepositoryProvider),
    geofences: ref.watch(geofenceRepositoryProvider),
    trips: ref.watch(tripRepositoryProvider),
  );
});
