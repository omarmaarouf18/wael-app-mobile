import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/screens/login_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/hero_backdrop.dart';
import 'package:wael_app/widgets/language_toggle_chip.dart';
import 'package:wael_app/widgets/primary_button.dart';
import 'package:wael_app/widgets/themed_error_banner.dart';

import 'fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _tall = Size(390, 1400);

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    final signIn = l10n.signIn.toUpperCase();

    Future<void> pump(WidgetTester tester, {FakeAuthRepository? repo}) =>
        pumpScreen(
          tester,
          locale,
          const LoginScreen(),
          auth: makeAuth(repository: repo),
          size: _tall,
        );

    Future<void> submit(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField).at(0), 'u@e.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.widgetWithText(PrimaryButton, signIn));
      await tester.pumpAndSettle();
    }

    group('LoginScreen [$name]', () {
      testWidgets('renders on the shared shell with the hero backdrop', (
        tester,
      ) async {
        await pump(tester);
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(HeroBackdrop), findsOneWidget);
        expect(find.text('EL METR'), findsOneWidget);
        expect(find.text('ACADEMY'), findsOneWidget);
        // In Arabic the heading and the (case-less) button label are the same.
        expect(
          find.text(l10n.signIn),
          findsNWidgets(locale.languageCode == 'ar' ? 2 : 1),
        );
        expect(find.text(l10n.rememberMe), findsOneWidget);
        expect(find.text(l10n.forgotPassword), findsOneWidget);
        expect(find.text(l10n.createAccountPrompt), findsOneWidget);
      });

      testWidgets('hero art is full bleed (starts at the top edge)', (
        tester,
      ) async {
        await pump(tester);
        expect(tester.getTopLeft(find.byType(HeroBackdrop)).dy, 0);
        expect(tester.getSize(find.byType(HeroBackdrop)).width, 390);
      });

      testWidgets('directional layout ($direction)', (tester) async {
        await pump(tester);
        final width = 390.0;
        // Language chip sits at the end edge of the top bar.
        final chip = tester.getCenter(find.byType(LanguageToggleChip)).dx;
        // Heading and the remember-me / forgot-password row.
        final heading = tester.getCenter(find.text(l10n.signIn).first).dx;
        final remember = find.text(l10n.rememberMe);
        final forgot = find.text(l10n.forgotPassword);
        if (direction == TextDirection.ltr) {
          expect(chip, greaterThan(width / 2));
          expect(heading, lessThan(width / 2));
        } else {
          expect(chip, lessThan(width / 2));
          expect(heading, greaterThan(width / 2));
        }
        expect(startsBefore(tester, remember, forgot, direction), isTrue);
      });

      testWidgets('language chip toggles the locale provider', (tester) async {
        await pump(tester);
        final locales = Provider.of<LocaleProvider>(
          tester.element(find.byType(LoginScreen)),
          listen: false,
        );
        expect(locales.locale.languageCode, 'en');
        await tester.tap(find.byType(LanguageToggleChip));
        await tester.pump();
        expect(locales.locale.languageCode, 'ar');
      });

      testWidgets('password visibility toggles', (tester) async {
        await pump(tester);
        bool obscured() => tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .obscureText;
        expect(obscured(), isTrue);
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pump();
        expect(obscured(), isFalse);
      });

      testWidgets('valid credentials: one login call, then /main', (
        tester,
      ) async {
        final repo = FakeAuthRepository();
        await pump(tester, repo: repo);
        await submit(tester);
        expect(repo.loginCalls, 1);
        expect(repo.lastLoginEmail, 'u@e.com');
        expect(find.text('route:/main'), findsOneWidget);
      });

      testWidgets('empty fields: banner, no API call', (tester) async {
        final repo = FakeAuthRepository();
        await pump(tester, repo: repo);
        await tester.tap(find.widgetWithText(PrimaryButton, signIn));
        await tester.pumpAndSettle();
        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        expect(repo.loginCalls, 0);
      });

      testWidgets('wrong password: persistent banner, retry logs in again', (
        tester,
      ) async {
        final repo = FakeAuthRepository(mode: 'wrong-password');
        await pump(tester, repo: repo);
        await submit(tester);
        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        expect(find.text('route:/main'), findsNothing);
        await tester.pump(const Duration(minutes: 1));
        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        expect(repo.loginCalls, 1);

        await tester.tap(find.text(l10n.retry));
        await tester.pumpAndSettle();
        expect(repo.loginCalls, 2);
        expect(find.byType(ThemedErrorBanner), findsOneWidget);
      });

      testWidgets('unverified account pushes /otp', (tester) async {
        final repo = FakeAuthRepository(mode: 'unverified');
        await pump(tester, repo: repo);
        await submit(tester);
        expect(find.text('route:/otp'), findsOneWidget);
        expect(find.text('route:/main'), findsNothing);
      });

      testWidgets('forgot password link navigates to /forgot', (tester) async {
        await pump(tester);
        await tester.tap(find.text(l10n.forgotPassword));
        await tester.pumpAndSettle();
        expect(find.text('route:/forgot'), findsOneWidget);
      });

      testWidgets('create account link navigates to /signup', (tester) async {
        await pump(tester);
        await tester.tap(find.text(l10n.createAccountPrompt));
        await tester.pumpAndSettle();
        expect(find.text('route:/signup'), findsOneWidget);
      });
    });
  }
}
