
import 'package:bytebeam_fleet_consloe/core/sql.dart';
import 'package:bytebeam_fleet_consloe/data/database/fleet_database.dart';
import 'package:uuid/uuid.dart';

class AlertRepository {
  AlertRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FleetDatabase _db;
  final DateTime Function() _clock;
  final _uuid = const Uuid();
  final _engine = const AlertEngine();

  Future<List<FleetAlert>> activeForVehicle(String vehicleId) async {
    final rows = await _db.fetchAll('''
      SELECT id, vehicle_id, kind, severity, message, triggered_at,
             resolved_at, dismissed_at, dismiss_reason
      FROM alerts
      WHERE vehicle_id = ${sqlString(vehicleId)}
        AND resolved_at IS NULL
        AND dismissed_at IS NULL
      ORDER BY triggered_at DESC
    ''');
    return rows.map(_map).toList();
  }

  Future<List<FleetAlert>> activeAll() async {
    final rows = await _db.fetchAll('''
      SELECT id, vehicle_id, kind, severity, message, triggered_at,
             resolved_at, dismissed_at, dismiss_reason
      FROM alerts
      WHERE resolved_at IS NULL AND dismissed_at IS NULL
      ORDER BY
        CASE severity WHEN 'critical' THEN 0 ELSE 1 END,
        triggered_at DESC
    ''');
    return rows.map(_map).toList();
  }

  Future<FleetAlert?> getById(String id) async {
    final rows = await _db.fetchAll('''
      SELECT id, vehicle_id, kind, severity, message, triggered_at,
             resolved_at, dismissed_at, dismiss_reason
      FROM alerts
      WHERE id = ${sqlString(id)}
    ''');
    if (rows.isEmpty) return null;
    return _map(rows.first);
  }

  Future<void> applyIntents(List<AlertIntent> intents) async {
    final now = _clock().toUtc();
    for (final intent in intents) {
      final existing = await _findOpen(intent.vehicleId, intent.kind);

      if (!intent.conditionActive) {
        if (existing != null) {
          await _db.execute('''
            UPDATE alerts
            SET resolved_at = ${sqlTimestamp(now)}
            WHERE id = ${sqlString(existing.id)}
              AND resolved_at IS NULL
              AND dismissed_at IS NULL
          ''');
        }
        continue;
      }

      if (existing == null) {
        final id = _uuid.v4();
        await _db.execute('''
          INSERT INTO alerts (
            id, vehicle_id, kind, severity, message, triggered_at,
            resolved_at, dismissed_at, dismiss_reason
          ) VALUES (
            ${sqlString(id)},
            ${sqlString(intent.vehicleId)},
            ${sqlString(intent.kind.storageKey)},
            ${sqlString(intent.severity.name)},
            ${sqlString(intent.message)},
            ${sqlTimestamp(now)},
            NULL, NULL, NULL
          )
        ''');
      } else if (existing.severity != intent.severity ||
          existing.message != intent.message) {
        await _db.execute('''
          UPDATE alerts
          SET severity = ${sqlString(intent.severity.name)},
              message = ${sqlString(intent.message)}
          WHERE id = ${sqlString(existing.id)}
        ''');
      }
    }
  }

  Future<void> evaluateFromLatest(
    String vehicleId,
    Map<SignalKind, SignalSnapshot> latest,
  ) async {
    await applyIntents(
      _engine.evaluate(
        vehicleId: vehicleId,
        latest: latest,
        now: _clock().toUtc(),
      ),
    );
  }

  Future<void> dismiss({
    required String alertId,
    required String reason,
  }) async {
    final now = _clock().toUtc();
    await _db.execute('''
      UPDATE alerts
      SET dismissed_at = ${sqlTimestamp(now)},
          dismiss_reason = ${sqlString(reason)}
      WHERE id = ${sqlString(alertId)}
        AND dismissed_at IS NULL
        AND resolved_at IS NULL
    ''');
  }

  Future<void> undoDismiss(String alertId) async {
    await _db.execute('''
      UPDATE alerts
      SET dismissed_at = NULL,
          dismiss_reason = NULL
      WHERE id = ${sqlString(alertId)}
    ''');
  }

  Future<FleetAlert?> _findOpen(String vehicleId, AlertKind kind) async {
    final rows = await _db.fetchAll('''
      SELECT id, vehicle_id, kind, severity, message, triggered_at,
             resolved_at, dismissed_at, dismiss_reason
      FROM alerts
      WHERE vehicle_id = ${sqlString(vehicleId)}
        AND kind = ${sqlString(kind.storageKey)}
        AND resolved_at IS NULL
        AND dismissed_at IS NULL
      ORDER BY triggered_at DESC
      LIMIT 1
    ''');
    if (rows.isEmpty) return null;
    return _map(rows.first);
  }

  FleetAlert _map(List<Object?> r) {
    return FleetAlert(
      id: r[0]! as String,
      vehicleId: r[1]! as String,
      kind: AlertKind.fromStorage(r[2]! as String)!,
      severity: (r[3]! as String) == 'critical'
          ? AlertSeverity.critical
          : AlertSeverity.warning,
      message: r[4]! as String,
      triggeredAt: _asDateTime(r[5])!,
      resolvedAt: _asDateTime(r[6]),
      dismissedAt: _asDateTime(r[7]),
      dismissReason: r[8] as String?,
    );
  }

  DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
