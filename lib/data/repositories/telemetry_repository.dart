
import 'package:bytebeam_fleet_consloe/core/constants.dart';
import 'package:bytebeam_fleet_consloe/core/sql.dart';
import 'package:bytebeam_fleet_consloe/data/database/fleet_database.dart';
import 'package:bytebeam_fleet_consloe/domain/models/signal.dart';
import 'package:bytebeam_fleet_consloe/domain/services/signal_verdict.dart';
import 'package:uuid/uuid.dart';

class TelemetryRepository {
  TelemetryRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FleetDatabase _db;
  final DateTime Function() _clock;
  final _uuid = const Uuid();
  final _verdicts = const SignalVerdictResolver();

  Future<void> ingestPacket({
    required String vehicleId,
    required DateTime eventTime,
    required Map<SignalKind, double> values,
    DateTime? ingestedAt,
  }) async {
    final ingested = (ingestedAt ?? _clock()).toUtc();
    final event = eventTime.toUtc();

    // Always stamp last_ping from the packet's event time.
    final payload = Map<SignalKind, double>.from(values);
    // last_ping is stored as the event_time; value unused.
    final buffer = StringBuffer();
    buffer.writeln('BEGIN TRANSACTION;');

    void addRow(SignalKind kind, double? value) {
      final id = _uuid.v4();
      buffer.writeln('''
        INSERT INTO signals (id, vehicle_id, signal, value, event_time, ingested_at)
        VALUES (
          ${sqlString(id)},
          ${sqlString(vehicleId)},
          ${sqlString(kind.storageKey)},
          ${sqlNullableNum(value)},
          ${sqlTimestamp(event)},
          ${sqlTimestamp(ingested)}
        );
      ''');
    }

    for (final entry in payload.entries) {
      addRow(entry.key, entry.value);
    }
    addRow(SignalKind.lastPing, 1);

    buffer.writeln('COMMIT;');
    await _db.execute(buffer.toString());
  }

  Future<void> ingestMany(List<SignalInsert> rows) async {
    if (rows.isEmpty) return;
    // Chunk to keep statements manageable.
    const chunk = 500;
    for (var i = 0; i < rows.length; i += chunk) {
      final slice = rows.sublist(i, i + chunk > rows.length ? rows.length : i + chunk);
      final buf = StringBuffer('BEGIN TRANSACTION;\n');
      for (final row in slice) {
        buf.writeln('''
          INSERT INTO signals (id, vehicle_id, signal, value, event_time, ingested_at)
          VALUES (
            ${sqlString(row.id)},
            ${sqlString(row.vehicleId)},
            ${sqlString(row.signal.storageKey)},
            ${sqlNullableNum(row.value)},
            ${sqlTimestamp(row.eventTime)},
            ${sqlTimestamp(row.ingestedAt)}
          );
        ''');
      }
      buf.writeln('COMMIT;');
      await _db.execute(buf.toString());
    }
  }

  Future<List<SignalReading>> readingsForVehicle(String vehicleId) async {
    final now = _clock().toUtc();
    final kinds = [
      SignalKind.soc,
      SignalKind.rangeKm,
      SignalKind.speed,
      SignalKind.batteryTemp,
      SignalKind.odometer,
      SignalKind.lastPing,
    ];

    final readings = <SignalReading>[];
    for (final kind in kinds) {
      final rows = await _db.fetchAll('''
        SELECT value, event_time
        FROM signals
        WHERE vehicle_id = ${sqlString(vehicleId)}
          AND signal = ${sqlString(kind.storageKey)}
        ORDER BY event_time DESC
        LIMIT 1
      ''');

      if (rows.isEmpty) {
        readings.add(SignalReading(kind: kind));
        continue;
      }

      final value = (rows.first[0] as num?)?.toDouble();
      final at = _asDateTime(rows.first[1]);
      final alert = _verdicts.isAlertCondition(kind, value);
      readings.add(
        SignalReading(
          kind: kind,
          value: kind == SignalKind.lastPing ? null : value,
          eventTime: at,
          verdict: _verdicts.verdict(
            value: value,
            eventTime: at,
            kind: kind,
            now: now,
            alertCondition: alert,
          ),
        ),
      );
    }
    return readings;
  }

