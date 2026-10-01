import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/providers/settings_provider.dart';
import 'package:wael_app/screens/settings_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/icon_tile.dart';
import 'package:wael_app/widgets/profile_avatar.dart';
import 'package:wael_app/widgets/themed_section_header.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _tall = Size(390, 1800);

Future<AuthProvider> signedIn() async {
  final auth = makeAuth();
  await auth.login('u@e.com', 'password123');
  auth.updateProfile(
    auth.currentUser.copyWith(fullName: 'Jane Doe', phone: '+201000000000'),
  );
  return auth;
}

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    String upper(String s) => s.toUpperCase();

    Future<(AuthProvider, SettingsProvider)> pump(WidgetTester tester) async {
      final auth = await signedIn();
      final settings = SettingsProvider();
      await pumpScreen(
        tester,
        locale,
        const SettingsScreen(),
        auth: auth,
        settings: settings,
        size: _tall,
      );
      return (auth, settings);
    }

    group('SettingsScreen [$name]', () {
      testWidgets('profile card, localised section headers and footer', (
        tester,
      ) async {
        await pump(tester);
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        expect(find.text('Jane Doe'), findsOneWidget);
        expect(find.text('u@e.com'), findsOneWidget);
        expect(find.byType(ProfileAvatar), findsOneWidget);
        expect(find.byType(ThemedSectionHeader), findsNWidgets(4));
        for (final title in [
          l10n.accountSecurity,
          l10n.languageAndPreferences,
          l10n.notificationsSettings,
          l10n.academyProtocolLegal,
        ]) {
          expect(find.text(upper(title)), findsOneWidget);
        }
        expect(find.text(l10n.allRightsReserved), findsOneWidget);
        expect(find.text(l10n.biometricSignIn), findsOneWidget);
      });

      testWidgets('layout mirrors ($direction)', (tester) async {
        await pump(tester);
        // Avatar, then the name.
        expect(
          startsBefore(
            tester,
            find.byType(ProfileAvatar),
            find.text('Jane Doe'),
            direction,
          ),
          isTrue,
        );
        // Avatar badge sits at the end corner of the avatar.
        final avatar = tester.getRect(find.byType(ProfileAvatar));
        final badge = find.descendant(
          of: find.byType(ProfileAvatar),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.constraints?.maxWidth == 8,
          ),
        );
        final badgeX = tester.getCenter(badge).dx;
        if (direction == TextDirection.ltr) {
          expect(badgeX, greaterThan(avatar.center.dx));
        } else {
          expect(badgeX, lessThan(avatar.center.dx));
        }
        // Switch row: icon tile at the start, switch at the end.
        // The first IconTile and Switch belong to the biometric row.
        final tile = find.byType(IconTile).first;
        final toggle = find.byType(Switch).first;
        expect(
          startsBefore(
            tester,
            tile,
            find.text(l10n.biometricSignIn),
            direction,
          ),
          isTrue,
        );
        expect(
          startsBefore(
            tester,
            find.text(l10n.biometricSignIn),
            toggle,
            direction,
          ),
          isTrue,
        );
        // Navigation row: chevron at the end, after the title.
        expect(
          startsBefore(
            tester,
            find.text(l10n.passwordAnd2fa),
            find.byIcon(Icons.chevron_right).first,
            direction,
          ),
          isTrue,
        );
      });

      testWidgets('switches write to the settings provider', (tester) async {
        final (_, settings) = await pump(tester);
        expect(settings.biometricEnabled, isTrue);
        await tester.tap(find.byType(Switch).first);
        await tester.pump();
        expect(settings.biometricEnabled, isFalse);
        await tester.tap(find.byType(Switch).at(1));
        await tester.pump();
        expect(settings.eventReminders, isFalse);
      });

      testWidgets('info tiles show a snackbar', (tester) async {
        await pump(tester);
        await tester.tap(find.text(l10n.passwordAnd2fa));
        await tester.pump();
        expect(find.text(l10n.twoFactorActive), findsOneWidget);
      });

      testWidgets('language tile toggles the locale and says so', (
        tester,
      ) async {
        await pump(tester);
        final locales = Provider.of<LocaleProvider>(
          tester.element(find.byType(SettingsScreen)),
          listen: false,
        );
        expect(locales.isArabic, isFalse);
        await tester.tap(find.text(l10n.languageAndSubtitles));
        await tester.pump();
        expect(locales.isArabic, isTrue);
        expect(find.text(l10n.languageSwitched(true)), findsOneWidget);
      });

      testWidgets('edit profile sheet saves through the auth provider', (
        tester,
      ) async {
        final (auth, _) = await pump(tester);
        await tester.tap(
          find.widgetWithText(OutlinedButton, upper(l10n.editProfile)),
        );
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextFormField, 'Jane Doe'), findsOneWidget);
        expect(find.text(l10n.phoneNumber), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Jane Doe'),
          'Jane Roe',
        );
        await tester.tap(find.text(upper(l10n.save)));
        await tester.pumpAndSettle();
        expect(auth.currentUser.fullName, 'Jane Roe');
        expect(find.text('Jane Roe'), findsOneWidget);
        expect(find.text(upper(l10n.save)), findsNothing);
      });

      testWidgets('honor code sheet shows the localised text and closes', (
        tester,
      ) async {
        await pump(tester);
        await tester.tap(find.text(l10n.honorCodeAndTerms));
        await tester.pumpAndSettle();
        expect(find.text(l10n.honorCodeBody), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.text(l10n.honorCodeBody), findsNothing);
      });

      testWidgets('sign out clears the session and goes to /login', (
        tester,
      ) async {
        final (auth, _) = await pump(tester);
        expect(auth.isAuthenticated, isTrue);
        await tester.tap(find.text(upper(l10n.signOut)));
        await tester.pumpAndSettle();
        expect(auth.isAuthenticated, isFalse);
        expect(find.text('route:/login'), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);
      });
    });
  }
}
