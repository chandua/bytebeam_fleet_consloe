import 'package:bytebeam_fleet_consloe/core/constants.dart';
import 'package:bytebeam_fleet_consloe/domain/models/signal.dart';
import 'package:bytebeam_fleet_consloe/domain/services/signal_verdict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = SignalVerdictResolver();
  final now = DateTime.utc(2026, 9, 6, 12);

  test('stale wins over alert condition', () {
    final verdict = resolver.verdict(
      value: 5,
      eventTime: now.subtract(FleetConstants.staleAfter + const Duration(minutes: 1)),
      kind: SignalKind.soc,
      now: now,
      alertCondition: true,
    );
    expect(verdict, SignalVerdict.stale);
  });

  test('alert when fresh and condition active', () {
    final verdict = resolver.verdict(
      value: 8,
      eventTime: now,
      kind: SignalKind.soc,
      now: now,
      alertCondition: resolver.isAlertCondition(SignalKind.soc, 8),
    );
    expect(verdict, SignalVerdict.alert);
  });

  test('normal when fresh and healthy', () {
    final verdict = resolver.verdict(
      value: 80,
      eventTime: now,
      kind: SignalKind.soc,
      now: now,
      alertCondition: resolver.isAlertCondition(SignalKind.soc, 80),
    );
    expect(verdict, SignalVerdict.normal);
  });
}
