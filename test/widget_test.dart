import 'package:flutter_test/flutter_test.dart';
import 'package:el_metr_academy/main.dart';

void main() {
  testWidgets('EL METR Academy smoke test launches login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ElMetrAcademyApp());
    await tester.pumpAndSettle();

    // Verify brand wordmark is present
    expect(find.text('EL METR'), findsOneWidget);
    expect(find.text('ACADEMY'), findsOneWidget);
  });
}
