import 'dart:io';

import 'package:bytebeam_fleet_consloe/core/duckdb_bootstrap.dart';
import 'package:bytebeam_fleet_consloe/data/database/fleet_database.dart';
import 'package:bytebeam_fleet_consloe/data/repositories/vehicle_repository.dart';
import 'package:bytebeam_fleet_consloe/data/seed/demo_seed.dart';
import 'package:bytebeam_fleet_consloe/data/seed/scale_backfill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// One-shot scale measurements for the README.
/// Run: `flutter test tool/measure_scale_manual_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureDuckDbNative();

  test('measure scale metrics', () async {
    final dir = await Directory.systemTemp.createTemp('fleet_scale_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final dbPath = p.join(dir.path, 'measure.duckdb');

    final coldWatch = Stopwatch()..start();
    final db = await FleetDatabase.open(overridePath: dbPath);
    addTearDown(db.dispose);
    await DemoSeed(db: db).runIfNeeded();
    final vehicles = VehicleRepository(db);
    await vehicles.list();
    coldWatch.stop();

    // ignore: avoid_print
    print('cold_open_seed_first_list_ms=${coldWatch.elapsedMilliseconds}');

    final backfill = await ScaleBackfill(db).run(
      onProgress: (progress, label) {
        // ignore: avoid_print
        print('  ${(progress * 100).toStringAsFixed(0)}% $label');
      },
    );
    // ignore: avoid_print
    print(
      'backfill_vehicles=${backfill.vehicles} '
      'backfill_signals=${backfill.signalRows} '
      'backfill_s=${backfill.elapsed.inSeconds}',
    );

    for (var i = 0; i < 5; i++) {
      await vehicles.list();
    }
    final samples = <int>[];
    for (var i = 0; i < 40; i++) {
      final sw = Stopwatch()..start();
      final rows = await vehicles.list();
      sw.stop();
      samples.add(sw.elapsedMilliseconds);
      if (i == 0) {
        // ignore: avoid_print
        print('fleet_list_rows=${rows.length}');
      }
    }
    samples.sort();
    int pct(int p) =>
        samples[(samples.length * p / 100).floor().clamp(0, samples.length - 1)];

    final rssMb = ProcessInfo.currentRss / (1024 * 1024);
    // ignore: avoid_print
    print('list_p50_ms=${pct(50)}');
    // ignore: avoid_print
    print('list_p95_ms=${pct(95)}');
    // ignore: avoid_print
    print('rss_mb=${rssMb.toStringAsFixed(0)}');
    // ignore: avoid_print
    print(
      'device=macOS ${Platform.operatingSystemVersion}; Apple M3 arm64; 8 GB RAM',
    );

    expect(backfill.vehicles, 500);
    expect(backfill.signalRows, greaterThan(1_000_000));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
