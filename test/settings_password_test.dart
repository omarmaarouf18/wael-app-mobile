import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/providers/account_provider.dart';
import 'package:wael_app/screens/settings/password_change_screen.dart';
import 'package:wael_app/screens/settings_screen.dart';

import 'account_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';
import 'package:wael_app/l10n/app_localizations.dart';

const _tall = Size(390, 1800);

Future<AccountProvider> accountsWith(
  FakeAccountRepository repo,
  Locale locale,
) async => AccountProvider(
  auth: await signedInAuth(),
  repository: repo,
  localeReader: () => locale.languageCode,
);

Future<void> fill(
  WidgetTester tester,
  AppLocalizations l10n, {
  String current = 'Password123!',
  String next = 'NewPassword123!',
  String confirm = 'NewPassword123!',
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), current);
  await tester.enterText(fields.at(1), next);
  await tester.enterText(fields.at(2), confirm);
  await tester.tap(find.text(l10n.save));
  await tester.pump();
}

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);

    group('Password change [$name]', () {
      testWidgets('row opens the change screen', (tester) async {
        await pumpScreen(
          tester,
          locale,
          const SettingsScreen(),
          accounts: await accountsWith(FakeAccountRepository(), locale),
          size: _tall,
        );
        await tester.tap(find.text(l10n.changePasswordTitle));
        await tester.pumpAndSettle();
        expect(find.byType(PasswordChangeScreen), findsOneWidget);
      });

      testWidgets('mismatch never reaches the server', (tester) async {
        final repo = FakeAccountRepository();
        await pumpScreen(
          tester,
          locale,
          const PasswordChangeScreen(),
          accounts: await accountsWith(repo, locale),
          size: _tall,
        );
        await fill(tester, l10n, confirm: 'Different123!');
        expect(repo.passwordCalls, 0);
        expect(
          find.text(ErrorMessages.passwordMismatch(l10n.isArabic)),
          findsOneWidget,
        );
      });

      testWidgets('success confirms and leaves', (tester) async {
        final repo = FakeAccountRepository();
        await pumpScreen(
          tester,
          locale,
          const PasswordChangeScreen(),
          accounts: await accountsWith(repo, locale),
          size: _tall,
        );
        await fill(tester, l10n);
        await tester.pump();
        expect(repo.passwordCalls, 1);
        expect(repo.lastCurrentPassword, 'Password123!');
        expect(repo.lastNewPassword, 'NewPassword123!');
        expect(find.text(l10n.passwordChanged), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.byType(PasswordChangeScreen), findsNothing);
      });

      testWidgets('wrong current password stays with a message', (
        tester,
      ) async {
        final repo = FakeAccountRepository()
          ..passwordError = ApiException(
            statusCode: 401,
            message: 'invalid credentials',
          );
        await pumpScreen(
          tester,
          locale,
          const PasswordChangeScreen(),
          accounts: await accountsWith(repo, locale),
          size: _tall,
        );
        await fill(tester, l10n, current: 'wrong');
        expect(
          find.text(ErrorMessages.invalidCredentials(l10n.isArabic)),
          findsOneWidget,
        );
        expect(find.byType(PasswordChangeScreen), findsOneWidget);
      });
    });
  }
}
