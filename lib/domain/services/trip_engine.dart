import 'package:bytebeam_fleet_consloe/domain/models/geofence.dart';
import 'package:bytebeam_fleet_consloe/domain/models/trip.dart';
import 'package:bytebeam_fleet_consloe/domain/services/geofence_engine.dart';


/// Builds trips from confirmed geofence transitions.
///
/// Confirmed exit starts a trip. The next confirmed enter completes it.
/// Returning to the origin fence is valid. One active trip per vehicle.
/// Replay is idempotent via transition keys; late packets may revise the
/// destination / end time of an open or recently completed trip when the
/// event time falls inside the trip window — but never create a second trip
/// for the same exit.
class TripEngine {
  const TripEngine();

  List<TripMutation> apply({
    required String vehicleId,
    required List<ProposedTransition> confirmed,
    Trip? activeTrip,
  }) {
    final mutations = <TripMutation>[];
    var open = activeTrip;

    final ordered = [...confirmed]
      ..sort((a, b) => a.eventTime.compareTo(b.eventTime));

    for (final t in ordered) {
      if (!t.confirmedLike) continue;

      if (t.type == GeofenceTransitionType.exit) {
        if (open != null && open.isActive) {
          // Already on a trip — ignore nested exits until we enter somewhere.
          continue;
        }
        mutations.add(
          TripMutation.start(
            vehicleId: vehicleId,
            originGeofenceId: t.geofenceId,
            startedAt: t.eventTime,
            sourceKey: t.idempotencyKey,
          ),
        );
        open = Trip(
          id: 'pending',
          vehicleId: vehicleId,
          originGeofenceId: t.geofenceId,
          startedAt: t.eventTime,
          status: TripStatus.inProgress,
        );
      } else if (t.type == GeofenceTransitionType.enter) {
        if (open == null || !open.isActive) continue;
        if (t.eventTime.isBefore(open.startedAt)) continue;

        mutations.add(
          TripMutation.complete(
            vehicleId: vehicleId,
            destinationGeofenceId: t.geofenceId,
            endedAt: t.eventTime,
            sourceKey: t.idempotencyKey,
          ),
        );
        open = null;
      }
    }

    return mutations;
  }
}

extension on ProposedTransition {
  // Proposed transitions from GeofenceEngine are already "confirmed".
  bool get confirmedLike => true;
}

sealed class TripMutation {
  const TripMutation();

  factory TripMutation.start({
    required String vehicleId,
    required String originGeofenceId,
    required DateTime startedAt,
    required String sourceKey,
  }) = TripStart;

  factory TripMutation.complete({
    required String vehicleId,
    required String destinationGeofenceId,
    required DateTime endedAt,
    required String sourceKey,
  }) = TripComplete;
}

class TripStart extends TripMutation {
  const TripStart({
    required this.vehicleId,
    required this.originGeofenceId,
    required this.startedAt,
    required this.sourceKey,
  });

  final String vehicleId;
  final String originGeofenceId;
  final DateTime startedAt;
  final String sourceKey;
}

class TripComplete extends TripMutation {
  const TripComplete({
    required this.vehicleId,
    required this.destinationGeofenceId,
    required this.endedAt,
    required this.sourceKey,
  });

  final String vehicleId;
  final String destinationGeofenceId;
  final DateTime endedAt;
  final String sourceKey;
}
