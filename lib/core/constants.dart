/// Fleet-wide thresholds and timing knobs.
///
/// Kept in one place so SQL status rules and the alert engine stay aligned.
abstract final class FleetConstants {
  static const offlineAfter = Duration(minutes: 10);
  static const staleAfter = Duration(minutes: 10);

  static const lowBatterySoc = 20.0;
  static const criticalBatterySoc = 10.0;
  static const overheatCelsius = 45.0;

  /// GPS samples with worse accuracy than this are ignored for geofence work.
  static const maxGpsAccuracyMeters = 50.0;

  /// Consecutive samples needed before we treat a geofence transition as confirmed.
  static const geofenceConfirmSamples = 2;

  /// Gap longer than this clears any in-flight transition confirmation.
  static const geofenceGapBreak = Duration(minutes: 30);

  /// Soft retention window for raw signal rows. Older rows are compacted away.
  static const signalRetention = Duration(days: 14);

  static const undoWindow = Duration(seconds: 5);

  static const demoVehicleCount = 24;
  static const scaleVehicleCount = 500;
  static const scaleSignalRows = 2000000;
}
