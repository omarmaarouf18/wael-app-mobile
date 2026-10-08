import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:wael_app/core/theme.dart';
import 'package:wael_app/l10n/app_localizations.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/account_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/screens/signup_screen.dart';
import 'package:wael_app/widgets/primary_button.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _tall = Size(390, 1400);

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';
    String en(String url) => isArabic ? url : '$url#en';

    Future<List<Uri>> pumpWithLauncher(
      WidgetTester tester, {
      AppConfigData data = const AppConfigData(),
    }) async {
      final launched = <Uri>[];
      await pumpScreen(
        tester,
        locale,
        SignupScreen(
          launchUrl: (uri, {mode = LaunchMode.externalApplication}) async {
            launched.add(uri);
            return true;
          },
        ),
        appConfig: AppConfigProvider()..setForTesting(data),
        size: _tall,
      );
      return launched;
    }

    Future<void> openSheet(WidgetTester tester, String linkLabel) async {
      // No sheet may be open from an earlier test (routes survive
      // pumpWidget on the same Navigator and would swallow the tap).
      expect(find.text(l10n.legalSheetTitle), findsNothing);
      // The consent names are inline link buttons with exact text.
      await tester.tap(find.text(linkLabel));
      await tester.pumpAndSettle();
      expect(find.text(l10n.legalSheetTitle), findsOneWidget);
    }

    /// Every test closes the sheet it opened, so no route leaks into the
    /// next test's tree (routes survive pumpWidget on the same Navigator).
    Future<void> closeSheet(WidgetTester tester) async {
      await tester.tap(find.text(l10n.legalAgree));
      await tester.pumpAndSettle();
      expect(find.text(l10n.legalSheetTitle), findsNothing);
    }

    group('Legal summary sheet [$name]', () {
      testWidgets('consent links stay visible with empty app-config', (
        tester,
      ) async {
        await pumpWithLauncher(tester);
        expect(find.text(l10n.termsLinkLabel), findsOneWidget);
        expect(find.text(l10n.privacyLinkLabel), findsOneWidget);
      });

      testWidgets('tapping the terms link opens the sheet', (tester) async {
        await pumpWithLauncher(tester);
        await openSheet(tester, l10n.termsLinkLabel);
        expect(find.text(l10n.termsSummaryTitle), findsOneWidget);
        for (final bullet in l10n.termsSummaryBullets) {
          expect(find.text(bullet), findsOneWidget);
        }
        await closeSheet(tester);
      });

      testWidgets('tapping the privacy link opens the sheet', (tester) async {
        await pumpWithLauncher(tester);
        await openSheet(tester, l10n.privacyLinkLabel);
        expect(find.text(l10n.privacySummaryTitle), findsOneWidget);
        for (final bullet in l10n.privacySummaryBullets) {
          expect(find.text(bullet), findsOneWidget);
        }
        await closeSheet(tester);
      });

      testWidgets('opening a link does not tick the checkbox', (tester) async {
        await pumpWithLauncher(tester);
        await openSheet(tester, l10n.termsLinkLabel);
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(find.text(l10n.legalSheetTitle), findsNothing);
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      });

      testWidgets('agree button closes the sheet and ticks the checkbox', (
        tester,
      ) async {
        await pumpWithLauncher(tester);
        await openSheet(tester, l10n.privacyLinkLabel);
        await tester.tap(find.text(l10n.legalAgree));
        await tester.pumpAndSettle();
        expect(find.text(l10n.legalSheetTitle), findsNothing);
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
        // The submit CTA is enabled once the box is ticked.
        final submit = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
        expect(submit.onPressed, isNotNull);
      });

      testWidgets('full-page buttons open the fallback pages', (tester) async {
        final launched = await pumpWithLauncher(tester);
        await openSheet(tester, l10n.termsLinkLabel);
        await tester.tap(find.text(l10n.readTermsFull));
        await tester.pump();
        await tester.tap(find.text(l10n.readPrivacyFull));
        await tester.pump();
        expect(launched.map((u) => u.toString()), [
          en('https://legal.elmetracademy.app/terms'),
          en('https://legal.elmetracademy.app/privacy'),
        ]);
        await closeSheet(tester);
      });

      testWidgets('full-page buttons use the server URLs when configured', (
        tester,
      ) async {
        final launched = await pumpWithLauncher(
          tester,
          data: const AppConfigData(
            termsUrl: 'https://example.com/custom-terms',
            privacyUrl: 'https://example.com/custom-privacy',
          ),
        );
        await openSheet(tester, l10n.termsLinkLabel);
        await tester.tap(find.text(l10n.readTermsFull));
        await tester.pump();
        await tester.tap(find.text(l10n.readPrivacyFull));
        await tester.pump();
        expect(launched.map((u) => u.toString()), [
          en('https://example.com/custom-terms'),
          en('https://example.com/custom-privacy'),
        ]);
        await closeSheet(tester);
      });

      testWidgets('sheet has no overflow at 2.0x text scaling', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final auth = makeAuth();
        await tester.pumpWidget(
          MultiProvider(
            providers: <SingleChildWidget>[
              ChangeNotifierProvider(create: (_) => LocaleProvider()),
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider.value(value: NotificationsProvider()),
              ChangeNotifierProvider.value(
                value: AppConfigProvider()
                  ..setForTesting(const AppConfigData()),
              ),
              ChangeNotifierProvider.value(
                value: AccountProvider(
                  auth: auth,
                  repository: null,
                  localeReader: () => locale.languageCode,
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              locale: locale,
              supportedLocales: const [Locale('en', ''), Locale('ar', '')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2.0)),
                child: child!,
              ),
              home: const SignupScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final consent = find.text(l10n.termsLinkLabel);
        await tester.ensureVisible(consent);
        await tester.pumpAndSettle();
        await tester.tap(consent);
        await tester.pumpAndSettle();
        expect(find.text(l10n.legalSheetTitle), findsOneWidget);
        for (final bullet in [
          ...l10n.termsSummaryBullets,
          ...l10n.privacySummaryBullets,
        ]) {
          expect(find.text(bullet), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        final agree = find.text(l10n.legalAgree);
        await tester.ensureVisible(agree);
        await tester.pumpAndSettle();
        await tester.tap(agree);
        await tester.pumpAndSettle();
        expect(find.text(l10n.legalSheetTitle), findsNothing);
      });
    });
  }
}
