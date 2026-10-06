import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/providers/account_provider.dart';
import 'package:wael_app/screens/settings_screen.dart';

import 'account_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _tall = Size(390, 1800);

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);
    String upper(String s) => s.toUpperCase();

    group('SettingsScreen profile [$name]', () {
      testWidgets('name and phone rows show the account and the 30-day note', (
        tester,
      ) async {
        await pumpScreen(tester, locale, const SettingsScreen(), size: _tall);
        expect(find.text(upper(l10n.myAccount)), findsOneWidget);
        expect(find.text(l10n.nameLabel), findsOneWidget);
        expect(find.text(l10n.mobileNumber), findsOneWidget);
        expect(find.text(l10n.changeOnceEvery30Days), findsNWidgets(2));
      });

      testWidgets('editing the name saves with the password', (tester) async {
        final repo = FakeAccountRepository();
        final accounts = AccountProvider(
          auth: await signedInAuth(),
          repository: repo,
          localeReader: () => locale.languageCode,
        );
        await pumpScreen(
          tester,
          locale,
          const SettingsScreen(),
          accounts: accounts,
          size: _tall,
        );
        await tester.tap(find.text(l10n.nameLabel));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'New Name');
        await tester.enterText(fields.at(1), 'Password123!');
        await tester.tap(find.text(l10n.save));
        await tester.pump();
        expect(repo.profileCalls, 1);
        expect(repo.lastFullName, 'New Name');
        expect(repo.lastPhone, isNull);
        expect(repo.lastCurrentPassword, 'Password123!');
        expect(find.text(l10n.profileUpdated), findsOneWidget);
        await tester.pumpAndSettle();
      });

      testWidgets('a wrong current password stays on the sheet', (
        tester,
      ) async {
        final repo = FakeAccountRepository()
          ..profileError = ApiException(
            statusCode: 401,
            message: 'invalid credentials',
          );
        await pumpScreen(
          tester,
          locale,
          const SettingsScreen(),
          accounts: AccountProvider(
            auth: await signedInAuth(),
            repository: repo,
            localeReader: () => locale.languageCode,
          ),
          size: _tall,
        );
        await tester.tap(find.text(l10n.mobileNumber));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), '+201099999999');
        await tester.enterText(fields.at(1), 'wrong');
        await tester.tap(find.text(l10n.save));
        await tester.pumpAndSettle();
        expect(
          find.text(ErrorMessages.invalidCredentials(l10n.isArabic)),
          findsOneWidget,
        );
        expect(find.text(l10n.profileUpdated), findsNothing);
      });

      testWidgets('change_too_soon names the allowed date', (tester) async {
        final repo = FakeAccountRepository()
          ..profileError = changeTooSoon(retryAfter: 86400 * 9);
        await pumpScreen(
          tester,
          locale,
          const SettingsScreen(),
          accounts: AccountProvider(
            auth: await signedInAuth(),
            repository: repo,
            localeReader: () => locale.languageCode,
          ),
          size: _tall,
        );
        await tester.tap(find.text(l10n.nameLabel));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Another Name');
        await tester.enterText(fields.at(1), 'Password123!');
        await tester.tap(find.text(l10n.save));
        await tester.pumpAndSettle();
        final expected = DateTime.now().add(const Duration(days: 9));
        final date =
            '${expected.year}-${expected.month.toString().padLeft(2, '0')}-${expected.day.toString().padLeft(2, '0')}';
        expect(find.textContaining(date), findsOneWidget);
      });
    });
  }
}
