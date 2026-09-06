import 'dart:math' as math;

import 'package:bytebeam_fleet_consloe/core/constants.dart';
import 'package:bytebeam_fleet_consloe/domain/models/geofence.dart';


/// Deterministic geofence membership from event-time location history.
///
/// Strategy (documented for the brief):
/// - **Duplicates**: identical (vehicle, eventTime, lat, lng) samples are ignored.
/// - **Late packets**: we always walk samples in event-time order, never arrival order.
/// - **GPS jitter**: require [FleetConstants.geofenceConfirmSamples] consecutive
///   samples agreeing on membership before emitting a confirmed enter/exit.
/// - **Inaccurate readings**: drop samples with accuracy worse than
///   [FleetConstants.maxGpsAccuracyMeters].
/// - **Overlaps**: among active fences containing the point, pick the smallest
///   radius; ties go to the newest `createdAt`.
/// - **Missing intervals**: a gap > [FleetConstants.geofenceGapBreak] resets the
///   confirmation streak (no phantom transitions across long offline stretches).
/// - **Geofence edits**: callers should re-run this over retained history after
///   an edit; we never invent transitions for time we did not observe.
class GeofenceEngine {
  const GeofenceEngine();

  List<ProposedTransition> process({
    required String vehicleId,
    required List<LocationSample> samples,
    required List<Geofence> activeGeofences,
    String? startingGeofenceId,
  }) {
    if (samples.isEmpty || activeGeofences.isEmpty) return const [];

    final ordered = [...samples]..sort((a, b) => a.eventTime.compareTo(b.eventTime));
    final deduped = <LocationSample>[];
    final seen = <String>{};
    for (final sample in ordered) {
      final key =
          '${sample.eventTime.toIso8601String()}|${sample.lat}|${sample.lng}';
      if (seen.add(key)) deduped.add(sample);
    }

    String? current = startingGeofenceId;
    String? pendingTarget;
    var streak = 0;
    DateTime? lastAcceptedAt;
    final out = <ProposedTransition>[];

    for (final sample in deduped) {
      if (sample.accuracyMeters != null &&
          sample.accuracyMeters! > FleetConstants.maxGpsAccuracyMeters) {
        continue;
      }

      if (lastAcceptedAt != null &&
          sample.eventTime.difference(lastAcceptedAt) >
              FleetConstants.geofenceGapBreak) {
        pendingTarget = null;
        streak = 0;
      }
      lastAcceptedAt = sample.eventTime;

      final containing = _pickContaining(sample, activeGeofences);
      final target = containing?.id;

      if (target == current) {
        pendingTarget = null;
        streak = 0;
        continue;
      }

      if (target == pendingTarget) {
        streak += 1;
      } else {
        pendingTarget = target;
        streak = 1;
      }

      if (streak < FleetConstants.geofenceConfirmSamples) continue;

      if (current != null) {
        out.add(
          ProposedTransition(
            vehicleId: vehicleId,
            geofenceId: current,
            type: GeofenceTransitionType.exit,
            eventTime: sample.eventTime,
          ),
        );
      }
      if (target != null) {
        out.add(
          ProposedTransition(
            vehicleId: vehicleId,
            geofenceId: target,
            type: GeofenceTransitionType.enter,
            eventTime: sample.eventTime,
          ),
        );
      }

      current = target;
      pendingTarget = null;
      streak = 0;
    }

    return out;
  }

  Geofence? containingFence(LocationSample sample, List<Geofence> fences) =>
      _pickContaining(sample, fences);

  Geofence? _pickContaining(LocationSample sample, List<Geofence> fences) {
    final hits = <Geofence>[];
    for (final fence in fences) {
      if (!fence.active) continue;
      final d = haversineMeters(sample.lat, sample.lng, fence.lat, fence.lng);
      if (d <= fence.radiusMeters) hits.add(fence);
    }
    if (hits.isEmpty) return null;
    hits.sort((a, b) {
      final byRadius = a.radiusMeters.compareTo(b.radiusMeters);
      if (byRadius != 0) return byRadius;
      return b.createdAt.compareTo(a.createdAt);
    });
    return hits.first;
  }
}

class LocationSample {
  const LocationSample({
    required this.lat,
    required this.lng,
    required this.eventTime,
    this.accuracyMeters,
  });

  final double lat;
  final double lng;
  final DateTime eventTime;
  final double? accuracyMeters;
}

class ProposedTransition {
  const ProposedTransition({
    required this.vehicleId,
    required this.geofenceId,
    required this.type,
    required this.eventTime,
  });

  final String vehicleId;
  final String geofenceId;
  final GeofenceTransitionType type;
  final DateTime eventTime;

  /// Stable id so replaying the same transition is a no-op.
  String get idempotencyKey =>
      '$vehicleId|$geofenceId|${type.name}|${eventTime.toUtc().toIso8601String()}';
}

double haversineMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadius = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _rad(double deg) => deg * math.pi / 180.0;
