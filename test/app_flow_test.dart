import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/main.dart';
import 'package:wael_app/widgets/app_bottom_nav.dart';
import 'package:wael_app/widgets/framed_poster_card.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';

import 'academy_fakes.dart';
import 'fakes.dart';

Widget testApp() {
  return WaelApp(
    providersOverride: [
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider(
        create: (_) => AuthProvider(
          repository: FakeAuthRepository(),
          tokenStore: MemoryTokenStore(),
        ),
      ),
      ChangeNotifierProvider(create: (_) => AcademyCatalogProvider(fake())),
      ChangeNotifierProvider(create: (_) => HomeProvider()),
      ChangeNotifierProvider(create: (_) => NotificationsProvider()),
    ],
  );
}

void main() {
  testWidgets('Real auth flow: splash to login to main shell', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    // Splash restores no session -> login screen.
    expect(find.byType(FramedPosterCard), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text("Don't have an account?"), findsOneWidget);

    // Navigate to Signup and back.
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN'), findsOneWidget);

    // Enter real credentials and sign in (fake backend accepts).
    await tester.enterText(find.byType(TextFormField).at(0), 'u@e.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    // Home shell content.
    // The shipped director profile is filled, so the director section shows.
    expect(find.text('ACADEMY DIRECTOR & INSTRUCTOR'), findsOneWidget);
    expect(find.text('Wael El Saeed'), findsOneWidget);
    expect(find.text('MY COURSES'), findsOneWidget);

    // Courses tab.
    // The home tab now also shows this icon on an owned-subject tile, so
    // target the bottom navigation.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.byIcon(Icons.school_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('EDUCATION TYPE'), findsOneWidget);

    // Settings shows the authenticated account email.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('u@e.com'), findsOneWidget);

    // Sign out returns to login (after confirming the dialog).
    await tester.ensureVisible(find.text('SIGN OUT OF EL METR ACADEMY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIGN OUT OF EL METR ACADEMY'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('SIGN IN'), findsOneWidget);
  });
}
