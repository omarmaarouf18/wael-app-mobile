import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/l10n/app_localizations.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/account_provider.dart';
import 'package:wael_app/screens/login_screen.dart';
import 'package:wael_app/screens/main_shell.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/screens/settings/delete_account_screen.dart';
import 'package:wael_app/screens/settings_screen.dart';
import 'package:wael_app/widgets/primary_button.dart';

import 'academy_fakes.dart';
import 'account_fakes.dart';
import 'fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _tall = Size(390, 1800);

Future<AccountProvider> accountsWith(
  FakeAccountRepository repo,
  Locale locale,
) async => AccountProvider(
  auth: await signedInAuth(),
  repository: repo,
  localeReader: () => locale.languageCode,
);

AcademyCatalogProvider ownedCatalog() {
  final repo = fake();
  repo.subjectsByLevel['bachelor-y1'] = [
    subject(
      's9',
      'bachelor-y1',
      en: 'Civil Law',
      ar: 'القانون المدني',
      owned: true,
    ),
  ];
  return AcademyCatalogProvider(repo);
}

Future<void> openDelete(
  WidgetTester tester,
  Locale locale,
  FakeAccountRepository repo,
) async {
  final catalog = ownedCatalog();
  await catalog.reload();
  await pumpScreen(
    tester,
    locale,
    const SettingsScreen(),
    accounts: await accountsWith(repo, locale),
    extraProviders: [
      ChangeNotifierProvider.value(value: catalog),
      ChangeNotifierProvider(create: (_) => HomeProvider()),
    ],
    size: _tall,
  );
  await tester.tap(find.text(l10nOf(locale).deleteAccount.toUpperCase()));
  await tester.pumpAndSettle();
}

AppLocalizations l10nOf(Locale locale) => l10nFor(locale);

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);

    group('Delete account [$name]', () {
      testWidgets('warning names the active subjects', (tester) async {
        await openDelete(tester, locale, FakeAccountRepository());
        expect(find.byType(DeleteAccountScreen), findsOneWidget);
        expect(find.text(l10n.deleteAccountWarning), findsOneWidget);
        expect(find.text(l10n.deleteAccountLoseAccess), findsOneWidget);
        expect(
          find.text(
            locale.languageCode == 'ar' ? 'القانون المدني' : 'Civil Law',
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.deleteAccountGrace), findsOneWidget);
      });

      testWidgets('button stays disabled until حذف plus password', (
        tester,
      ) async {
        final repo = FakeAccountRepository();
        await openDelete(tester, locale, repo);
        final fields = find.byType(TextFormField);
        final button = find.widgetWithText(FilledButton, l10n.deleteAccount);
        // Password only: still disabled.
        await tester.enterText(fields.at(0), 'Password123!');
        await tester.tap(button, warnIfMissed: false);
        await tester.pump();
        expect(repo.deletionCalls, 0);
        // Wrong confirm word: still disabled.
        await tester.enterText(fields.at(1), 'حذفx');
        await tester.tap(button, warnIfMissed: false);
        await tester.pump();
        expect(repo.deletionCalls, 0);
        // Exact word: enabled.
        await tester.enterText(fields.at(1), 'حذف');
        await tester.pump();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(repo.deletionCalls, 1);
        expect(repo.lastDeletionPassword, 'Password123!');
      });

      testWidgets('wrong password stays with a message', (tester) async {
        final repo = FakeAccountRepository()
          ..deletionError = ApiException(
            statusCode: 401,
            message: 'invalid credentials',
          );
        await openDelete(tester, locale, repo);
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'wrong');
        await tester.enterText(fields.at(1), 'حذف');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, l10n.deleteAccount));
        await tester.pumpAndSettle();
        expect(
          find.text(ErrorMessages.invalidCredentials(l10n.isArabic)),
          findsOneWidget,
        );
        expect(find.byType(DeleteAccountScreen), findsOneWidget);
      });

      testWidgets('success shows the date, then login', (tester) async {
        final repo = FakeAccountRepository()..deletionDate = '2026-11-05';
        await openDelete(tester, locale, repo);
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Password123!');
        await tester.enterText(fields.at(1), 'حذف');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, l10n.deleteAccount));
        await tester.pumpAndSettle();
        expect(find.text(l10n.deletionScheduled('2026-11-05')), findsOneWidget);
        await tester.tap(find.text(l10n.backToLogin));
        await tester.pumpAndSettle();
        expect(find.text('route:/login'), findsOneWidget);
      });

      testWidgets('login with deletion_cancelled shows the notice', (
        tester,
      ) async {
        final auth = makeAuth(
          repository: FakeAuthRepository(mode: 'deletion-cancelled'),
        );
        await pumpScreen(
          tester,
          locale,
          const LoginScreen(),
          auth: auth,
          size: _tall,
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'u@e.com');
        await tester.enterText(fields.at(1), 'Password123!');
        await tester.tap(
          find.widgetWithText(PrimaryButton, l10n.signIn.toUpperCase()),
        );
        await tester.pumpAndSettle();
        expect(find.text('route:/main'), findsOneWidget);

        await pumpScreen(
          tester,
          locale,
          const MainShell(),
          auth: auth,
          extraProviders: [
            ChangeNotifierProvider.value(value: ownedCatalog()),
            ChangeNotifierProvider(create: (_) => HomeProvider()),
          ],
          size: const Size(390, 844),
        );
        await tester.pump();
        expect(find.text(l10n.deletionCancelledNotice), findsOneWidget);
        await tester.pumpAndSettle();
      });
    });
  }
}
