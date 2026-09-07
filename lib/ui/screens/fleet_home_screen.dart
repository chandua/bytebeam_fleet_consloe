
import 'package:bytebeam_fleet_consloe/providers/fleet_providers.dart';
import 'package:bytebeam_fleet_consloe/providers/geofence_providers.dart';
import 'package:bytebeam_fleet_consloe/providers/vehicle_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_status.dart';
import '../widgets/status_chip.dart';

class FleetHomeScreen extends ConsumerWidget {
  const FleetHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(fleetFilterProvider);
    final counts = ref.watch(fleetCountsProvider);
    final list = ref.watch(fleetListProvider);
    final undo = ref.watch(undoDismissProvider);
    final scale = ref.watch(scaleBackfillProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Console'),
        actions: [
          IconButton(
            tooltip: 'Geofences',
            onPressed: () => context.push('/geofences'),
            icon: const Icon(Icons.fence_outlined),
          ),
          IconButton(
            tooltip: 'Trips',
            onPressed: () => context.push('/trips'),
            icon: const Icon(Icons.route_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'scale') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Scale backfill'),
                    content: const Text(
                      'Writes 500 vehicles and ~2M signal rows into DuckDB. '
                      'This can take a few minutes.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Run'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(scaleBackfillProvider.notifier).run();
                }
              } else if (value == 'refresh') {
                ref.invalidate(fleetListProvider);
                ref.invalidate(fleetCountsProvider);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              PopupMenuItem(
                value: 'scale',
                child: Text('Scale backfill (500 / 2M)'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (scale.running || scale.resultSummary != null)
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    if (scale.running)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (scale.running) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scale.running
                            ? '${scale.label} (${(scale.progress * 100).toStringAsFixed(0)}%)'
                            : scale.resultSummary ?? '',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: counts.when(
              loading: () => const SizedBox(height: 40),
              error: (e, _) => Text(
                'Counts failed: $e',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (c) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      count: c.all,
                      selected: filter == null,
                      onTap: () =>
                          ref.read(fleetFilterProvider.notifier).setFilter(null),
                    ),
                    _FilterChip(
                      label: 'Moving',
                      count: c.moving,
                      selected: filter == VehicleStatus.moving,
                      onTap: () => ref
                          .read(fleetFilterProvider.notifier)
                          .setFilter(VehicleStatus.moving),
                    ),
                    _FilterChip(
                      label: 'Idle',
                      count: c.idle,
                      selected: filter == VehicleStatus.idle,
                      onTap: () => ref
                          .read(fleetFilterProvider.notifier)
                          .setFilter(VehicleStatus.idle),
                    ),
                    _FilterChip(
                      label: 'Stopped',
                      count: c.stopped,
                      selected: filter == VehicleStatus.stopped,
                      onTap: () => ref
                          .read(fleetFilterProvider.notifier)
                          .setFilter(VehicleStatus.stopped),
                    ),
                    _FilterChip(
                      label: 'Offline',
                      count: c.offline,
                      selected: filter == VehicleStatus.offline,
                      onTap: () => ref
                          .read(fleetFilterProvider.notifier)
                          .setFilter(VehicleStatus.offline),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Failed to load fleet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText('$e'),
                ],
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyFleet();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(fleetListProvider);
                    ref.invalidate(fleetCountsProvider);
                    await ref.read(fleetListProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _VehicleTile(item: items[index]);
                    },
                  ),
                );
              },
            ),
          ),
          if (undo != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.inverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Alert dismissed',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onInverseSurface,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.read(alertActionsProvider).undo(),
                          child: const Text('UNDO'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text('$label ($count)'),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({required this.item});

  final VehicleListItem item;

  @override
  Widget build(BuildContext context) {
    final socText = item.soc == null ? '—' : '${item.soc!.toStringAsFixed(0)}%';
    final rangeText =
        item.rangeKm == null ? '—' : '${item.rangeKm!.toStringAsFixed(0)} km';
    final ping = item.lastPing == null
        ? 'no ping'
        : DateFormat.Hm().format(item.lastPing!.toLocal());

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/vehicle/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.regNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (item.hasAlert) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Color(0xFFB45309),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.model,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'SOC $socText · Range $rangeText · Ping $ping'
                      '${item.currentGeofenceName == null ? '' : ' · ${item.currentGeofenceName}'}',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(status: item.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFleet extends StatelessWidget {
  const _EmptyFleet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              'No vehicles match this filter',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try another status chip, or clear the filter.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
