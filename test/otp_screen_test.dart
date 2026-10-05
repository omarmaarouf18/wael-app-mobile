import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/screens/otp_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/otp_pin_input.dart';
import 'package:wael_app/widgets/themed_error_banner.dart';

import 'fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

Future<AuthProvider> pendingAuth(FakeAuthRepository repo) async {
  final auth = makeAuth(repository: repo);
  await auth.signup(
    fullName: 'Test User',
    phone: '+201000000000',
    email: 'u@e.com',
    password: 'password123',
  );
  return auth;
}

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);

    group('OtpScreen [$name]', () {
      testWidgets('shows the shared shell, title, email and OtpPinInput', (
        tester,
      ) async {
        final auth = await pendingAuth(FakeAuthRepository());
        await pumpScreen(tester, locale, const OtpScreen(), auth: auth);
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.text(l10n.verifyCode), findsOneWidget);
        expect(find.text('u@e.com'), findsOneWidget);
        expect(find.byType(OtpPinInput), findsOneWidget);
        expect(find.text(upper(l10n.verify)), findsOneWidget);
        // The dev OTP panel is debug-only; tests run in debug mode.
        expect(find.text('DEBUG OTP: 123456'), findsOneWidget);
      });

      testWidgets('title sits at the start edge ($direction)', (tester) async {
        final auth = await pendingAuth(FakeAuthRepository());
        await pumpScreen(tester, locale, const OtpScreen(), auth: auth);
        final width = tester.getSize(find.byType(Scaffold)).width;
        final title = find.text(l10n.verifyCode);
        if (direction == TextDirection.ltr) {
          expect(tester.getTopLeft(title).dx, lessThan(width / 2));
          expect(tester.getTopLeft(title).dx, lessThan(40));
        } else {
          expect(tester.getTopRight(title).dx, greaterThan(width / 2));
          expect(tester.getTopRight(title).dx, greaterThan(width - 40));
        }
      });

      testWidgets('code boxes stay left to right', (tester) async {
        final auth = await pendingAuth(FakeAuthRepository());
        await pumpScreen(tester, locale, const OtpScreen(), auth: auth);
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pump();
        expect(
          tester.getCenter(find.text('1')).dx,
          lessThan(tester.getCenter(find.text('6')).dx),
        );
      });

      testWidgets('no back button when nothing to pop, one when pushed', (
        tester,
      ) async {
        final auth = await pendingAuth(FakeAuthRepository());
        await pumpScreen(tester, locale, const OtpScreen(), auth: auth);
        expect(find.byTooltip(l10n.back), findsNothing);

        await pumpScreen(
          tester,
          locale,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const OtpScreen()),
              ),
              child: const Text('open'),
            ),
          ),
          auth: auth,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byTooltip(l10n.back), findsOneWidget);
        await tester.tap(find.byTooltip(l10n.back));
        await tester.pumpAndSettle();
        expect(find.byType(OtpScreen), findsNothing);
      });

      testWidgets('oneTimeCode autofill with done submit', (tester) async {
        final auth = await pendingAuth(FakeAuthRepository());
        await pumpScreen(tester, locale, const OtpScreen(), auth: auth);
        expect(find.byType(AutofillGroup), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
        expect(field.textInputAction, TextInputAction.done);
      });

      testWidgets('done submits the code', (tester) async {
        final repo = FakeAuthRepository();
        final auth = await pendingAuth(repo);
        await pumpScreen(tester, locale, const OtpScreen(), auth: auth);
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(repo.verifyOtpCalls, 1);
        expect(find.text('route:/main'), findsOneWidget);
      });

      testWidgets('a correct code calls verifyOtp once and goes to /main', (
        tester,
      ) async {
        final repo = FakeAuthRepository();
        final auth = await pendingAuth(repo);
        await pumpScreen(tester, locale, const OtpScreen(), auth: auth);
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pump();
        await tester.tap(find.text(upper(l10n.verify)));
        await tester.pumpAndSettle();
        expect(repo.verifyOtpCalls, 1);
        expect(repo.lastOtpCode, '123456');
        expect(find.text('route:/main'), findsOneWidget);
      });

      testWidgets('a wrong code shows a persistent banner with retry', (
        tester,
      ) async {
        final repo = FakeAuthRepository(mode: 'wrong-otp');
        final auth = await pendingAuth(repo);
        await pumpScreen(tester, locale, const OtpScreen(), auth: auth);
        await tester.enterText(find.byType(TextField), '000000');
        await tester.pump();
        await tester.tap(find.text(upper(l10n.verify)));
        await tester.pumpAndSettle();

        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        expect(find.text('route:/main'), findsNothing);
        await tester.pump(const Duration(minutes: 1));
        expect(find.byType(ThemedErrorBanner), findsOneWidget);

        expect(repo.verifyOtpCalls, 1);
        await tester.tap(find.text(l10n.retry));
        await tester.pumpAndSettle();
        expect(repo.verifyOtpCalls, 2);
        expect(repo.lastOtpCode, '000000');
      });

      testWidgets('resend button sends a new code and starts a cooldown', (
        tester,
      ) async {
        final repo = FakeAuthRepository();
        final auth = await pendingAuth(repo);
        await pumpScreen(tester, locale, const OtpScreen(), auth: auth);
        expect(find.text(l10n.resendCode), findsOneWidget);
        await tester.tap(find.text(l10n.resendCode));
        await tester.pumpAndSettle();
        expect(repo.resendSignupCalls, 1);
        expect(repo.lastResendEmail, 'u@e.com');
        // Cooldown message replaces the button.
        expect(find.text(l10n.resendCode), findsNothing);
      });
    });
  }
}

String upper(String s) => s.toUpperCase();
