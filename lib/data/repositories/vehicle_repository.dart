
import 'package:bytebeam_fleet_consloe/core/constants.dart';
import 'package:bytebeam_fleet_consloe/core/sql.dart';
import 'package:bytebeam_fleet_consloe/data/database/fleet_database.dart';
import 'package:bytebeam_fleet_consloe/data/database/schema.dart';
import 'package:bytebeam_fleet_consloe/domain/models/vehicle.dart';
import 'package:bytebeam_fleet_consloe/domain/models/vehicle_status.dart';
import 'package:uuid/uuid.dart';

class VehicleRepository {
  VehicleRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FleetDatabase _db;
  final DateTime Function() _clock;
  final _uuid = const Uuid();

  Future<void> upsertVehicle({
    required String id,
    required String regNumber,
    required String model,
  }) async {
    await _db.execute('''
      INSERT INTO vehicles (id, reg_number, model)
      VALUES (${sqlString(id)}, ${sqlString(regNumber)}, ${sqlString(model)})
      ON CONFLICT (id) DO UPDATE SET
        reg_number = excluded.reg_number,
        model = excluded.model
    ''');
  }

  Future<int> vehicleCount() async {
    final n = await _db.fetchScalar('SELECT COUNT(*) FROM vehicles');
    return (n as num?)?.toInt() ?? 0;
  }

  Future<FleetFilterCounts> filterCounts() async {
    // Derive from the same list SQL so we never need SUM() (core_functions).
    final items = await list();
    var moving = 0, idle = 0, stopped = 0, offline = 0;
    for (final item in items) {
      switch (item.status) {
        case VehicleStatus.moving:
          moving++;
        case VehicleStatus.idle:
          idle++;
        case VehicleStatus.stopped:
          stopped++;
        case VehicleStatus.offline:
          offline++;
      }
    }
    return FleetFilterCounts(
      all: items.length,
      moving: moving,
      idle: idle,
      stopped: stopped,
      offline: offline,
    );
  }

  Future<List<VehicleListItem>> list({VehicleStatus? filter}) async {
    final now = _clock().toUtc();
    final offlineBefore = now.subtract(FleetConstants.offlineAfter);
    final base = FleetSchema.fleetListSql(
      offlineBeforeIso: sqlTimestampLiteral(offlineBefore),
    );
    final where = filter == null
        ? ''
        : 'WHERE status = ${sqlString(filter.sqlValue)}';
    final rows = await _db.fetchAll('''
      $base
      SELECT id, reg_number, model, status, soc, range_km, speed, ignition,
             last_ping, active_alert_count, geofence_name
      FROM ranked
      $where
      ORDER BY reg_number
    ''');

    return rows.map((r) {
      return VehicleListItem(
        id: r[0]! as String,
        regNumber: r[1]! as String,
        model: r[2]! as String,
        status: VehicleStatus.fromSql(r[3] as String?) ?? VehicleStatus.offline,
        soc: (r[4] as num?)?.toDouble(),
        rangeKm: (r[5] as num?)?.toDouble(),
        speed: (r[6] as num?)?.toDouble(),
        ignitionOn: r[7] == null ? null : ((r[7] as num) >= 1),
        lastPing: _asDateTime(r[8]),
        activeAlertCount: (r[9] as num?)?.toInt() ?? 0,
        currentGeofenceName: r[10] as String?,
      );
    }).toList();
  }

  Future<Vehicle?> get(String id) async {
    final rows = await _db.fetchAll('''
      SELECT id, reg_number, model FROM vehicles WHERE id = ${sqlString(id)}
    ''');
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Vehicle(
      id: r[0]! as String,
      regNumber: r[1]! as String,
      model: r[2]! as String,
    );
  }

  Future<List<String>> listIds() async {
    final rows = await _db.fetchAll('SELECT id FROM vehicles ORDER BY id');
    return rows.map((r) => r[0]! as String).toList();
  }

  String newId() => _uuid.v4();

  DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
