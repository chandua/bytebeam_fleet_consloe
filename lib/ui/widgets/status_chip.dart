import 'package:flutter/material.dart';

import '../../domin/model/vehicle_status.dart' show VehicleStatus;

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final VehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      VehicleStatus.moving => (const Color(0xFFD7F0E2), const Color(0xFF146C43)),
      VehicleStatus.idle => (const Color(0xFFFFF0D6), const Color(0xFF8A5A00)),
      VehicleStatus.stopped => (const Color(0xFFE8E8E8), const Color(0xFF444444)),
      VehicleStatus.offline => (const Color(0xFFF0D6D6), const Color(0xFF8A1F1F)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class VerdictPill extends StatelessWidget {
  const VerdictPill({super.key, required this.label, required this.tone});

  final String label;
  final VerdictTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      VerdictTone.normal => (const Color(0xFFD7F0E2), const Color(0xFF146C43)),
      VerdictTone.alert => (const Color(0xFFF8D4D4), const Color(0xFF9B1C1C)),
      VerdictTone.stale => (const Color(0xFFE5E5E5), const Color(0xFF6B6B6B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

enum VerdictTone { normal, alert, stale }
