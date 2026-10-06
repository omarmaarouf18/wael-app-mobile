import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/theme.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/confirm_action_dialog.dart';
import 'package:wael_app/widgets/otp_pin_input.dart';
import 'package:wael_app/widgets/secondary_button.dart';
import 'package:wael_app/widgets/status_dot.dart';
import 'package:wael_app/widgets/themed_empty_state.dart';
import 'package:wael_app/widgets/themed_error_banner.dart';
import 'package:wael_app/widgets/themed_loading_indicator.dart';
import 'package:wael_app/widgets/themed_panel.dart';
import 'package:wael_app/widgets/themed_section_header.dart';
import 'package:wael_app/widgets/themed_text_field.dart';

import 'widget_layer_harness.dart';

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);

    group('[$name]', () {
      testWidgets('app resolves $direction', (tester) async {
        late TextDirection seen;
        await pumpLocalized(
          tester,
          locale,
          Builder(
            builder: (context) {
              seen = Directionality.of(context);
              return const SizedBox();
            },
          ),
        );
        expect(seen, direction);
      });

      group('AppShell', () {
        testWidgets('mirrors back button and actions', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            AppShell(
              title: 'Title',
              showBack: true,
              actions: const [Icon(Icons.search, key: Key('action'))],
              body: const Text('body'),
            ),
          );
          final back = tester.getCenter(find.byTooltip(l10n.back)).dx;
          final title = tester.getCenter(find.text('Title')).dx;
          final action = tester.getCenter(find.byKey(const Key('action'))).dx;
          if (direction == TextDirection.ltr) {
            expect(back, lessThan(title));
            expect(action, greaterThan(title));
          } else {
            expect(back, greaterThan(title));
            expect(action, lessThan(title));
          }
          expect(find.text('body'), findsOneWidget);
        });

        testWidgets('back button pops the route', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppShell(
                      title: 'Second',
                      showBack: true,
                      body: SizedBox(),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.text('Second'), findsOneWidget);
          await tester.tap(find.byTooltip(l10n.back));
          await tester.pumpAndSettle();
          expect(find.text('Second'), findsNothing);
        });

        testWidgets('showHeader false has no app bar', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            const AppShell(showHeader: false, body: Text('body')),
          );
          expect(find.byType(AppBar), findsNothing);
          expect(find.text('body'), findsOneWidget);
        });

        testWidgets('header uses the glass token', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            const AppShell(title: 'T', body: SizedBox()),
          );
          expect(
            tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
            AppColors.headerGlass,
          );
        });
      });

      group('SecondaryButton', () {
        testWidgets('fires onPressed', (tester) async {
          var taps = 0;
          await pumpLocalized(
            tester,
            locale,
            Scaffold(
              body: SecondaryButton(text: l10n.cancel, onPressed: () => taps++),
            ),
          );
          await tester.tap(find.text(l10n.cancel));
          expect(taps, 1);
        });

        testWidgets('loading disables taps and shows a spinner', (
          tester,
        ) async {
          var taps = 0;
          await pumpLocalized(
            tester,
            locale,
            Scaffold(
              body: SecondaryButton(
                text: l10n.cancel,
                onPressed: () => taps++,
                isLoading: true,
              ),
            ),
            settle: false,
          );
          await tester.tap(find.byType(SecondaryButton));
          expect(taps, 0);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        });
      });

      group('ThemedPanel', () {
        testWidgets('tone selects the surface token', (tester) async {
          for (final (tone, color) in [
            (PanelTone.base, AppColors.surfaceLayer1),
            (PanelTone.raised, AppColors.surfaceElevated),
            (PanelTone.inset, AppColors.surfaceContainerLow),
          ]) {
            await pumpLocalized(
              tester,
              locale,
              Scaffold(
                body: ThemedPanel(tone: tone, child: const Text('content')),
              ),
            );
            final box = tester.widget<Container>(
              find.descendant(
                of: find.byType(ThemedPanel),
                matching: find.byType(Container),
              ),
            );
            expect((box.decoration! as BoxDecoration).color, color);
            expect(find.text('content'), findsOneWidget);
          }
        });

        testWidgets('default padding is directional', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            const Scaffold(body: ThemedPanel(child: Text('c'))),
          );
          expect(
            tester.widget<ThemedPanel>(find.byType(ThemedPanel)).padding,
            isA<EdgeInsetsDirectional>(),
          );
        });
      });

      group('ThemedErrorBanner', () {
        testWidgets('shows message and localised retry that fires', (
          tester,
        ) async {
          var retries = 0;
          await pumpLocalized(
            tester,
            locale,
            Scaffold(
              body: ThemedErrorBanner(
                message: l10n.errorLoading,
                onRetry: () => retries++,
              ),
            ),
          );
          expect(find.text(l10n.errorLoading), findsOneWidget);
          await tester.tap(find.text(l10n.retry));
          expect(retries, 1);
        });

        testWidgets('has no retry button without onRetry', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            Scaffold(body: ThemedErrorBanner(message: l10n.errorLoading)),
          );
          expect(find.byType(TextButton), findsNothing);
        });

        testWidgets('is persistent and announced as a live region', (
          tester,
        ) async {
          await pumpLocalized(
            tester,
            locale,
            Scaffold(body: ThemedErrorBanner(message: l10n.errorLoading)),
          );
          await tester.pump(const Duration(minutes: 5));
          expect(find.text(l10n.errorLoading), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.liveRegion == true,
            ),
            findsWidgets,
          );
        });

        testWidgets('icon at start, retry at end', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            Scaffold(
              body: ThemedErrorBanner(
                message: l10n.errorLoading,
                onRetry: () {},
              ),
            ),
          );
          final icon = tester.getCenter(find.byIcon(Icons.error_outline)).dx;
          final text = tester.getCenter(find.text(l10n.errorLoading)).dx;
          final retry = tester.getCenter(find.text(l10n.retry)).dx;
          if (direction == TextDirection.ltr) {
            expect(icon, lessThan(text));
            expect(retry, greaterThan(text));
          } else {
            expect(icon, greaterThan(text));
            expect(retry, lessThan(text));
          }
        });

        testWidgets('retry uses a text token, not red', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            Scaffold(
              body: ThemedErrorBanner(
                message: l10n.errorLoading,
                onRetry: () {},
              ),
            ),
          );
          final style = tester.widget<Text>(find.text(l10n.retry)).style!;
          expect(style.color, AppColors.textPrimary);
        });
      });

      group('ThemedTextField', () {
        testWidgets('validation errors use danger, not crimson', (
          tester,
        ) async {
          await pumpLocalized(
            tester,
            locale,
            Scaffold(
              body: Form(
                autovalidateMode: AutovalidateMode.always,
                child: ThemedTextField(
                  hintText: 'hint',
                  validator: (_) => 'bad',
                ),
              ),
            ),
          );
          await tester.pump();
          final style = tester.widget<Text>(find.text('bad')).style!;
          expect(style.color, AppColors.danger);
        });
      });

      group('StatusDot', () {
        testWidgets('default pip color is danger, not crimson', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            const Scaffold(body: StatusDot()),
          );
          final dot = tester.widget<StatusDot>(find.byType(StatusDot));
          expect(dot.color, AppColors.danger);
        });
      });

      group('ThemedEmptyState', () {
        testWidgets('shows icon, title, message and action', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            Scaffold(
              body: ThemedEmptyState(
                title: l10n.navNotes,
                message: l10n.noNotifications,
                action: SecondaryButton(text: l10n.retry, onPressed: () {}),
              ),
            ),
          );
          expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
          expect(find.text(l10n.navNotes), findsOneWidget);
          expect(find.text(l10n.noNotifications), findsOneWidget);
          expect(find.text(l10n.retry), findsOneWidget);
          final screen = tester.getSize(find.byType(Scaffold));
          expect(
            tester.getCenter(find.text(l10n.noNotifications)).dx,
            closeTo(screen.width / 2, 1),
          );
        });

        testWidgets('title and action are optional', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            Scaffold(body: ThemedEmptyState(message: l10n.noNotifications)),
          );
          expect(find.text(l10n.noNotifications), findsOneWidget);
          expect(find.byType(SecondaryButton), findsNothing);
        });
      });

      group('ThemedLoadingIndicator', () {
        testWidgets('spinner with localised semantic label', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            const Scaffold(body: ThemedLoadingIndicator()),
            settle: false,
          );
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.bySemanticsLabel(l10n.loading), findsOneWidget);
        });

        testWidgets('optional visible label', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            Scaffold(body: ThemedLoadingIndicator(label: l10n.verify)),
            settle: false,
          );
          expect(find.text(l10n.verify), findsOneWidget);
        });
      });

      group('ThemedSectionHeader', () {
        testWidgets('uppercases Latin only, no Arabic letter spacing', (
          tester,
        ) async {
          final title = locale.languageCode == 'ar' ? l10n.navHome : 'Buttons';
          await pumpLocalized(
            tester,
            locale,
            Scaffold(body: ThemedSectionHeader(title: title)),
          );
          final expected = AppTypography.uppercaseLabel(title);
          expect(find.text(expected), findsOneWidget);
          final style = tester.widget<Text>(find.text(expected)).style!;
          if (locale.languageCode == 'ar') {
            expect(expected, title);
            expect(style.letterSpacing, 0);
          } else {
            expect(expected, 'BUTTONS');
            expect(style.letterSpacing, greaterThan(0));
          }
        });

        testWidgets('uppercase: false keeps the title', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            const Scaffold(
              body: ThemedSectionHeader(title: 'Mixed Case', uppercase: false),
            ),
          );
          expect(find.text('Mixed Case'), findsOneWidget);
        });

        testWidgets('action sits at the end edge', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            Scaffold(
              body: ThemedSectionHeader(
                title: 'Section',
                action: Text(l10n.viewAll, key: const Key('action')),
              ),
            ),
          );
          final title = tester.getCenter(find.text('SECTION')).dx;
          final action = tester.getCenter(find.byKey(const Key('action'))).dx;
          if (direction == TextDirection.ltr) {
            expect(action, greaterThan(title));
          } else {
            expect(action, lessThan(title));
          }
        });
      });

      group('ConfirmActionDialog', () {
        Future<void> openDialog(
          WidgetTester tester,
          ValueSetter<bool> onResult, {
          String? confirmLabel,
          String? cancelLabel,
        }) async {
          await pumpLocalized(
            tester,
            locale,
            Builder(
              builder: (context) => TextButton(
                onPressed: () async => onResult(
                  await ConfirmActionDialog.show(
                    context,
                    title: 'Sign out',
                    message: l10n.errorLoading,
                    confirmLabel: confirmLabel,
                    cancelLabel: cancelLabel,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
        }

        testWidgets('shows localised default labels', (tester) async {
          await openDialog(tester, (_) {});
          expect(find.text('Sign out'), findsOneWidget);
          expect(find.text(l10n.errorLoading), findsOneWidget);
          expect(find.text(l10n.confirm), findsOneWidget);
          expect(find.text(l10n.cancel), findsOneWidget);
        });

        testWidgets('custom labels override the defaults', (tester) async {
          await openDialog(
            tester,
            (_) {},
            confirmLabel: 'Yes',
            cancelLabel: 'No',
          );
          expect(find.text('Yes'), findsOneWidget);
          expect(find.text('No'), findsOneWidget);
          expect(find.text(l10n.confirm), findsNothing);
        });

        testWidgets('tapping outside does not dismiss', (tester) async {
          bool? result;
          await openDialog(tester, (v) => result = v);
          expect(
            tester
                .widget<ModalBarrier>(find.byType(ModalBarrier).last)
                .dismissible,
            isFalse,
          );
          await tester.tapAt(const Offset(2, 2));
          await tester.pumpAndSettle();
          expect(find.byType(ConfirmActionDialog), findsOneWidget);
          expect(result, isNull);
        });

        testWidgets('confirm resolves true', (tester) async {
          bool? result;
          await openDialog(tester, (v) => result = v);
          await tester.tap(find.text(l10n.confirm));
          await tester.pumpAndSettle();
          expect(result, isTrue);
          expect(find.byType(ConfirmActionDialog), findsNothing);
        });

        testWidgets('cancel resolves false', (tester) async {
          bool? result;
          await openDialog(tester, (v) => result = v);
          await tester.tap(find.text(l10n.cancel));
          await tester.pumpAndSettle();
          expect(result, isFalse);
        });

        testWidgets('cancel at start, confirm at end', (tester) async {
          await openDialog(tester, (_) {});
          final cancel = tester.getCenter(find.text(l10n.cancel)).dx;
          final confirm = tester.getCenter(find.text(l10n.confirm)).dx;
          if (direction == TextDirection.ltr) {
            expect(cancel, lessThan(confirm));
          } else {
            expect(cancel, greaterThan(confirm));
          }
        });
      });

      group('OtpPinInput', () {
        testWidgets('digits fill the boxes and complete', (tester) async {
          final changes = <String>[];
          String? completed;
          await pumpLocalized(
            tester,
            locale,
            Scaffold(
              body: OtpPinInput(
                onChanged: changes.add,
                onCompleted: (v) => completed = v,
              ),
            ),
          );
          await tester.enterText(find.byType(TextField), '123');
          await tester.pump();
          expect(completed, isNull);
          for (final d in ['1', '2', '3']) {
            expect(find.text(d), findsOneWidget);
          }
          await tester.enterText(find.byType(TextField), '123456');
          await tester.pump();
          expect(completed, '123456');
          expect(changes.last, '123456');
        });

        testWidgets('boxes stay left to right in every locale', (tester) async {
          await pumpLocalized(
            tester,
            locale,
            const Scaffold(body: OtpPinInput()),
          );
          await tester.enterText(find.byType(TextField), '123456');
          await tester.pump();
          final first = tester.getCenter(find.text('1')).dx;
          final last = tester.getCenter(find.text('6')).dx;
          expect(first, lessThan(last));
        });

        testWidgets('Arabic-Indic digits are normalised, letters dropped', (
          tester,
        ) async {
          String? completed;
          await pumpLocalized(
            tester,
            locale,
            Scaffold(body: OtpPinInput(onCompleted: (v) => completed = v)),
          );
          await tester.enterText(find.byType(TextField), '١٢a٣٤-٥٦');
          await tester.pump();
          expect(completed, '123456');
        });

        testWidgets('input beyond the length is truncated', (tester) async {
          final controller = TextEditingController();
          await pumpLocalized(
            tester,
            locale,
            Scaffold(body: OtpPinInput(controller: controller)),
          );
          await tester.enterText(find.byType(TextField), '12345678');
          await tester.pump();
          expect(controller.text, '123456');
        });

        testWidgets('hasError switches the border to the danger token', (
          tester,
        ) async {
          await pumpLocalized(
            tester,
            locale,
            const Scaffold(body: OtpPinInput(hasError: true)),
          );
          final boxes = tester
              .widgetList<Container>(find.byType(Container))
              .map((c) => c.decoration)
              .whereType<BoxDecoration>()
              .where((d) => d.border != null)
              .toList();
          expect(boxes, hasLength(6));
          for (final d in boxes) {
            expect((d.border! as Border).top.color, AppColors.danger);
          }
        });

        testWidgets('custom length and localised semantic label', (
          tester,
        ) async {
          await pumpLocalized(
            tester,
            locale,
            const Scaffold(body: OtpPinInput(length: 4)),
          );
          expect(find.bySemanticsLabel(l10n.verificationCode), findsWidgets);
          await tester.enterText(find.byType(TextField), '123456');
          await tester.pump();
          expect(find.text('5'), findsNothing);
          expect(find.text('4'), findsOneWidget);
        });
      });
    });
  }

  group('OtpDigitsFormatter', () {
    const formatter = OtpDigitsFormatter(6);
    TextEditingValue run(String text) => formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text),
    );

    test('maps Arabic-Indic and Persian digits to ASCII', () {
      expect(run('٠١٢٣٤٥٦٧٨٩').text, '012345');
      expect(run('۰۱۲۳۴۵').text, '012345');
    });

    test('drops non digits and truncates', () {
      expect(run('a1 b2-3').text, '123');
      expect(run('1234567').text, '123456');
    });

    test('keeps the caret at the end', () {
      expect(run('12').selection, const TextSelection.collapsed(offset: 2));
    });
  });
}
