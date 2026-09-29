import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/main.dart';

void main() {
  testWidgets('EL METR Academy smoke test launches login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WaelApp());
    await tester.pumpAndSettle();

    // Verify brand wordmark is present
    expect(find.text('EL METR'), findsOneWidget);
    expect(find.text('ACADEMY'), findsOneWidget);
  });
}
