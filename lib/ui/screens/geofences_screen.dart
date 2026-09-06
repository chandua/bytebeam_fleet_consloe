
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/geofence.dart';
import '../../providers/geofence_providers.dart';

class GeofencesScreen extends ConsumerWidget {
  const GeofencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(geofenceListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Geofences')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New fence'),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No geofences yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = items[i];
              final g = item.geofence;
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  title: Text(
                    g.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: g.active ? null : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    '${g.lat.toStringAsFixed(4)}, ${g.lng.toStringAsFixed(4)}'
                    ' · ${g.radiusMeters.toStringAsFixed(0)} m'
                    ' · ${item.vehicleCount} vehicles'
                    '${g.active ? '' : ' · deactivated'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _openEditor(context, ref, existing: g);
                      } else if (value == 'deactivate' && g.active) {
                        await ref
                            .read(geofenceActionsProvider)
                            .deactivate(g.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (g.active)
                        const PopupMenuItem(
                          value: 'deactivate',
                          child: Text('Deactivate'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Geofence? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final latCtrl =
        TextEditingController(text: existing?.lat.toString() ?? '12.9716');
    final lngCtrl =
        TextEditingController(text: existing?.lng.toString() ?? '77.5946');
    final radiusCtrl = TextEditingController(
      text: existing?.radiusMeters.toString() ?? '400',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Create geofence' : 'Edit geofence'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: latCtrl,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: lngCtrl,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: radiusCtrl,
                decoration: const InputDecoration(labelText: 'Radius (m)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final lat = double.tryParse(latCtrl.text.trim());
    final lng = double.tryParse(lngCtrl.text.trim());
    final radius = double.tryParse(radiusCtrl.text.trim());
    final name = nameCtrl.text.trim();
    if (name.isEmpty || lat == null || lng == null || radius == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check the fields and try again')),
        );
      }
      return;
    }

    final actions = ref.read(geofenceActionsProvider);
    if (existing == null) {
      await actions.create(
        name: name,
        lat: lat,
        lng: lng,
        radiusMeters: radius,
      );
    } else {
      await actions.update(
        existing.copyWith(
          name: name,
          lat: lat,
          lng: lng,
          radiusMeters: radius,
        ),
      );
    }
  }
}
