import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/screens/signup_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/primary_button.dart';
import 'package:wael_app/widgets/themed_error_banner.dart';
import 'package:wael_app/widgets/themed_text_field.dart';

import 'fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _tall = Size(390, 1400);

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';
    final submitLabel = l10n.signUp.toUpperCase();

    Future<void> pump(WidgetTester tester, {FakeAuthRepository? repo}) =>
        pumpScreen(
          tester,
          locale,
          const SignupScreen(),
          auth: makeAuth(repository: repo),
          size: _tall,
        );

    Future<void> fill(
      WidgetTester tester, {
      String password = 'password123',
      String confirm = 'password123',
    }) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Jane Doe');
      await tester.enterText(fields.at(1), 'jane@e.com');
      await tester.enterText(fields.at(2), '+201000000000');
      await tester.enterText(fields.at(3), password);
      await tester.enterText(fields.at(4), confirm);
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(PrimaryButton, submitLabel));
      await tester.pumpAndSettle();
    }

    Future<void> agreeToTerms(WidgetTester tester) async {
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
    }

    group('SignupScreen [$name]', () {
      testWidgets('shell with brand lockup and a localised form', (
        tester,
      ) async {
        await pump(tester);
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.text('EL METR'), findsOneWidget);
        expect(find.text('ACADEMY'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(5));
        expect(find.text(l10n.phoneNumber), findsOneWidget);
        expect(find.text(l10n.agreeToTerms), findsOneWidget);
        expect(find.byType(ThemedErrorBanner), findsNothing);
      });

      testWidgets('directional layout ($direction)', (tester) async {
        await pump(tester);
        final width = 390.0;
        // Back button at the start edge, brand lockup after it.
        expect(
          startsBefore(
            tester,
            find.byTooltip(l10n.back),
            find.text('EL METR'),
            direction,
          ),
          isTrue,
        );
        // Heading at the start edge.
        final heading = find.text(l10n.signUp).first;
        if (direction == TextDirection.ltr) {
          expect(tester.getTopLeft(heading).dx, lessThan(40));
        } else {
          expect(tester.getTopRight(heading).dx, greaterThan(width - 40));
        }
        // Terms checkbox precedes its text.
        expect(
          startsBefore(
            tester,
            find.byType(Checkbox),
            find.text(l10n.agreeToTerms),
            direction,
          ),
          isTrue,
        );
        // Field prefix icon sits at the start edge of its field.
        expect(
          startsBefore(
            tester,
            find.byIcon(Icons.person_outline),
            find.byType(TextFormField).first,
            direction,
          ),
          isTrue,
        );
      });

      testWidgets('back button pops the route', (tester) async {
        await pumpScreen(
          tester,
          locale,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SignupScreen()),
              ),
              child: const Text('open'),
            ),
          ),
          size: _tall,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(SignupScreen), findsOneWidget);
        await tester.tap(find.byTooltip(l10n.back));
        await tester.pumpAndSettle();
        expect(find.byType(SignupScreen), findsNothing);
      });

      testWidgets('empty form: inline field errors, no banner, no API call', (
        tester,
      ) async {
        final repo = FakeAuthRepository();
        await pump(tester, repo: repo);
        await agreeToTerms(tester);
        await submit(tester);
        // Field errors render inline under each field; the banner stays for
        // server errors only.
        expect(find.byType(ThemedErrorBanner), findsNothing);
        expect(repo.signupCalls, 0);
        expect(find.text(ErrorMessages.emptyField(isArabic)), findsNWidgets(5));
        await tester.pump(const Duration(minutes: 1));
        expect(find.byType(ThemedErrorBanner), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('field errors appear on blur', (tester) async {
        await pump(tester);
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'not-an-email',
        );
        // Moving focus away validates the blurred field inline.
        await tester.tap(find.byType(TextFormField).at(2));
        await tester.pump();
        expect(find.text(ErrorMessages.invalidEmail(isArabic)), findsOneWidget);
        expect(find.byType(ThemedErrorBanner), findsNothing);
      });

      testWidgets('autofill hints and next/done chain', (tester) async {
        await pump(tester);
        expect(find.byType(AutofillGroup), findsOneWidget);
        final fields = tester.widgetList<ThemedTextField>(
          find.byType(ThemedTextField),
        );
        expect(fields.elementAt(0).autofillHints, contains(AutofillHints.name));
        expect(
          fields.elementAt(1).autofillHints,
          contains(AutofillHints.email),
        );
        expect(
          fields.elementAt(2).autofillHints,
          contains(AutofillHints.telephoneNumber),
        );
        expect(
          fields.elementAt(3).autofillHints,
          contains(AutofillHints.newPassword),
        );
        expect(fields.elementAt(3).textInputAction, TextInputAction.next);
        expect(fields.elementAt(4).textInputAction, TextInputAction.done);
        expect(fields.elementAt(4).onFieldSubmitted, isNotNull);
      });

      testWidgets('next moves focus, done submits', (tester) async {
        final repo = FakeAuthRepository();
        await pump(tester, repo: repo);
        await agreeToTerms(tester);
        await fill(tester);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(repo.signupCalls, 1);
        expect(find.text('route:/otp'), findsOneWidget);
      });

      testWidgets('password rules show live under the field', (tester) async {
        await pump(tester);
        expect(find.text(l10n.passwordRuleLength), findsOneWidget);
        expect(find.text(l10n.passwordRuleBytes), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).at(3), 'short');
        await tester.pump();
        expect(
          find.text(ErrorMessages.passwordMinLength(isArabic, 8)),
          findsOneWidget,
        );
      });

      testWidgets('short password and mismatch are reported', (tester) async {
        final repo = FakeAuthRepository();
        await pump(tester, repo: repo);
        await agreeToTerms(tester);
        await fill(tester, password: 'short', confirm: 'short');
        await submit(tester);
        expect(
          find.text(ErrorMessages.passwordMinLength(isArabic, 8)),
          findsOneWidget,
        );

        await fill(tester, confirm: 'different123');
        await submit(tester);
        expect(
          find.text(ErrorMessages.passwordMismatch(isArabic)),
          findsOneWidget,
        );
        expect(
          find.text(ErrorMessages.passwordMinLength(isArabic, 8)),
          findsNothing,
        );
        expect(repo.signupCalls, 0);
      });

      testWidgets('consent unticked by default; submit disabled until ticked', (
        tester,
      ) async {
        final repo = FakeAuthRepository();
        await pump(tester, repo: repo);
        await fill(tester);
        // Button disabled while unticked: tapping does nothing, no API call.
        await submit(tester);
        expect(repo.signupCalls, 0);
        expect(find.text('route:/otp'), findsNothing);
        // Ticking enables the submit.
        await agreeToTerms(tester);
        await submit(tester);
        expect(repo.signupCalls, 1);
        expect(find.text('route:/otp'), findsOneWidget);
      });

      testWidgets('long password over 72 bytes is reported', (tester) async {
        final repo = FakeAuthRepository();
        await pump(tester, repo: repo);
        await agreeToTerms(tester);
        final longPw = List.filled(73, 'a').join();
        await fill(tester, password: longPw, confirm: longPw);
        await submit(tester);
        expect(
          find.text(ErrorMessages.passwordTooLong(isArabic)),
          findsOneWidget,
        );
        expect(repo.signupCalls, 0);
      });

      testWidgets('valid form: one signup call, then /otp', (tester) async {
        final repo = FakeAuthRepository();
        await pump(tester, repo: repo);
        await fill(tester);
        await agreeToTerms(tester);
        await submit(tester);
        expect(repo.signupCalls, 1);
        expect(repo.lastSignupEmail, 'jane@e.com');
        expect(find.text('route:/otp'), findsOneWidget);
      });

      testWidgets('server error: persistent banner, retry signs up again', (
        tester,
      ) async {
        final repo = FakeAuthRepository(mode: 'signup-conflict');
        await pump(tester, repo: repo);
        await fill(tester);
        await agreeToTerms(tester);
        await submit(tester);
        expect(repo.signupCalls, 1);
        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        expect(find.text('route:/otp'), findsNothing);
        await tester.pump(const Duration(minutes: 1));
        expect(find.byType(ThemedErrorBanner), findsOneWidget);

        await tester.tap(find.text(l10n.retry));
        await tester.pumpAndSettle();
        expect(repo.signupCalls, 2);
      });

      testWidgets('terms link opens the server terms URL', (tester) async {
        final launched = <Uri>[];
        final appConfig = AppConfigProvider(cache: MemoryAppConfigCache())
          ..setForTesting(
            const AppConfigData(
              termsUrl: 'https://legal.elmetracademy.app/terms',
            ),
          );
        await pumpScreen(
          tester,
          locale,
          SignupScreen(
            launchUrl: (uri, {mode = LaunchMode.externalApplication}) async {
              launched.add(uri);
              return true;
            },
          ),
          appConfig: appConfig,
          size: _tall,
        );
        await tester.tap(find.text(l10n.readTerms));
        await tester.pump();
        expect(launched.map((u) => u.toString()), [
          'https://legal.elmetracademy.app/terms',
        ]);
      });

      testWidgets('terms link hides until the server configures it', (
        tester,
      ) async {
        await pump(tester);
        expect(find.text(l10n.readTerms), findsNothing);
      });
    });
  }
}
