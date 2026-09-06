import 'package:fleet_console/core/sql.dart';
import 'package:fleet_console/data/database/fleet_database.dart';
import 'package:fleet_console/domain/models/geofence.dart';
import 'package:fleet_console/domain/services/geofence_engine.dart';
import 'package:uuid/uuid.dart';

class GeofenceRepository {
  GeofenceRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FleetDatabase _db;
  final DateTime Function() _clock;
  final _uuid = const Uuid();
  final _engine = const GeofenceEngine();

  Future<List<Geofence>> listAll({bool activeOnly = false}) async {
    final where = activeOnly ? 'WHERE active = TRUE' : '';
    final rows = await _db.fetchAll('''
      SELECT id, name, lat, lng, radius_meters, active, created_at, deactivated_at
      FROM geofences
      $where
      ORDER BY name
    ''');
    return rows.map(_map).toList();
  }

  Future<List<GeofenceWithCount>> listWithCounts() async {
    final rows = await _db.fetchAll('''
      SELECT g.id, g.name, g.lat, g.lng, g.radius_meters, g.active,
             g.created_at, g.deactivated_at,
             COALESCE(c.cnt, 0) AS vehicle_count
      FROM geofences g
      LEFT JOIN (
        SELECT geofence_id, COUNT(*) AS cnt
        FROM vehicle_geofence
        WHERE geofence_id IS NOT NULL
        GROUP BY geofence_id
      ) c ON c.geofence_id = g.id
      ORDER BY g.active DESC, g.name
    ''');

    return rows
        .map(
          (r) => GeofenceWithCount(
            geofence: _map(r),
            vehicleCount: (r[8] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<Geofence?> get(String id) async {
    final rows = await _db.fetchAll('''
      SELECT id, name, lat, lng, radius_meters, active, created_at, deactivated_at
      FROM geofences WHERE id = ${sqlString(id)}
    ''');
    if (rows.isEmpty) return null;
    return _map(rows.first);
  }

  Future<String> create({
    required String name,
    required double lat,
    required double lng,
    required double radiusMeters,
  }) async {
    final id = _uuid.v4();
    final now = _clock().toUtc();
    await _db.execute('''
      INSERT INTO geofences (
        id, name, lat, lng, radius_meters, active, created_at, deactivated_at
      ) VALUES (
        ${sqlString(id)},
        ${sqlString(name)},
        $lat, $lng, $radiusMeters,
        TRUE,
        ${sqlTimestamp(now)},
        NULL
      )
    ''');
    return id;
  }

  Future<void> update(Geofence fence) async {
    await _db.execute('''
      UPDATE geofences SET
        name = ${sqlString(fence.name)},
        lat = ${fence.lat},
        lng = ${fence.lng},
        radius_meters = ${fence.radiusMeters},
        active = ${sqlBool(fence.active)},
        deactivated_at = ${fence.deactivatedAt == null ? 'NULL' : sqlTimestamp(fence.deactivatedAt!)}
      WHERE id = ${sqlString(fence.id)}
    ''');
  }

  Future<void> deactivate(String id) async {
    final now = _clock().toUtc();
    await _db.execute('''
      UPDATE geofences
      SET active = FALSE, deactivated_at = ${sqlTimestamp(now)}
      WHERE id = ${sqlString(id)}
    ''');
  }

  Future<String?> currentGeofenceId(String vehicleId) async {
    final v = await _db.fetchScalar('''
      SELECT geofence_id FROM vehicle_geofence
      WHERE vehicle_id = ${sqlString(vehicleId)}
    ''');
    return v as String?;
  }

  Future<void> setCurrentGeofence(String vehicleId, String? geofenceId) async {
    await _db.execute('''
      INSERT INTO vehicle_geofence (vehicle_id, geofence_id)
      VALUES (${sqlString(vehicleId)}, ${sqlNullableString(geofenceId)})
      ON CONFLICT (vehicle_id) DO UPDATE SET geofence_id = excluded.geofence_id
    ''');
  }

  /// Replays location history through the engine and persists confirmed transitions.
  Future<List<ProposedTransition>> recomputeVehicle({
    required String vehicleId,
    required List<LocationSample> samples,
  }) async {
    final fences = await listAll(activeOnly: true);
    final starting = await currentGeofenceId(vehicleId);
    final proposed = _engine.process(
      vehicleId: vehicleId,
      samples: samples,
      activeGeofences: fences,
      startingGeofenceId: starting,
    );

    for (final t in proposed) {
      await _insertTransition(t);
    }

    if (samples.isNotEmpty) {
      final last = [...samples]..sort((a, b) => a.eventTime.compareTo(b.eventTime));
      final membership = _engine.containingFence(last.last, fences);
      await setCurrentGeofence(vehicleId, membership?.id);
    }

    return proposed;
  }

  Future<void> _insertTransition(ProposedTransition t) async {
    // Idempotent: same key → ignore.
    final existing = await _db.fetchScalar('''
      SELECT id FROM geofence_transitions WHERE id = ${sqlString(t.idempotencyKey)}
    ''');
    if (existing != null) return;

    await _db.execute('''
      INSERT INTO geofence_transitions (
        id, vehicle_id, geofence_id, type, event_time, confirmed
      ) VALUES (
        ${sqlString(t.idempotencyKey)},
        ${sqlString(t.vehicleId)},
        ${sqlString(t.geofenceId)},
        ${sqlString(t.type.name)},
        ${sqlTimestamp(t.eventTime)},
        TRUE
      )
    ''');
  }

  Future<List<ProposedTransition>> confirmedTransitions(
    String vehicleId, {
    DateTime? since,
  }) async {
    final sinceClause = since == null
        ? ''
        : 'AND event_time >= ${sqlTimestamp(since.toUtc())}';
    final rows = await _db.fetchAll('''
      SELECT id, vehicle_id, geofence_id, type, event_time
      FROM geofence_transitions
      WHERE vehicle_id = ${sqlString(vehicleId)}
        AND confirmed = TRUE
        $sinceClause
      ORDER BY event_time ASC
    ''');

    return rows
        .map(
          (r) => ProposedTransition(
            vehicleId: r[1]! as String,
            geofenceId: r[2]! as String,
            type: (r[3]! as String) == 'enter'
                ? GeofenceTransitionType.enter
                : GeofenceTransitionType.exit,
            eventTime: _asDateTime(r[4])!,
          ),
        )
        .toList();
  }

  Geofence _map(List<Object?> r) {
    return Geofence(
      id: r[0]! as String,
      name: r[1]! as String,
      lat: (r[2] as num).toDouble(),
      lng: (r[3] as num).toDouble(),
      radiusMeters: (r[4] as num).toDouble(),
      active: r[5] == true || r[5] == 1,
      createdAt: _asDateTime(r[6])!,
      deactivatedAt: _asDateTime(r[7]),
    );
  }

  DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
