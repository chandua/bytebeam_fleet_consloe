
import 'package:bytebeam_fleet_consloe/data/seed/scale_backfill.dart' show ScaleBackfill;
import 'package:bytebeam_fleet_consloe/domain/models/geofence.dart';
import 'package:bytebeam_fleet_consloe/domain/models/trip.dart';
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
    _ref.invalidate(geofenceListProvider);
    _ref.invalidate(fleetListProvider);
  }

  Future<void> update(Geofence fence) async {
    await _ref.read(geofenceRepositoryProvider).update(fence);
    _ref.invalidate(geofenceListProvider);
    _ref.invalidate(fleetListProvider);
  }

  Future<void> deactivate(String id) async {
    await _ref.read(geofenceRepositoryProvider).deactivate(id);
    _ref.invalidate(geofenceListProvider);
    _ref.invalidate(fleetListProvider);
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
