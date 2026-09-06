
import 'package:bytebeam_fleet_consloe/app.dart';
import 'package:bytebeam_fleet_consloe/core/duckdb_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDuckDbNative();
  runApp(
    const ProviderScope(
      child: FleetApp(),
    ),
  );
}
