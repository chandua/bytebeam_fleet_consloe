import 'package:bytebeam_fleet_consloe/app.dart';
import 'package:bytebeam_fleet_consloe/core/duckdb_bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureDuckDbNative();

  testWidgets('app boots into loading shell', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FleetApp()),
    );
    expect(find.byType(FleetApp), findsOneWidget);
  });
}
