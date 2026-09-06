
import 'package:bytebeam_fleet_consloe/domain/models/alert.dart';
import 'package:bytebeam_fleet_consloe/domain/models/signal.dart';
import 'package:bytebeam_fleet_consloe/ui/widgets/soc_sparkline.dart';
import 'package:bytebeam_fleet_consloe/ui/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/trip.dart';
import '../../providers/vehicle_providers.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider(vehicleId));
    final readings = ref.watch(vehicleReadingsProvider(vehicleId));
    final history = ref.watch(socHistoryProvider(vehicleId));
    final alerts = ref.watch(vehicleAlertsProvider(vehicleId));
    final trips = ref.watch(vehicleTripsProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(
        title: vehicle.when(
          data: (v) => Text(v?.regNumber ?? 'Vehicle'),
          loading: () => const Text('Vehicle'),
          error: (_, _) => const Text('Vehicle'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          vehicle.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (v) {
              if (v == null) return const Text('Vehicle not found');
              return Text(
                v.model,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Readings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          readings.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('$e'),
            data: (rows) => Column(
              children: rows.map((r) => _ReadingRow(reading: r)).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Text('SOC history', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: history.when(
                loading: () => const SizedBox(
                  height: 72,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('$e'),
                data: (points) => SocSparkline(
                  values: points.map((p) => p.soc).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Active alerts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          alerts.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No active alerts',
                  style: TextStyle(color: Colors.grey.shade600),
                );
              }
              return Column(
                children: items
                    .map(
                      (a) => _AlertCard(
                        alert: a,
                        onDismiss: () => _showDismissSheet(context, ref, a),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Trips', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          trips.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No trips yet',
                  style: TextStyle(color: Colors.grey.shade600),
                );
              }
              return Column(
                children: items.take(8).map((t) => _TripTile(trip: t)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDismissSheet(
    BuildContext context,
    WidgetRef ref,
    FleetAlert alert,
  ) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Dismiss alert',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Why are you clearing this?'),
              ),
              for (final r in DismissReasons.ordered)
                ListTile(
                  title: Text(r),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (reason == null) return;
    await ref.read(alertActionsProvider).dismiss(alert.id, reason);
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.reading});

  final SignalReading reading;

  @override
  Widget build(BuildContext context) {
    final valueText = _formatValue(reading);
    final age = reading.eventTime == null
        ? null
        : _formatAge(DateTime.now().toUtc().difference(reading.eventTime!));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reading.kind.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (age != null)
                  Text(
                    age,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Text(
            valueText,
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(width: 10),
          if (reading.verdict != null)
            VerdictPill(
              label: reading.verdict!.name.toUpperCase(),
              tone: switch (reading.verdict!) {
                SignalVerdict.normal => VerdictTone.normal,
                SignalVerdict.alert => VerdictTone.alert,
                SignalVerdict.stale => VerdictTone.stale,
              },
            )
          else
            const SizedBox(width: 64),
        ],
      ),
    );
  }

  String _formatValue(SignalReading r) {
    if (!r.hasValue) return '—';
    if (r.kind == SignalKind.lastPing) {
      return DateFormat.MMMd().add_Hm().format(r.eventTime!.toLocal());
    }
    if (r.value == null) return '—';
    return switch (r.kind) {
      SignalKind.soc => '${r.value!.toStringAsFixed(0)}%',
      SignalKind.rangeKm => '${r.value!.toStringAsFixed(0)} km',
      SignalKind.speed => '${r.value!.toStringAsFixed(0)} km/h',
      SignalKind.batteryTemp => '${r.value!.toStringAsFixed(1)} °C',
      SignalKind.odometer => '${r.value!.toStringAsFixed(0)} km',
      SignalKind.ignition => r.value! >= 1 ? 'On' : 'Off',
      _ => r.value!.toStringAsFixed(2),
    };
  }

  String _formatAge(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onDismiss});

  final FleetAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final critical = alert.severity == AlertSeverity.critical;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.warning_amber_rounded,
          color: critical ? Colors.red.shade700 : Colors.orange.shade800,
        ),
        title: Text(alert.message),
        subtitle: Text(alert.severity.name.toUpperCase()),
        trailing: TextButton(
          onPressed: onDismiss,
          child: const Text('Dismiss'),
        ),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final dest = trip.destinationName ?? (trip.isActive ? 'In progress' : '—');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${trip.originName ?? 'Origin'} → $dest'),
      subtitle: Text(
        DateFormat.MMMd().add_Hm().format(trip.startedAt.toLocal()),
      ),
      trailing: Text(
        trip.isActive ? 'IN PROGRESS' : 'DONE',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: trip.isActive ? Colors.teal.shade700 : Colors.grey.shade600,
        ),
      ),
    );
  }
}
