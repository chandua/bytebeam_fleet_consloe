import 'package:bytebeam_fleet_consloe/ui/screen/fleet_home_screen.dart';
import 'package:bytebeam_fleet_consloe/ui/screen/geofences_screen.dart';
import 'package:bytebeam_fleet_consloe/ui/screen/trips_screen.dart';
import 'package:bytebeam_fleet_consloe/ui/screen/vehicle_detail_screen.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const FleetHomeScreen(),
        routes: [
          GoRoute(
            path: 'vehicle/:id',
            builder: (context, state) => VehicleDetailScreen(
              vehicleId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'geofences',
            builder: (context, state) => const GeofencesScreen(),
          ),
          GoRoute(
            path: 'trips',
            builder: (context, state) => const TripsScreen(),
          ),
        ],
      ),
    ],
  );
}