  Future<List<SocHistoryPoint>> socHistory(
    String vehicleId, {
    Duration window = FleetConstants.signalRetention,
  }) async {
    final since = _clock().toUtc().subtract(window);
    final rows = await _db.fetchAll('''
      SELECT event_time, value
      FROM signals
      WHERE vehicle_id = ${sqlString(vehicleId)}
        AND signal = 'soc'
        AND event_time >= ${sqlTimestamp(since)}
        AND value IS NOT NULL
      ORDER BY event_time ASC
    ''');

    return rows
        .map(
          (r) => SocHistoryPoint(
            at: _asDateTime(r[0])!,
            soc: (r[1] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<Map<SignalKind, ({double? value, DateTime eventTime})>> latestMap(
    String vehicleId,
  ) async {
    final rows = await _db.fetchAll('''
      SELECT signal, value, event_time
      FROM (
        SELECT signal, value, event_time,
               ROW_NUMBER() OVER (PARTITION BY signal ORDER BY event_time DESC) rn
        FROM signals
        WHERE vehicle_id = ${sqlString(vehicleId)}
      )
      WHERE rn = 1
    ''');

    final map = <SignalKind, ({double? value, DateTime eventTime})>{};
    for (final r in rows) {
      final kind = SignalKind.fromStorageKey(r[0]! as String);
      if (kind == null) continue;
      final at = _asDateTime(r[2]);
      if (at == null) continue;
      map[kind] = (value: (r[1] as num?)?.toDouble(), eventTime: at);
    }
    return map;
  }

  Future<List<LocationPoint>> locationHistory(
    String vehicleId, {
    Duration window = const Duration(hours: 24),
  }) async {
    final since = _clock().toUtc().subtract(window);
    final rows = await _db.fetchAll('''
      WITH lat_rows AS (
        SELECT event_time, value AS lat
        FROM signals
        WHERE vehicle_id = ${sqlString(vehicleId)}
          AND signal = 'lat'
          AND event_time >= ${sqlTimestamp(since)}
      ),
      lng_rows AS (
        SELECT event_time, value AS lng
        FROM signals
        WHERE vehicle_id = ${sqlString(vehicleId)}
          AND signal = 'lng'
          AND event_time >= ${sqlTimestamp(since)}
      ),
      acc_rows AS (
        SELECT event_time, value AS accuracy
        FROM signals
        WHERE vehicle_id = ${sqlString(vehicleId)}
          AND signal = 'gps_accuracy'
          AND event_time >= ${sqlTimestamp(since)}
      )
      SELECT l.event_time, l.lat, g.lng, a.accuracy
      FROM lat_rows l
      JOIN lng_rows g ON g.event_time = l.event_time
      LEFT JOIN acc_rows a ON a.event_time = l.event_time
      ORDER BY l.event_time ASC
    ''');

    return rows
        .map(
          (r) => LocationPoint(
            eventTime: _asDateTime(r[0])!,
            lat: (r[1] as num).toDouble(),
            lng: (r[2] as num).toDouble(),
            accuracyMeters: (r[3] as num?)?.toDouble(),
          ),
        )
        .toList();
  }

  Future<int> compactOldSignals() async {
    final cutoff = _clock().toUtc().subtract(FleetConstants.signalRetention);
    final before = await _db.fetchScalar('SELECT COUNT(*) FROM signals');
    await _db.execute('''
      DELETE FROM signals
      WHERE event_time < ${sqlTimestamp(cutoff)}
        AND signal NOT IN ('last_ping')
    ''');
    // Keep one last_ping even if old — fleet status needs it.
    final after = await _db.fetchScalar('SELECT COUNT(*) FROM signals');
    return ((before as num?)?.toInt() ?? 0) - ((after as num?)?.toInt() ?? 0);
  }

  Future<int> signalCount() async {
    final n = await _db.fetchScalar('SELECT COUNT(*) FROM signals');
    return (n as num?)?.toInt() ?? 0;
  }

  DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}

class SignalInsert {
  SignalInsert({
    required this.id,
    required this.vehicleId,
    required this.signal,
    required this.value,
    required this.eventTime,
    required this.ingestedAt,
  });

  final String id;
  final String vehicleId;
  final SignalKind signal;
  final double? value;
  final DateTime eventTime;
  final DateTime ingestedAt;
}

class LocationPoint {
  const LocationPoint({
    required this.lat,
    required this.lng,
    required this.eventTime,
    this.accuracyMeters,
  });

  final double lat;
  final double lng;
  final DateTime eventTime;
  final double? accuracyMeters;
}
