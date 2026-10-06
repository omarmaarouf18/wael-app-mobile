import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/providers/account_provider.dart';
import 'package:wael_app/screens/settings/email_change_screen.dart';
import 'package:wael_app/screens/settings_screen.dart';
import 'package:wael_app/widgets/otp_pin_input.dart';

import 'account_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _tall = Size(390, 1800);

Future<AccountProvider> accountsWith(
  WidgetTester tester,
  FakeAccountRepository repo,
  Locale locale,
) async => AccountProvider(
  auth: await signedInAuth(),
  repository: repo,
  localeReader: () => locale.languageCode,
);

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);

    group('Email change [$name]', () {
      testWidgets('email row opens the change screen', (tester) async {
        await pumpScreen(
          tester,
          locale,
          const SettingsScreen(),
          accounts: await accountsWith(tester, FakeAccountRepository(), locale),
          size: _tall,
        );
        await tester.tap(find.text(l10n.email));
        await tester.pumpAndSettle();
        expect(find.byType(EmailChangeScreen), findsOneWidget);
        expect(find.text(l10n.newEmailLabel), findsOneWidget);
      });

      testWidgets('code step follows a successful send', (tester) async {
        final repo = FakeAccountRepository();
        await pumpScreen(
          tester,
          locale,
          const EmailChangeScreen(),
          accounts: await accountsWith(tester, repo, locale),
          size: _tall,
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'new@e.com');
        await tester.enterText(fields.at(1), 'Password123!');
        await tester.tap(find.text(l10n.sendCodeAction));
        await tester.pumpAndSettle();
        expect(repo.emailChangeCalls, 1);
        expect(repo.lastNewEmail, 'new@e.com');
        expect(find.byType(OtpPinInput), findsOneWidget);
        expect(find.text(l10n.emailCodeSent), findsOneWidget);
      });

      testWidgets('wrong password stays on step one', (tester) async {
        final repo = FakeAccountRepository()
          ..emailChangeError = ApiException(
            statusCode: 401,
            message: 'invalid credentials',
          );
        await pumpScreen(
          tester,
          locale,
          const EmailChangeScreen(),
          accounts: await accountsWith(tester, repo, locale),
          size: _tall,
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'new@e.com');
        await tester.enterText(fields.at(1), 'wrong');
        await tester.tap(find.text(l10n.sendCodeAction));
        await tester.pumpAndSettle();
        expect(
          find.text(ErrorMessages.invalidCredentials(l10n.isArabic)),
          findsOneWidget,
        );
        expect(find.byType(OtpPinInput), findsNothing);
      });

      testWidgets('confirm success ends at login', (tester) async {
        final repo = FakeAccountRepository();
        await pumpScreen(
          tester,
          locale,
          const EmailChangeScreen(),
          accounts: await accountsWith(tester, repo, locale),
          size: _tall,
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'new@e.com');
        await tester.enterText(fields.at(1), 'Password123!');
        await tester.tap(find.text(l10n.sendCodeAction));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(OtpPinInput), '123456');
        await tester.pumpAndSettle();
        expect(repo.emailConfirmCalls, 1);
        expect(repo.lastCode, '123456');
        expect(find.text('route:/login'), findsOneWidget);
      });

      testWidgets('wrong code stays with a clear message', (tester) async {
        final repo = FakeAccountRepository()
          ..emailConfirmError = ApiException(
            statusCode: 401,
            message: 'invalid or expired code',
            code: 'invalid_token',
          );
        await pumpScreen(
          tester,
          locale,
          const EmailChangeScreen(),
          accounts: await accountsWith(tester, repo, locale),
          size: _tall,
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'new@e.com');
        await tester.enterText(fields.at(1), 'Password123!');
        await tester.tap(find.text(l10n.sendCodeAction));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(OtpPinInput), '000000');
        await tester.pumpAndSettle();
        expect(
          find.text(ErrorMessages.invalidOrExpiredCode(l10n.isArabic)),
          findsOneWidget,
        );
        expect(find.byType(EmailChangeScreen), findsOneWidget);
      });
    });
  }
}
