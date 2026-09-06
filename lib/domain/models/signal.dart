enum SignalKind {
  soc,
  rangeKm,
  speed,
  batteryTemp,
  odometer,
  lastPing,
  lat,
  lng,
  gpsAccuracy,
  ignition;

  String get storageKey => switch (this) {
        SignalKind.soc => 'soc',
        SignalKind.rangeKm => 'range_km',
        SignalKind.speed => 'speed',
        SignalKind.batteryTemp => 'battery_temp',
        SignalKind.odometer => 'odometer',
        SignalKind.lastPing => 'last_ping',
        SignalKind.lat => 'lat',
        SignalKind.lng => 'lng',
        SignalKind.gpsAccuracy => 'gps_accuracy',
        SignalKind.ignition => 'ignition',
      };

  String get label => switch (this) {
        SignalKind.soc => 'SOC',
        SignalKind.rangeKm => 'Range',
        SignalKind.speed => 'Speed',
        SignalKind.batteryTemp => 'Battery temp',
        SignalKind.odometer => 'Odometer',
        SignalKind.lastPing => 'Last ping',
        SignalKind.lat => 'Latitude',
        SignalKind.lng => 'Longitude',
        SignalKind.gpsAccuracy => 'GPS accuracy',
        SignalKind.ignition => 'Ignition',
      };

  static SignalKind? fromStorageKey(String key) {
    for (final kind in values) {
      if (kind.storageKey == key) return kind;
    }
    return null;
  }
}

enum SignalVerdict { normal, alert, stale }

class SignalReading {
  const SignalReading({
    required this.kind,
    this.value,
    this.eventTime,
    this.verdict,
  });

  final SignalKind kind;
  final double? value;
  final DateTime? eventTime;
  final SignalVerdict? verdict;

  bool get hasValue => value != null || eventTime != null;
}

class SocHistoryPoint {
  const SocHistoryPoint({required this.at, required this.soc});

  final DateTime at;
  final double soc;
}
