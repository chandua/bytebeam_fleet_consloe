
import 'package:bytebeam_fleet_consloe/domain/models/vehicle.dart';
import 'package:bytebeam_fleet_consloe/domain/models/vehicle_status.dart';
import 'package:bytebeam_fleet_consloe/providers/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FleetFilterNotifier extends Notifier<VehicleStatus?> {
  @override
  VehicleStatus? build() => null;

  void setFilter(VehicleStatus? status) => state = status;
}

final fleetFilterProvider =
    NotifierProvider<FleetFilterNotifier, VehicleStatus?>(
  FleetFilterNotifier.new,
);

final fleetCountsProvider = FutureProvider<FleetFilterCounts>((ref) async {
  // Touch the DB so we don't race before seed finishes.
  await ref.watch(fleetDatabaseProvider.future);
  return ref.read(vehicleRepositoryProvider).filterCounts();
});

final fleetListProvider = FutureProvider<List<VehicleListItem>>((ref) async {
  await ref.watch(fleetDatabaseProvider.future);
  final filter = ref.watch(fleetFilterProvider);
  return ref.read(vehicleRepositoryProvider).list(filter: filter);
});
