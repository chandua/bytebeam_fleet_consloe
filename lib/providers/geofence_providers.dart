
import 'package:bytebeam_fleet_consloe/data/seed/scale_backfill.dart' show ScaleBackfill;
import 'package:bytebeam_fleet_consloe/domain/models/geofence.dart';
import 'package:bytebeam_fleet_consloe/domain/models/trip.dart';
import 'package:bytebeam_fleet_consloe/domain/services/geofence_engine.dart';
import 'package:bytebeam_fleet_consloe/providers/database_providers.dart';
import 'package:bytebeam_fleet_consloe/providers/fleet_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final geofenceListProvider =
    FutureProvider<List<GeofenceWithCount>>((ref) async {
  await ref.watch(fleetDatabaseProvider.future);
  return ref.read(geofenceRepositoryProvider).listWithCounts();
});

final recentTripsProvider = FutureProvider<List<Trip>>((ref) async {
  await ref.watch(fleetDatabaseProvider.future);
  return ref.read(tripRepositoryProvider).listRecent();
});

class GeofenceActions {
  GeofenceActions(this._ref);

  final Ref _ref;

  Future<void> create({
    required String name,
    required double lat,
    required double lng,
    required double radiusMeters,
  }) async {
    await _ref.read(geofenceRepositoryProvider).create(
          name: name,
          lat: lat,
          lng: lng,
          radiusMeters: radiusMeters,
        );
    await _recomputeAllVehicles();
    _invalidateFleet();
  }

  Future<void> update(Geofence fence) async {
    await _ref.read(geofenceRepositoryProvider).update(fence);
    await _recomputeAllVehicles();
    _invalidateFleet();
  }

  Future<void> deactivate(String id) async {
    await _ref.read(geofenceRepositoryProvider).deactivate(id);
    await _recomputeAllVehicles();
    _invalidateFleet();
  }

  /// Engine docs: re-run retained history after fence create/edit/deactivate.
  Future<void> _recomputeAllVehicles() async {
    final vehicleIds = await _ref.read(vehicleRepositoryProvider).listIds();
    final telemetry = _ref.read(telemetryRepositoryProvider);
    final geofences = _ref.read(geofenceRepositoryProvider);
    final trips = _ref.read(tripRepositoryProvider);

    for (final vehicleId in vehicleIds) {
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

  void _invalidateFleet() {
    _ref.invalidate(geofenceListProvider);
    _ref.invalidate(fleetListProvider);
    _ref.invalidate(fleetCountsProvider);
    _ref.invalidate(recentTripsProvider);
  }
}

final geofenceActionsProvider = Provider(GeofenceActions.new);

class ScaleBackfillProgress {
  const ScaleBackfillProgress({
    this.running = false,
    this.progress = 0,
    this.label = '',
    this.resultSummary,
  });

  final bool running;
  final double progress;
  final String label;
  final String? resultSummary;
}

class ScaleBackfillNotifier extends Notifier<ScaleBackfillProgress> {
  @override
  ScaleBackfillProgress build() => const ScaleBackfillProgress();

  Future<void> run() async {
    if (state.running) return;
    state = const ScaleBackfillProgress(running: true, label: 'Starting…');

    final db = await ref.watch(fleetDatabaseProvider.future);
    final result = await ScaleBackfill(db).run(
      onProgress: (progress, label) {
        state = ScaleBackfillProgress(
          running: true,
          progress: progress,
          label: label,
        );
      },
    );

    state = ScaleBackfillProgress(
      running: false,
      progress: 1,
      label: 'Done',
      resultSummary:
          '${result.vehicles} vehicles, ${result.signalRows} signals in '
          '${result.elapsed.inSeconds}s',
    );
    ref.invalidate(fleetListProvider);
    ref.invalidate(fleetCountsProvider);
  }
}

final scaleBackfillProvider =
    NotifierProvider<ScaleBackfillNotifier, ScaleBackfillProgress>(
  ScaleBackfillNotifier.new,
);
