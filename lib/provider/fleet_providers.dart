
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domin/model/vehicle_status.dart';

class FleetFilterNotifier extends Notifier<VehicleStatus?> {
  @override
  VehicleStatus? build() => null;

  void select(VehicleStatus? status) => state = status;
}

final fleetFilterProvider =
    NotifierProvider<FleetFilterNotifier, VehicleStatus?>(
  FleetFilterNotifier.new,
);


