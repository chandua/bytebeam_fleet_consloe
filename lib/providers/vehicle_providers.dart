import 'dart:async';

import 'package:bytebeam_fleet_consloe/core/constants.dart';
import 'package:bytebeam_fleet_consloe/domain/models/alert.dart';
import 'package:bytebeam_fleet_consloe/domain/models/signal.dart';
import 'package:bytebeam_fleet_consloe/domain/models/trip.dart';
import 'package:bytebeam_fleet_consloe/domain/models/vehicle.dart';
import 'package:bytebeam_fleet_consloe/providers/database_providers.dart';
import 'package:bytebeam_fleet_consloe/providers/fleet_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final vehicleProvider =
    FutureProvider.family<Vehicle?, String>((ref, id) async {
  await ref.watch(fleetDatabaseProvider.future);
  return ref.read(vehicleRepositoryProvider).get(id);
});

final vehicleReadingsProvider =
    FutureProvider.family<List<SignalReading>, String>((ref, id) async {
  await ref.watch(fleetDatabaseProvider.future);
  return ref.read(telemetryRepositoryProvider).readingsForVehicle(id);
});

final socHistoryProvider =
    FutureProvider.family<List<SocHistoryPoint>, String>((ref, id) async {
  await ref.watch(fleetDatabaseProvider.future);
  return ref.read(telemetryRepositoryProvider).socHistory(id);
});

final vehicleAlertsProvider =
    FutureProvider.family<List<FleetAlert>, String>((ref, id) async {
  await ref.watch(fleetDatabaseProvider.future);
  return ref.read(alertRepositoryProvider).activeForVehicle(id);
});

final vehicleTripsProvider =
    FutureProvider.family<List<Trip>, String>((ref, id) async {
  await ref.watch(fleetDatabaseProvider.future);
  return ref.read(tripRepositoryProvider).listForVehicle(id);
});

class PendingUndo {
  const PendingUndo({required this.alertId, required this.expiresAt});

  final String alertId;
  final DateTime expiresAt;
}

class UndoDismissNotifier extends Notifier<PendingUndo?> {
  Timer? _timer;

  @override
  PendingUndo? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void arm(String alertId) {
    _timer?.cancel();
    final expires = DateTime.now().add(FleetConstants.undoWindow);
    state = PendingUndo(alertId: alertId, expiresAt: expires);
    _timer = Timer(FleetConstants.undoWindow, () {
      if (state?.alertId == alertId) state = null;
    });
  }

  void clear() {
    _timer?.cancel();
    state = null;
  }
}

final undoDismissProvider =
    NotifierProvider<UndoDismissNotifier, PendingUndo?>(
  UndoDismissNotifier.new,
);

class AlertActions {
  AlertActions(this._ref);

  final Ref _ref;

  Future<void> dismiss(String alertId, String reason) async {
    await _ref.read(alertRepositoryProvider).dismiss(
          alertId: alertId,
          reason: reason,
        );
    _ref.read(undoDismissProvider.notifier).arm(alertId);
    _ref.invalidate(fleetListProvider);
    _ref.invalidate(fleetCountsProvider);
    _ref.invalidate(vehicleAlertsProvider);
  }

  Future<void> undo() async {
    final pending = _ref.read(undoDismissProvider);
    if (pending == null) return;
    await _ref.read(alertRepositoryProvider).undoDismiss(pending.alertId);
    _ref.read(undoDismissProvider.notifier).clear();
    _ref.invalidate(fleetListProvider);
    _ref.invalidate(fleetCountsProvider);
    _ref.invalidate(vehicleAlertsProvider);
  }
}

final alertActionsProvider = Provider(AlertActions.new);
