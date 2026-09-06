import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/duckdb_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDuckDbNative();
  runApp(
    const ProviderScope(
      child: FleetApp(),
    ),
  );
}




