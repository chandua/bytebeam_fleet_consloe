import 'package:bytebeam_fleet_consloe/core/sql.dart';
import 'package:bytebeam_fleet_consloe/data/database/fleet_database.dart';
import 'package:bytebeam_fleet_consloe/domain/models/trip.dart';
import 'package:bytebeam_fleet_consloe/domain/services/geofence_engine.dart';
import 'package:bytebeam_fleet_consloe/domain/services/trip_engine.dart';

import 'package:uuid/uuid.dart';

class TripRepository {
  TripRepository(this._db, {DateTime Function()? clock});

  final FleetDatabase _db;
  final _uuid = const Uuid();
  final _engine = const TripEngine();

  Future<List<Trip>> listForVehicle(String vehicleId) async {
    final rows = await _db.fetchAll('''
      SELECT t.id, t.vehicle_id, t.origin_geofence_id, t.destination_geofence_id,
             t.started_at, t.ended_at, t.status,
             o.name AS origin_name, d.name AS destination_name
      FROM trips t
      LEFT JOIN geofences o ON o.id = t.origin_geofence_id
      LEFT JOIN geofences d ON d.id = t.destination_geofence_id
      WHERE t.vehicle_id = ${sqlString(vehicleId)}
      ORDER BY t.started_at DESC
    ''');
    return rows.map(_map).toList();
  }

  Future<List<Trip>> listRecent({int limit = 50}) async {
    final rows = await _db.fetchAll('''
      SELECT t.id, t.vehicle_id, t.origin_geofence_id, t.destination_geofence_id,
             t.started_at, t.ended_at, t.status,
             o.name AS origin_name, d.name AS destination_name
      FROM trips t
      LEFT JOIN geofences o ON o.id = t.origin_geofence_id
      LEFT JOIN geofences d ON d.id = t.destination_geofence_id
      ORDER BY t.started_at DESC
      LIMIT $limit
    ''');
    return rows.map(_map).toList();
  }

  Future<Trip?> activeForVehicle(String vehicleId) async {
    final rows = await _db.fetchAll('''
      SELECT t.id, t.vehicle_id, t.origin_geofence_id, t.destination_geofence_id,
             t.started_at, t.ended_at, t.status,
             o.name AS origin_name, d.name AS destination_name
      FROM trips t
      LEFT JOIN geofences o ON o.id = t.origin_geofence_id
      LEFT JOIN geofences d ON d.id = t.destination_geofence_id
      WHERE t.vehicle_id = ${sqlString(vehicleId)}
        AND t.status = 'inProgress'
      ORDER BY t.started_at DESC
      LIMIT 1
    ''');
    if (rows.isEmpty) return null;
    return _map(rows.first);
  }

  Future<void> applyTransitions({
    required String vehicleId,
    required List<ProposedTransition> confirmed,
  }) async {
    final active = await activeForVehicle(vehicleId);
    final mutations = _engine.apply(
      vehicleId: vehicleId,
      confirmed: confirmed,
      activeTrip: active,
    );

    for (final m in mutations) {
      switch (m) {
        case TripStart(:final originGeofenceId, :final startedAt, :final sourceKey):
          final exists = await _db.fetchScalar('''
            SELECT id FROM trips WHERE source_start_key = ${sqlString(sourceKey)}
          ''');
          if (exists != null) continue;
          // Still only one active trip.
          final open = await activeForVehicle(vehicleId);
          if (open != null) continue;

          await _db.execute('''
            INSERT INTO trips (
              id, vehicle_id, origin_geofence_id, destination_geofence_id,
              started_at, ended_at, status, source_start_key, source_end_key
            ) VALUES (
              ${sqlString(_uuid.v4())},
              ${sqlString(vehicleId)},
              ${sqlString(originGeofenceId)},
              NULL,
              ${sqlTimestamp(startedAt)},
              NULL,
              'inProgress',
              ${sqlString(sourceKey)},
              NULL
            )
          ''');
        case TripComplete(
            :final destinationGeofenceId,
            :final endedAt,
            :final sourceKey,
          ):
          final endTaken = await _db.fetchScalar('''
            SELECT id FROM trips WHERE source_end_key = ${sqlString(sourceKey)}
          ''');
          if (endTaken != null) continue;

          final open = await activeForVehicle(vehicleId);
          if (open == null) continue;

          await _db.execute('''
            UPDATE trips SET
              destination_geofence_id = ${sqlString(destinationGeofenceId)},
              ended_at = ${sqlTimestamp(endedAt)},
              status = 'completed',
              source_end_key = ${sqlString(sourceKey)}
            WHERE id = ${sqlString(open.id)}
          ''');
      }
    }
  }

  Trip _map(List<Object?> r) {
    return Trip(
      id: r[0]! as String,
      vehicleId: r[1]! as String,
      originGeofenceId: r[2]! as String,
      destinationGeofenceId: r[3] as String?,
      startedAt: _asDateTime(r[4])!,
      endedAt: _asDateTime(r[5]),
      status: (r[6]! as String) == 'completed'
          ? TripStatus.completed
          : TripStatus.inProgress,
      originName: r[7] as String?,
      destinationName: r[8] as String?,
    );
  }

  DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
