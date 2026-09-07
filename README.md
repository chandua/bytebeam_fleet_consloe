# Fleet Console

Local-first Flutter fleet dashboard (Bytebeam take-home style). Telemetry lives in an on-device DuckDB file; the UI reads from SQL, not from an in-memory list mirrored to disk.

Package name: `bytebeam_fleet_consloe`.

## Run

```bash
flutter pub get
flutter run -d macos   # or an Android / iOS device
```

Android is the primary mobile target (`dart_duckdb` ships native binaries). macOS works for local development once the DuckDB dylib is available (CocoaPods `prepare_command` downloads it, or place `libduckdb.dylib` under the package’s `macos/Libraries/release/`).

`dart_duckdb` is loaded from `third_party/dart_duckdb` (vendored 1.4.2 sources). iOS links **`duckdb.xcframework`** (device + simulator) from the `yharby/duckdb-dart` `v1.4.3-ios` release — upstream TigerEyeLabs zips are device-only and break simulator builds. The iOS `Podfile` prefetches that XCFramework before `pod install`. Android `build.gradle` downloads `libduckdb.so` from TigerEyeLabs **`v1.4.2`** (1.4.1/1.4.4 Android assets 404).

## Tests

```bash
flutter test
```

Domain tests cover status rules, alert escalation, geofence confirmation, trip construction, and signal verdicts. They do not need a device.

## 30-second tour

1. **Fleet home** — vehicles with reg, model, SOC, range, alert badge, status chip. Filter chips (All / Moving / Idle / Stopped / Offline) show live SQL counts.
2. **Vehicle detail** — readings with age + NORMAL / ALERT / STALE, SOC sparkline, dismissible alerts with a 5s undo, and trips for that truck.
3. **Geofences** — create / edit / deactivate circular fences; live vehicle counts. Edits recompute membership from retained location history.
4. **Trips** — auto-built from confirmed geofence exit → enter.
5. **Scale backfill** — overflow menu → “Scale backfill (500 / 2M)” writes 500 vehicles and ~2M signal rows, then refreshes the list.

## Architecture notes

- `lib/data/database` — DuckDB open + schema
- `lib/data/repositories` — all reads/writes go through here
- `lib/domain/services` — pure rules (alerts, geofences, trips) so they stay unit-testable
- `lib/providers` — Riverpod only (no `setState`)
- `lib/ui` — screens + small widgets

### Geofence strategy

Documented on `GeofenceEngine`: event-time ordering, exact-duplicate drop, accuracy filter (>50 m ignored), 2-sample confirmation, gap reset after 30 minutes, overlap = smallest radius then newest fence, edits recomputed from retained history.

### Trips

Confirmed exit starts one active trip; next confirmed enter completes it (origin return allowed). Replay is idempotent via transition keys.

### Retention

Append-only `signals` older than **14 days** can be dropped via `TelemetryRepository.compactOldSignals()` (last ping kept). What you lose: deep SOC/history sparklines and long geofence trails beyond that window. Active membership, alerts, geofences, and trips stay.

### Scale measurements

Measured on **macOS 26.5.2 (Apple M3, 8 GB RAM)** after running scale backfill (500 vehicles, ~2.00M signal rows; backfill itself took **338 s**).

| Metric | Result | How |
| --- | --- | --- |
| Cold start → first fleet data | **3.1 s** | Stopwatch: DuckDB open + demo seed + first `VehicleRepository.list` |
| Fleet-list query p50 / p95 | **52 ms / 65 ms** | 40 warm samples of `list()` over 524 vehicles |
| Memory at rest (RSS) | **~477 MB** | `ProcessInfo.currentRss` after backfill with list queried |

Re-run locally:

```bash
flutter test tool/measure_scale_manual_test.dart
```

## AI conversation logs

Uncurated Cursor agent transcripts (including dead ends and corrections) live in [`docs/ai-logs/`](docs/ai-logs/).

## Cut scope (if any)

Nothing core was dropped: fleet list, detail, alerts+undo, geofences, trips, seed data, scale action, and domain tests are in. Optional APK and a polished map UI were skipped in favor of correctness of the local-first path.
