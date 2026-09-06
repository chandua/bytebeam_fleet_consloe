import 'package:bytebeam_fleet_consloe/providers/database_providers.dart';
import 'package:bytebeam_fleet_consloe/ui/router.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/theme/app_theme.dart';

class FleetApp extends ConsumerWidget {
  const FleetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(fleetDatabaseProvider);

    return MaterialApp.router(
      title: 'Fleet Console',
      theme: buildFleetTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: buildRouter(),
      builder: (context, child) {
        return db.when(
          loading: () => const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Opening local DuckDB…'),
                ],
              ),
            ),
          ),
          error: (e, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not open database:\n$e'),
              ),
            ),
          ),
          data: (_) => child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
