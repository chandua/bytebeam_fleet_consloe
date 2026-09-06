import 'dart:io';

import 'package:dart_duckdb/dart_duckdb.dart' show OperatingSystem;
import 'package:dart_duckdb/open.dart';
import 'package:path/path.dart' as p;

/// Ensures the DuckDB dylib is findable on macOS (Flutter bundles it under
/// Contents/Frameworks, but dart_duckdb only probes DynamicLibrary.process()).
void configureDuckDbNative() {
  if (!Platform.isMacOS) return;

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final bundled = p.join(exeDir, '..', 'Frameworks', 'libduckdb.dylib');
  final bundledNormalized = p.normalize(bundled);
  if (File(bundledNormalized).existsSync()) {
    open.overrideFor(OperatingSystem.macOS, bundledNormalized);
    return;
  }

  // flutter test / bare dart — pull from the pub-cache package.
  final home = Platform.environment['HOME'];
  if (home == null) return;
  final pubCache =
      Platform.environment['PUB_CACHE'] ?? p.join(home, '.pub-cache');
  final hosted = Directory(p.join(pubCache, 'hosted'));
  if (!hosted.existsSync()) return;

  for (final host in hosted.listSync().whereType<Directory>()) {
    for (final pkg in host.listSync().whereType<Directory>()) {
      if (!p.basename(pkg.path).startsWith('dart_duckdb-')) continue;
      final dylib =
          p.join(pkg.path, 'macos', 'Libraries', 'release', 'libduckdb.dylib');
      if (File(dylib).existsSync()) {
        open.overrideFor(OperatingSystem.macOS, dylib);
        return;
      }
    }
  }
}
