import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/constants.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/core/theme.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/screens/login_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/framed_poster_card.dart';
import 'package:wael_app/widgets/hero_backdrop.dart';
import 'package:wael_app/widgets/language_toggle_chip.dart';
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
      testWidgets('renders on the shared shell with the framed poster', (
        tester,
      ) async {
        await pump(tester);
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(FramedPosterCard), findsOneWidget);
        // The old full-bleed backdrop and the text wordmark are gone.
        expect(find.byType(HeroBackdrop), findsNothing);
        expect(find.text('ACADEMY'), findsNothing);
        // In Arabic the heading and the (case-less) button label are the same.
        expect(
          find.text(l10n.signIn),
          findsNWidgets(locale.languageCode == 'ar' ? 2 : 1),
        );
        expect(find.text(l10n.forgotPassword), findsOneWidget);
        expect(find.text(l10n.createAccountPrompt), findsOneWidget);
      });

      testWidgets(
        'shows the EL METR poster, whole, and not the character art',
        (tester) async {
          await pump(tester);
          final image = tester.widget<Image>(
            find.descendant(
              of: find.byType(FramedPosterCard),
              matching: find.byType(Image),
            ),
          );
          expect((image.image as AssetImage).assetName, AppConstants.imgPoster);
          expect(image.fit, BoxFit.contain);
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Image &&
                  w.image is AssetImage &&
                  (w.image as AssetImage).assetName ==
                      AppConstants.imgCharacterArt,
            ),
            findsNothing,
          );
        },
      );

      testWidgets('the poster card is framed and at most 55% of the height', (
        tester,
      ) async {
        await pump(tester);
        final card = find.descendant(
          of: find.byType(FramedPosterCard),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration,
          ),
        );
        final box = tester.widget<Container>(card).decoration! as BoxDecoration;
        expect(box.borderRadius, AppRadius.radiusXl);
        expect((box.border! as Border).top.width, 1);
        expect((box.border! as Border).top.color.a, lessThan(1));
        expect(box.boxShadow, isNotEmpty);
        final size = tester.getSize(card);
        expect(size.height, lessThanOrEqualTo(1400 * 0.55));
        expect(
          size.width / size.height,
          closeTo(AppConstants.posterAspectRatio, 0.01),
        );
      });

      testWidgets('email only: no phone wording, no remember me', (
        tester,
      ) async {
        await pump(tester);
        expect(find.text(l10n.email), findsOneWidget);
        expect(find.text(l10n.emailOrPhone), findsNothing);
        expect(
          find.textContaining(RegExp('phone', caseSensitive: false)),
          findsNothing,
        );
        expect(find.textContaining('هاتف'), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        expect(
          find.textContaining(RegExp('remember', caseSensitive: false)),
          findsNothing,
        );
        expect(find.textContaining('تذكرني'), findsNothing);
        // Two inputs only: email and password.
        expect(find.byType(TextFormField), findsNWidgets(2));
      });

      testWidgets('form autofills with next, done and submits', (tester) async {
        await pump(tester);
        expect(find.byType(AutofillGroup), findsOneWidget);
        final email = tester.widget<ThemedTextField>(
          find.byType(ThemedTextField).at(0),
        );
        expect(email.autofillHints, contains(AutofillHints.email));
        expect(email.textInputAction, TextInputAction.next);
        final password = tester.widget<ThemedTextField>(
          find.byType(ThemedTextField).at(1),
        );
        expect(password.autofillHints, contains(AutofillHints.password));
        expect(password.textInputAction, TextInputAction.done);
        expect(password.onFieldSubmitted, isNotNull);

        await tester.enterText(find.byType(TextFormField).at(0), 'u@e.com');
        await tester.tap(find.byType(TextFormField).at(1));
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('route:/main'), findsOneWidget);
      });

      testWidgets('fits a 360x640 phone without overflow', (tester) async {
        await pumpScreen(
          tester,
          locale,
          const LoginScreen(),
          auth: makeAuth(),
          size: const Size(360, 640),
        );
        expect(tester.takeException(), isNull);
        // The language chip and the whole poster are on screen at first.
        expect(
          tester.getRect(find.byType(LanguageToggleChip)).top,
          greaterThanOrEqualTo(0),
        );
        final poster = tester.getRect(find.byType(FramedPosterCard));
        expect(poster.top, greaterThanOrEqualTo(0));
        expect(poster.height, lessThanOrEqualTo(640 * 0.55));
        // The rest of the form is reachable by scrolling.
        await tester.ensureVisible(find.widgetWithText(PrimaryButton, signIn));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('directional layout ($direction)', (tester) async {
        await pump(tester);
        final width = 390.0;
        // Language chip sits at the end edge of the top bar.
        final chip = tester.getCenter(find.byType(LanguageToggleChip)).dx;
        final heading = tester.getCenter(find.text(l10n.signIn).first).dx;
        final forgot = tester.getCenter(find.text(l10n.forgotPassword)).dx;
        if (direction == TextDirection.ltr) {
          expect(chip, greaterThan(width / 2));
          expect(heading, lessThan(width / 2));
          expect(forgot, greaterThan(width / 2));
        } else {
          expect(chip, lessThan(width / 2));
          expect(heading, greaterThan(width / 2));
          expect(forgot, lessThan(width / 2));
        }
        // Top to bottom: chip, poster, heading, email, password, button.
        double top(Finder f) => tester.getTopLeft(f.first).dy;
        final order = [
          top(find.byType(LanguageToggleChip)),
          top(find.byType(FramedPosterCard)),
          top(find.text(l10n.signIn)),
          top(find.text(l10n.email)),
          top(find.text(l10n.password)),
          top(find.widgetWithText(PrimaryButton, signIn)),
        ];
        expect(order, [...order]..sort());
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
        expect(find.byTooltip(l10n.showPassword), findsOneWidget);
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pump();
        expect(obscured(), isFalse);
        expect(find.byTooltip(l10n.hidePassword), findsOneWidget);
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

      testWidgets('empty fields: inline errors, no banner, no API call', (
        tester,
      ) async {
        final repo = FakeAuthRepository();
        await pump(tester, repo: repo);
        await tester.tap(find.widgetWithText(PrimaryButton, signIn));
        await tester.pumpAndSettle();
        // Field errors render inline under each field; the banner stays for
        // server errors only.
        expect(find.byType(ThemedErrorBanner), findsNothing);
        expect(repo.loginCalls, 0);
      });

      testWidgets('field errors appear on blur', (tester) async {
        await pump(tester);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'not-an-email',
        );
        // Moving focus away validates the blurred field inline.
        await tester.tap(find.byType(TextFormField).at(1));
        await tester.pump();
        expect(
          find.text(ErrorMessages.invalidEmail(locale.languageCode == 'ar')),
          findsOneWidget,
        );
        expect(find.byType(ThemedErrorBanner), findsNothing);
      });

      testWidgets('next moves focus, done submits', (tester) async {
        await pump(tester);
        await tester.enterText(find.byType(TextFormField).at(0), 'u@e.com');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        final passwordFocused = tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .focusNode
            .hasFocus;
        expect(passwordFocused, isTrue);
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('route:/main'), findsOneWidget);
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
