/// Schema + a few SQL fragments reused by repositories.
///
/// UI reads always go through these queries (or siblings) — never an in-memory
/// cache that DuckDB merely shadows.
abstract final class FleetSchema {
  static const createStatements = <String>[
    '''
    CREATE TABLE IF NOT EXISTS vehicles (
      id VARCHAR PRIMARY KEY,
      reg_number VARCHAR NOT NULL,
      model VARCHAR NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS signals (
      id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      signal VARCHAR NOT NULL,
      value DOUBLE,
      event_time TIMESTAMP NOT NULL,
      ingested_at TIMESTAMP NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS alerts (
      id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      kind VARCHAR NOT NULL,
      severity VARCHAR NOT NULL,
      message VARCHAR NOT NULL,
      triggered_at TIMESTAMP NOT NULL,
      resolved_at TIMESTAMP,
      dismissed_at TIMESTAMP,
      dismiss_reason VARCHAR
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS geofences (
      id VARCHAR PRIMARY KEY,
      name VARCHAR NOT NULL,
      lat DOUBLE NOT NULL,
      lng DOUBLE NOT NULL,
      radius_meters DOUBLE NOT NULL,
      active BOOLEAN NOT NULL,
      created_at TIMESTAMP NOT NULL,
      deactivated_at TIMESTAMP
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS geofence_transitions (
      id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      geofence_id VARCHAR NOT NULL,
      type VARCHAR NOT NULL,
      event_time TIMESTAMP NOT NULL,
      confirmed BOOLEAN NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS vehicle_geofence (
      vehicle_id VARCHAR PRIMARY KEY,
      geofence_id VARCHAR
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS trips (
      id VARCHAR PRIMARY KEY,
      vehicle_id VARCHAR NOT NULL,
      origin_geofence_id VARCHAR NOT NULL,
      destination_geofence_id VARCHAR,
      started_at TIMESTAMP NOT NULL,
      ended_at TIMESTAMP,
      status VARCHAR NOT NULL,
      source_start_key VARCHAR NOT NULL UNIQUE,
      source_end_key VARCHAR UNIQUE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS meta (
      key VARCHAR PRIMARY KEY,
      value VARCHAR NOT NULL
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_signals_vehicle_signal_time
      ON signals(vehicle_id, signal, event_time DESC)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_alerts_vehicle_active
      ON alerts(vehicle_id, resolved_at, dismissed_at)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_transitions_vehicle_time
      ON geofence_transitions(vehicle_id, event_time)
    ''',
  ];

  /// Latest numeric/bool-ish signals per vehicle, pivoted for the fleet list.
  ///
  /// Offline cutoff is computed in Dart — DuckDB 1.4 on iOS cannot autoload
  /// `core_functions` (`epoch_ms` / `date_diff`), so we only use timestamp `<`.
  static String fleetListSql({required String offlineBeforeIso}) => '''
    WITH latest AS (
      SELECT vehicle_id, signal, value, event_time,
             ROW_NUMBER() OVER (
               PARTITION BY vehicle_id, signal
               ORDER BY event_time DESC
             ) AS rn
      FROM signals
      WHERE signal IN ('soc', 'range_km', 'speed', 'ignition', 'last_ping')
    ),
    signal_wide AS (
      SELECT
        vehicle_id,
        MAX(CASE WHEN signal = 'soc' THEN value END) AS soc,
        MAX(CASE WHEN signal = 'range_km' THEN value END) AS range_km,
        MAX(CASE WHEN signal = 'speed' THEN value END) AS speed,
        MAX(CASE WHEN signal = 'ignition' THEN value END) AS ignition,
        MAX(CASE WHEN signal = 'last_ping' THEN event_time END) AS last_ping
      FROM latest
      WHERE rn = 1
      GROUP BY vehicle_id
    ),
    alert_counts AS (
      SELECT vehicle_id, COUNT(*) AS active_alert_count
      FROM alerts
      WHERE resolved_at IS NULL AND dismissed_at IS NULL
      GROUP BY vehicle_id
    ),
    ranked AS (
      SELECT
        v.id,
        v.reg_number,
        v.model,
        p.soc,
        p.range_km,
        p.speed,
        p.ignition,
        p.last_ping,
        COALESCE(a.active_alert_count, 0) AS active_alert_count,
        g.name AS geofence_name,
        CASE
          WHEN p.last_ping IS NULL
            OR p.last_ping < TIMESTAMP '$offlineBeforeIso'
            THEN 'OFFLINE'
          WHEN COALESCE(p.speed, 0) > 0 THEN 'MOVING'
          WHEN COALESCE(p.ignition, 0) = 1 THEN 'IDLE'
          ELSE 'STOPPED'
        END AS status
      FROM vehicles v
      LEFT JOIN signal_wide p ON p.vehicle_id = v.id
      LEFT JOIN alert_counts a ON a.vehicle_id = v.id
      LEFT JOIN vehicle_geofence vg ON vg.vehicle_id = v.id
      LEFT JOIN geofences g ON g.id = vg.geofence_id
    )
  ''';
}
