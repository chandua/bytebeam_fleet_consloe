
import 'package:bytebeam_fleet_consloe/data/database/fleet_database.dart';
import 'package:bytebeam_fleet_consloe/data/seed/demo_seed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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


