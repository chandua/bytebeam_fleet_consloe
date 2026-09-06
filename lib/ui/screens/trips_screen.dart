import 'package:bytebeam_fleet_consloe/providers/geofence_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(recentTripsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: trips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No trips recorded yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final t = items[i];
              final dest =
                  t.destinationName ?? (t.isActive ? 'In progress' : '—');
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  title: Text(
                    '${t.originName ?? 'Origin'} → $dest',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${t.vehicleId} · ${DateFormat.MMMd().add_Hm().format(t.startedAt.toLocal())}'
                    '${t.endedAt == null ? '' : ' → ${DateFormat.Hm().format(t.endedAt!.toLocal())}'}',
                  ),
                  trailing: Text(
                    t.isActive ? 'IN PROGRESS' : 'DONE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: t.isActive
                          ? Colors.teal.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
