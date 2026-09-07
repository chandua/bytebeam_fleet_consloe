import 'package:bytebeam_fleet_consloe/domain/models/geofence.dart';
import 'package:bytebeam_fleet_consloe/domain/services/geofence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = GeofenceEngine();

  final depot = Geofence(
    id: 'depot',
    name: 'Depot',
    lat: 0,
    lng: 0,
    radiusMeters: 200,
    active: true,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final hub = Geofence(
    id: 'hub',
    name: 'Hub',
    lat: 0.01,
    lng: 0,
    radiusMeters: 200,
    active: true,
    createdAt: DateTime.utc(2026, 1, 2),
  );

  LocationSample at(
    double lat,
    double lng,
    int minute, {
    double accuracy = 10,
  }) {
    return LocationSample(
      lat: lat,
      lng: lng,
      eventTime: DateTime.utc(2026, 9, 6, 10, minute),
      accuracyMeters: accuracy,
    );
  }

  test('requires two agreeing samples before confirming exit/enter', () {
    final transitions = engine.process(
      vehicleId: 'v1',
      startingGeofenceId: depot.id,
      activeGeofences: [depot, hub],
      samples: [
        at(0, 0, 0),
        at(0.01, 0, 1),
      ],
    );
    expect(transitions, isEmpty);

    final confirmed = engine.process(
      vehicleId: 'v1',
      startingGeofenceId: depot.id,
      activeGeofences: [depot, hub],
      samples: [
        at(0.01, 0, 1),
        at(0.01, 0, 2),
      ],
    );
    expect(confirmed.map((t) => t.type).toList(), [
      GeofenceTransitionType.exit,
      GeofenceTransitionType.enter,
    ]);
    expect(confirmed.first.geofenceId, depot.id);
    expect(confirmed.last.geofenceId, hub.id);
  });

  test('drops inaccurate GPS and ignores exact duplicates', () {
    final transitions = engine.process(
      vehicleId: 'v1',
      startingGeofenceId: depot.id,
      activeGeofences: [depot, hub],
      samples: [
        at(0.01, 0, 1, accuracy: 80),
        at(0.01, 0, 1, accuracy: 80),
        at(0.01, 0, 2),
        at(0.01, 0, 2),
        at(0.01, 0, 3),
      ],
    );
    expect(transitions.length, 2);
  });

  test('overlap prefers smaller radius', () {
    final big = Geofence(
      id: 'big',
      name: 'Big',
      lat: 0,
      lng: 0,
      radiusMeters: 2000,
      active: true,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final small = Geofence(
      id: 'small',
      name: 'Small',
      lat: 0,
      lng: 0,
      radiusMeters: 100,
      active: true,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    final pick = engine.containingFence(at(0, 0, 0), [big, small]);
    expect(pick?.id, 'small');
  });
}
