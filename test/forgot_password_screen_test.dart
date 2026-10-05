import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/screens/forgot_password_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/otp_pin_input.dart';
import 'package:wael_app/widgets/primary_button.dart';
import 'package:wael_app/widgets/themed_error_banner.dart';
import 'package:wael_app/widgets/themed_text_field.dart';

import 'fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    String upper(String s) => s.toUpperCase();

    group('ForgotPasswordScreen [$name]', () {
      testWidgets('step 0 shows the shell, heading and email field', (
        tester,
      ) async {
        await pumpScreen(tester, locale, const ForgotPasswordScreen());
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.text(l10n.resetPassword), findsOneWidget);
        expect(find.text(l10n.resetSentNote), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text(upper(l10n.sendCode)), findsOneWidget);
        expect(find.byType(OtpPinInput), findsNothing);
      });

      testWidgets('heading sits at the start edge ($direction)', (
        tester,
      ) async {
        await pumpScreen(tester, locale, const ForgotPasswordScreen());
        final width = tester.getSize(find.byType(Scaffold)).width;
        final heading = find.text(l10n.resetPassword);
        if (direction == TextDirection.ltr) {
          expect(tester.getTopLeft(heading).dx, lessThan(40));
        } else {
          expect(tester.getTopRight(heading).dx, greaterThan(width - 40));
        }
      });

      testWidgets('three steps: request, verify with OtpPinInput, confirm', (
        tester,
      ) async {
        final repo = FakeAuthRepository();
        await pumpScreen(
          tester,
          locale,
          const ForgotPasswordScreen(),
          auth: makeAuth(repository: repo),
        );
        await tester.enterText(find.byType(TextFormField), 'u@e.com');
        await tester.tap(find.text(upper(l10n.sendCode)));
        await tester.pumpAndSettle();
        expect(repo.requestResetCalls, 1);
        expect(find.byType(OtpPinInput), findsOneWidget);
        expect(find.text('DEBUG OTP: 654321'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '654321');
        await tester.pump();
        await tester.tap(find.text(upper(l10n.verify)));
        await tester.pumpAndSettle();
        expect(repo.verifyResetCalls, 1);
        expect(find.byType(OtpPinInput), findsNothing);
        expect(find.text(l10n.newPassword), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), 'newpassword1');
        await tester.tap(
          find.widgetWithText(PrimaryButton, upper(l10n.resetPassword)),
        );
        await tester.pumpAndSettle();
        expect(repo.confirmResetCalls, 1);
        expect(find.text('route:/login'), findsOneWidget);
      });

      testWidgets('email errors appear inline, no banner', (tester) async {
        final repo = FakeAuthRepository();
        await pumpScreen(
          tester,
          locale,
          const ForgotPasswordScreen(),
          auth: makeAuth(repository: repo),
        );
        await tester.enterText(find.byType(TextFormField), 'not-an-email');
        await tester.pump();
        expect(
          find.text(ErrorMessages.invalidEmail(locale.languageCode == 'ar')),
          findsOneWidget,
        );
        expect(find.byType(ThemedErrorBanner), findsNothing);
        expect(repo.requestResetCalls, 0);
      });

      testWidgets('autofill hints and done submits', (tester) async {
        final repo = FakeAuthRepository();
        await pumpScreen(
          tester,
          locale,
          const ForgotPasswordScreen(),
          auth: makeAuth(repository: repo),
        );
        expect(find.byType(AutofillGroup), findsOneWidget);
        final email = tester.widget<ThemedTextField>(
          find.byType(ThemedTextField),
        );
        expect(email.autofillHints, contains(AutofillHints.email));
        expect(email.textInputAction, TextInputAction.done);

        await tester.enterText(find.byType(TextFormField), 'u@e.com');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(repo.requestResetCalls, 1);
        expect(find.byType(OtpPinInput), findsOneWidget);
      });

      testWidgets('new-password visibility toggles', (tester) async {
        await pumpScreen(tester, locale, const ForgotPasswordScreen());
        await tester.enterText(find.byType(TextFormField), 'u@e.com');
        await tester.tap(find.text(upper(l10n.sendCode)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '654321');
        await tester.pump();
        await tester.tap(find.text(upper(l10n.verify)));
        await tester.pumpAndSettle();
        expect(find.text(l10n.newPassword), findsOneWidget);
        bool obscured() => tester
            .widget<EditableText>(find.byType(EditableText).last)
            .obscureText;
        expect(obscured(), isTrue);
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pump();
        expect(obscured(), isFalse);
      });

      testWidgets('72-byte password limit is reported inline', (tester) async {
        final repo = FakeAuthRepository();
        await pumpScreen(
          tester,
          locale,
          const ForgotPasswordScreen(),
          auth: makeAuth(repository: repo),
        );
        await tester.enterText(find.byType(TextFormField), 'u@e.com');
        await tester.tap(find.text(upper(l10n.sendCode)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '654321');
        await tester.pump();
        await tester.tap(find.text(upper(l10n.verify)));
        await tester.pumpAndSettle();
        final longPw = List.filled(73, 'a').join();
        await tester.enterText(find.byType(TextFormField), longPw);
        await tester.pump();
        expect(find.text(l10n.passwordRuleLength), findsOneWidget);
        expect(find.text(l10n.passwordRuleBytes), findsOneWidget);
        await tester.tap(
          find.widgetWithText(PrimaryButton, upper(l10n.resetPassword)),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(ErrorMessages.passwordTooLong(locale.languageCode == 'ar')),
          findsOneWidget,
        );
        expect(repo.confirmResetCalls, 0);
      });

      testWidgets('a wrong code shows a persistent banner; retry re-verifies', (
        tester,
      ) async {
        final repo = FakeAuthRepository(mode: 'wrong-reset-code');
        await pumpScreen(
          tester,
          locale,
          const ForgotPasswordScreen(),
          auth: makeAuth(repository: repo),
        );
        await tester.enterText(find.byType(TextFormField), 'u@e.com');
        await tester.tap(find.text(upper(l10n.sendCode)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '000000');
        await tester.pump();
        await tester.tap(find.text(upper(l10n.verify)));
        await tester.pumpAndSettle();

        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        await tester.pump(const Duration(minutes: 1));
        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        expect(repo.verifyResetCalls, 1);
        await tester.tap(find.text(l10n.retry));
        await tester.pumpAndSettle();
        expect(repo.verifyResetCalls, 2);
        expect(find.text(l10n.newPassword), findsNothing);
      });
    });
  }
}
