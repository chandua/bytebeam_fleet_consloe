import 'dart:io';

import 'package:bytebeam_fleet_consloe/data/database/schema.dart';
import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns the on-disk DuckDB file. Everything the app "knows" lives here.
class FleetDatabase {
  FleetDatabase._(this._db, this._conn, this.path);

  final Database _db;
  final Connection _conn;
  final String path;

  Connection get connection => _conn;

  static Future<FleetDatabase> open({String? overridePath}) async {
    final path = overridePath ?? await _defaultPath();
    final parent = Directory(p.dirname(path));
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }

    final db = await duckdb.open(path);
    final conn = await duckdb.connect(db);
    final fleet = FleetDatabase._(db, conn, path);
    await fleet._migrate();
    return fleet;
  }

  /// In-memory handle for unit tests.
  static Future<FleetDatabase> openInMemory() async {
    final db = await duckdb.open(':memory:');
    final conn = await duckdb.connect(db);
    final fleet = FleetDatabase._(db, conn, ':memory:');
    await fleet._migrate();
    return fleet;
  }

  static Future<String> _defaultPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'fleet_console.duckdb');
  }

  Future<void> _migrate() async {
    for (final stmt in FleetSchema.createStatements) {
      await _conn.execute(stmt);
    }
  }

  Future<void> execute(String sql) => _conn.execute(sql);

  Future<ResultSet> query(String sql) => _conn.query(sql);

  Future<List<List<Object?>>> fetchAll(String sql) async {
    final result = await _conn.query(sql);
    return result.fetchAll();
  }

  Future<Object?> fetchScalar(String sql) async {
    final rows = await fetchAll(sql);
    if (rows.isEmpty || rows.first.isEmpty) return null;
    return rows.first.first;
  }

  Future<void> dispose() async {
    await _conn.dispose();
    await _db.dispose();
  }
}
