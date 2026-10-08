import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/screens/settings_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/icon_tile.dart';
import 'package:wael_app/widgets/profile_avatar.dart';
import 'package:wael_app/widgets/themed_section_header.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _tall = Size(390, 1800);

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    String upper(String s) => s.toUpperCase();

    Future<AuthProvider> pump(
      WidgetTester tester, {
      String fullName = 'Jane Doe',
      String phone = '+201000000000',
    }) async {
      final auth = await signedInAuth(name: fullName, phone: phone);
      await pumpScreen(
        tester,
        locale,
        const SettingsScreen(),
        auth: auth,
        size: _tall,
      );
      return auth;
    }

    group('SettingsScreen [$name]', () {
      testWidgets('profile card shows the account from the server', (
        tester,
      ) async {
        await pump(tester);
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        // The name also shows in the My-account name row below.
        expect(find.text('Jane Doe'), findsNWidgets(2));
        expect(find.text('u@e.com'), findsNWidgets(2));
        expect(find.text('+201000000000'), findsNWidgets(2));
        expect(find.byType(ProfileAvatar), findsOneWidget);
      });

      testWidgets('the avatar is a neutral icon, not a stand-in photo', (
        tester,
      ) async {
        await pump(tester);
        final avatar = find.byType(ProfileAvatar);
        expect(
          find.descendant(
            of: avatar,
            matching: find.byIcon(Icons.person_outline),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: avatar, matching: find.byType(Image)),
          findsNothing,
        );
        // No "online" badge dot either.
        expect(
          find.descendant(
            of: avatar,
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.constraints?.maxWidth == 8,
            ),
          ),
          findsNothing,
        );
      });

      testWidgets('shows the kept sections: language, about, sign out', (
        tester,
      ) async {
        await pump(tester);
        // Two sections (language, about), the sign-out button, and the
        // version row. Terms/privacy tiles always show (fallback links).
        expect(find.byType(ThemedSectionHeader), findsNWidgets(4));
        expect(find.text(upper(l10n.languageAndPreferences)), findsOneWidget);
        expect(find.text(l10n.languageAndSubtitles), findsOneWidget);
        expect(find.text(upper(l10n.aboutApp)), findsOneWidget);
        expect(find.text(l10n.appVersion), findsOneWidget);
        expect(find.text(l10n.termsTitle), findsOneWidget);
        expect(find.text(l10n.privacyTitle), findsOneWidget);
        expect(find.byType(OutlinedButton), findsNWidgets(2));
        expect(find.text(upper(l10n.signOut)), findsOneWidget);
        expect(find.text(upper(l10n.deleteAccount)), findsOneWidget);

        // Everything that claimed a setting or a policy is gone.
        expect(find.byType(Switch), findsNothing);
        expect(find.byType(SwitchListTile), findsNothing);
        for (final icon in [
          Icons.fingerprint,
          Icons.notifications_none,
          Icons.auto_stories_outlined,
          Icons.verified_outlined,
          Icons.policy_outlined,
          Icons.edit,
        ]) {
          expect(find.byIcon(icon), findsNothing, reason: '$icon');
        }
      });

      testWidgets('no invented standing, platform or build number', (
        tester,
      ) async {
        await pump(tester);
        expect(find.textContaining('Top 3%'), findsNothing);
        expect(find.textContaining('Senior Scholar'), findsNothing);
        expect(find.textContaining('دفعة'), findsNothing);
        expect(find.textContaining('iOS'), findsNothing);
        expect(find.textContaining('Build 1.0.0'), findsNothing);
      });

      testWidgets('without a name the email is the title and phone is hidden', (
        tester,
      ) async {
        await pump(tester, fullName: '', phone: '');
        expect(find.text('u@e.com'), findsNWidgets(2));
        expect(find.byType(ProfileAvatar), findsOneWidget);
        expect(find.textContaining('+20'), findsNothing);
      });

      testWidgets('layout mirrors ($direction)', (tester) async {
        await pump(tester);
        expect(
          startsBefore(
            tester,
            find.byType(ProfileAvatar),
            find.text('Jane Doe').first,
            direction,
          ),
          isTrue,
        );
        // Language row: icon tile, then title, then the chevron at the end.
        final langTile = find.ancestor(
          of: find.text(l10n.languageAndSubtitles),
          matching: find.byType(InkWell),
        );
        final langIcon = find.descendant(
          of: langTile,
          matching: find.byType(IconTile),
        );
        final langChevron = find.descendant(
          of: langTile,
          matching: find.byIcon(Icons.chevron_right),
        );
        expect(
          startsBefore(
            tester,
            langIcon,
            find.text(l10n.languageAndSubtitles),
            direction,
          ),
          isTrue,
        );
        expect(
          startsBefore(
            tester,
            find.text(l10n.languageAndSubtitles),
            langChevron,
            direction,
          ),
          isTrue,
        );
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

      testWidgets('sign out asks first, then clears and goes to /login', (
        tester,
      ) async {
        final auth = await pump(tester);
        expect(auth.isAuthenticated, isTrue);
        await tester.tap(find.text(upper(l10n.signOut)));
        await tester.pumpAndSettle();
        // Still signed in with the question open.
        expect(auth.isAuthenticated, isTrue);
        expect(find.text(l10n.signOutConfirmTitle), findsOneWidget);
        await tester.tap(find.text(l10n.confirm));
        await tester.pumpAndSettle();
        expect(auth.isAuthenticated, isFalse);
        expect(find.text('route:/login'), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);
      });

      testWidgets('cancelling sign out stays signed in', (tester) async {
        final auth = await pump(tester);
        expect(auth.isAuthenticated, isTrue);
        await tester.tap(find.text(upper(l10n.signOut)));
        await tester.pumpAndSettle();
        expect(find.text(l10n.signOutConfirmTitle), findsOneWidget);
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        expect(auth.isAuthenticated, isTrue);
        expect(find.byType(SettingsScreen), findsOneWidget);
      });

      testWidgets('Help section is hidden when supportWhatsappUrl is empty', (
        tester,
      ) async {
        await pump(tester);
        expect(find.text(l10n.contactWhatsApp), findsNothing);
      });

      testWidgets(
        'Help section is present with URL and opens WhatsApp externally',
        (tester) async {
          final calls = <(Uri, LaunchMode)>[];
          final configProvider = AppConfigProvider()
            ..setForTesting(
              const AppConfigData(
                supportWhatsappUrl: 'https://wa.me/201000000000',
              ),
            );
          final auth = await signedInAuth();
          await pumpScreen(
            tester,
            locale,
            SettingsScreen(
              launchUrl: (uri, {mode = LaunchMode.platformDefault}) async {
                calls.add((uri, mode));
                return true;
              },
            ),
            auth: auth,
            appConfig: configProvider,
            size: _tall,
          );

          expect(find.text(l10n.contactWhatsApp), findsOneWidget);
          await tester.tap(find.text(l10n.contactWhatsApp));
          await tester.pumpAndSettle();

          expect(calls, hasLength(1));
          expect(calls.first.$1.host, 'wa.me');
          expect(calls.first.$2, LaunchMode.externalApplication);
          expect(find.byType(SnackBar), findsNothing);
        },
      );

      testWidgets('Help section shows snackbar when launching WhatsApp fails', (
        tester,
      ) async {
        final configProvider = AppConfigProvider()
          ..setForTesting(
            const AppConfigData(
              supportWhatsappUrl: 'https://wa.me/201000000000',
            ),
          );
        final auth = await signedInAuth();
        await pumpScreen(
          tester,
          locale,
          SettingsScreen(
            launchUrl: (uri, {mode = LaunchMode.platformDefault}) async =>
                false,
          ),
          auth: auth,
          appConfig: configProvider,
          size: _tall,
        );

        expect(find.text(l10n.contactWhatsApp), findsOneWidget);
        await tester.tap(find.text(l10n.contactWhatsApp));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(l10n.supportOpenFailed), findsOneWidget);
      });

      testWidgets('does not overflow on a small phone', (tester) async {
        final auth = await signedInAuth(
          name: 'A very long student name that keeps going and going',
          phone: '+201000000000',
        );
        await pumpScreen(
          tester,
          locale,
          const SettingsScreen(),
          auth: auth,
          size: const Size(320, 568),
        );
        expect(tester.takeException(), isNull);
      });
    });
  }
}
