import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/screens/login_screen.dart';
import 'package:wael_app/screens/settings/email_change_screen.dart';
import 'package:wael_app/screens/settings/password_change_screen.dart';
import 'package:wael_app/screens/signup_screen.dart';
import 'package:wael_app/widgets/themed_text_field.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

// UX pass 2026-10-12 (spec §4): every credential and account field carries
// autofill hints, the right keyboard and a next/done action, inside an
// AutofillGroup, so iOS and Android offer saved and generated passwords,
// the email, the name and the phone number.

List<(Iterable<String>?, TextInputType, TextInputAction?)> _fields(
  WidgetTester tester,
) => [
  for (final f in tester.widgetList<ThemedTextField>(
    find.byType(ThemedTextField),
  ))
    (f.autofillHints, f.keyboardType, f.textInputAction),
];

void main() {
  final (_, locale, _) = kLocales.first;

  Future<void> pump(WidgetTester tester, Widget screen) =>
      pumpScreen(tester, locale, screen, size: const Size(390, 1600));

  testWidgets('login: email + password, in an AutofillGroup', (tester) async {
    await pump(tester, const LoginScreen());
    expect(find.byType(AutofillGroup), findsWidgets);
    expect(_fields(tester), [
      (
        const [AutofillHints.email],
        TextInputType.emailAddress,
        TextInputAction.next,
      ),
      (
        const [AutofillHints.password],
        TextInputType.text,
        TextInputAction.done,
      ),
    ]);
  });

  testWidgets('signup: name, email, phone, new password x2', (tester) async {
    await pump(tester, const SignupScreen());
    expect(find.byType(AutofillGroup), findsWidgets);
    final hints = [for (final f in _fields(tester)) f.$1?.single];
    expect(hints, [
      AutofillHints.name,
      AutofillHints.email,
      AutofillHints.telephoneNumber,
      AutofillHints.newPassword,
      AutofillHints.newPassword,
    ]);
    expect(_fields(tester)[2].$2, TextInputType.phone);
    expect(_fields(tester).last.$3, TextInputAction.done);
  });

  testWidgets('password change: current, new, confirm', (tester) async {
    await pump(tester, const PasswordChangeScreen());
    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(_fields(tester), [
      (
        const [AutofillHints.password],
        TextInputType.text,
        TextInputAction.next,
      ),
      (
        const [AutofillHints.newPassword],
        TextInputType.text,
        TextInputAction.next,
      ),
      (
        const [AutofillHints.newPassword],
        TextInputType.text,
        TextInputAction.done,
      ),
    ]);
  });

  testWidgets('email change: new email, current password', (tester) async {
    await pump(tester, const EmailChangeScreen());
    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(_fields(tester), [
      (
        const [AutofillHints.email],
        TextInputType.emailAddress,
        TextInputAction.next,
      ),
      (
        const [AutofillHints.password],
        TextInputType.text,
        TextInputAction.done,
      ),
    ]);
  });
}
