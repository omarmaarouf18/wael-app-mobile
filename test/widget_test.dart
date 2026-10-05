import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/main.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';

import 'fakes.dart';

void main() {
  // The smoke test drives the real route table with fake session storage.
  // The platform secure store never answers under flutter_test, so the real
  // binding would leave the restore hanging on the splash (and any restore
  // budget timer pending at teardown).
  testWidgets('EL METR Academy smoke test launches login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      WaelApp(
        providersOverride: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              repository: FakeAuthRepository(),
              tokenStore: MemoryTokenStore(),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Splash found no stored session and routed to login.
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('EL METR'), findsNothing);
  });
}
