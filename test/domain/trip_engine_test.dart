import 'package:bytebeam_fleet_consloe/domain/models/geofence.dart';
import 'package:bytebeam_fleet_consloe/domain/models/trip.dart';
import 'package:bytebeam_fleet_consloe/domain/services/geofence_engine.dart';
import 'package:bytebeam_fleet_consloe/domain/services/trip_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = TripEngine();

  ProposedTransition exitAt(int minute) => ProposedTransition(
        vehicleId: 'v1',
        geofenceId: 'depot',
        type: GeofenceTransitionType.exit,
        eventTime: DateTime.utc(2026, 9, 6, 10, minute),
      );

  ProposedTransition enterHubAt(int minute) => ProposedTransition(
        vehicleId: 'v1',
        geofenceId: 'hub',
        type: GeofenceTransitionType.enter,
        eventTime: DateTime.utc(2026, 9, 6, 10, minute),
      );

  test('exit starts a trip and enter completes it', () {
    final mutations = engine.apply(
      vehicleId: 'v1',
      confirmed: [exitAt(0), enterHubAt(20)],
    );

    expect(mutations, hasLength(2));
    expect(mutations[0], isA<TripStart>());
    expect(mutations[1], isA<TripComplete>());
    final complete = mutations[1] as TripComplete;
    expect(complete.destinationGeofenceId, 'hub');
  });

  test('second exit while trip is open is ignored', () {
    final open = Trip(
      id: 't1',
      vehicleId: 'v1',
      originGeofenceId: 'depot',
      startedAt: DateTime.utc(2026, 9, 6, 10),
      status: TripStatus.inProgress,
    );

    final mutations = engine.apply(
      vehicleId: 'v1',
      activeTrip: open,
      confirmed: [exitAt(5), enterHubAt(30)],
    );

    expect(mutations, hasLength(1));
    expect(mutations.single, isA<TripComplete>());
  });

  test('returning to origin is a valid completion', () {
    final mutations = engine.apply(
      vehicleId: 'v1',
      confirmed: [
        exitAt(0),
        ProposedTransition(
          vehicleId: 'v1',
          geofenceId: 'depot',
          type: GeofenceTransitionType.enter,
          eventTime: DateTime.utc(2026, 9, 6, 10, 40),
        ),
      ],
    );

    final complete = mutations.whereType<TripComplete>().single;
    expect(complete.destinationGeofenceId, 'depot');
  });
}
