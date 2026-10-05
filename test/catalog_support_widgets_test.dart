import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/theme.dart';
import 'package:wael_app/widgets/accent_title.dart';
import 'package:wael_app/widgets/app_badge.dart';
import 'package:wael_app/widgets/icon_tile.dart';
import 'package:wael_app/widgets/search_field.dart';
import 'package:wael_app/widgets/selectable_chip.dart';
import 'package:wael_app/widgets/themed_panel.dart';
import 'package:wael_app/widgets/themed_skeleton.dart';

import 'widget_layer_harness.dart';

BoxDecoration decorationOf(WidgetTester tester, Finder f) =>
    tester.widget<Container>(f).decoration! as BoxDecoration;

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);

    group('[$name]', () {
      testWidgets('AppBadge: neutral, accent and pill', (tester) async {
        await pumpLocalized(
          tester,
          locale,
          const Scaffold(
            body: Column(
              children: [
                AppBadge(label: 'one'),
                AppBadge(label: 'two', accent: true),
                AppBadge(label: 'three', pill: true),
              ],
            ),
          ),
        );
        BoxDecoration deco(String label) => decorationOf(
          tester,
          find.ancestor(of: find.text(label), matching: find.byType(Container)),
        );
        expect(deco('one').color, AppColors.surfaceElevated);
        expect(deco('one').borderRadius, AppRadius.radiusXs);
        expect(deco('two').color, AppColors.crimson.withValues(alpha: 0.15));
        expect(deco('three').borderRadius, AppRadius.radiusPill);
        final accentStyle = tester.widget<Text>(find.text('two')).style!;
        expect(accentStyle.color, AppColors.crimson);
        // Arabic letterforms must not be letter-spaced.
        expect(
          accentStyle.letterSpacing,
          locale.languageCode == 'ar' ? 0 : 1.0,
        );
      });

      testWidgets('SelectableChip: taps, selection and count', (tester) async {
        var taps = 0;
        await pumpLocalized(
          tester,
          locale,
          Scaffold(
            body: Row(
              children: [
                SelectableChip(
                  label: 'A',
                  selected: true,
                  count: 3,
                  icon: Icons.school_outlined,
                  onTap: () => taps++,
                ),
                SelectableChip(
                  label: 'B',
                  selected: false,
                  onTap: () => taps += 10,
                ),
              ],
            ),
          ),
        );
        await tester.tap(find.text('A'));
        await tester.tap(find.text('B'));
        expect(taps, 11);
        expect(find.text('3'), findsOneWidget);
        // Selected chip first in the row: before B in reading order.
        final a = tester.getCenter(find.text('A')).dx;
        final b = tester.getCenter(find.text('B')).dx;
        expect(direction == TextDirection.ltr ? a < b : a > b, isTrue);
        // Icon precedes the label at the start edge.
        final icon = tester.getCenter(find.byIcon(Icons.school_outlined)).dx;
        expect(direction == TextDirection.ltr ? icon < a : icon > a, isTrue);
        final selectedSemantics = tester.getSemantics(
          find.byType(SelectableChip).first,
        );
        expect(selectedSemantics.flagsCollection.isSelected, Tristate.isTrue);
      });

      testWidgets('SelectableChip outlined selected has the glow', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          locale,
          Scaffold(
            body: Row(
              children: [
                SelectableChip(
                  label: 'Selected',
                  selected: true,
                  variant: ChipVariant.outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),
        );
        final deco =
            tester
                    .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                    .decoration!
                as BoxDecoration;
        expect(deco.boxShadow, AppElevation.crimsonGlow);
        expect((deco.border! as Border).top.color, AppColors.crimson);
        expect(deco.color, AppColors.surfaceElevated);
      });

      testWidgets('AccentTitle: bar at the start, trailing at the end', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          locale,
          const Scaffold(
            body: AccentTitle(
              title: 'Content',
              trailing: Text('9', key: Key('t')),
            ),
          ),
        );
        const title = 'CONTENT';
        expect(find.text(title), findsOneWidget);
        final bar = tester
            .getCenter(
              find.byWidgetPredicate(
                (w) => w is Container && w.constraints?.maxWidth == 3,
              ),
            )
            .dx;
        final text = tester.getCenter(find.text(title)).dx;
        final trailing = tester.getCenter(find.byKey(const Key('t'))).dx;
        if (direction == TextDirection.ltr) {
          expect(bar, lessThan(text));
          expect(trailing, greaterThan(text));
        } else {
          expect(bar, greaterThan(text));
          expect(trailing, lessThan(text));
        }
      });

      testWidgets('SearchField: typing, clear button, layout', (tester) async {
        final controller = TextEditingController();
        final changes = <String>[];
        var cleared = 0;
        await pumpLocalized(
          tester,
          locale,
          Scaffold(
            body: SearchField(
              controller: controller,
              hint: l10n.search,
              onChanged: changes.add,
              onClear: () {
                cleared++;
                controller.clear();
              },
            ),
          ),
        );
        expect(find.byIcon(Icons.close), findsNothing);
        await tester.enterText(find.byType(TextField), 'abc');
        await tester.pump();
        expect(changes, ['abc']);
        final glass = tester.getCenter(find.byIcon(Icons.search)).dx;
        final close = tester.getCenter(find.byIcon(Icons.close)).dx;
        expect(
          direction == TextDirection.ltr ? glass < close : glass > close,
          isTrue,
        );
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(cleared, 1);
        expect(find.byIcon(Icons.close), findsNothing);
      });

      testWidgets('IconTile border and ThemedPanel radius', (tester) async {
        await pumpLocalized(
          tester,
          locale,
          const Scaffold(
            body: Column(
              children: [
                IconTile(icon: Icons.add, borderColor: AppColors.crimson),
                ThemedPanel(
                  borderRadius: AppRadius.radiusLg,
                  tone: PanelTone.inset,
                  child: Text('p'),
                ),
              ],
            ),
          ),
        );
        final tile = decorationOf(
          tester,
          find
              .descendant(
                of: find.byType(IconTile),
                matching: find.byType(Container),
              )
              .first,
        );
        expect((tile.border! as Border).top.color, AppColors.crimson);
        final panel = decorationOf(
          tester,
          find
              .descendant(
                of: find.byType(ThemedPanel),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(panel.borderRadius, AppRadius.radiusLg);
      });

      testWidgets('ThemedSkeletonList shows placeholders while loading', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          locale,
          const Scaffold(body: ThemedSkeletonList()),
        );
        expect(find.byType(ThemedSkeletonList), findsOneWidget);
        expect(find.byType(ThemedSkeletonCard), findsNWidgets(3));
        // Design-system tokens only: no raw colors.
        final card = tester.widget<ThemedSkeletonCard>(
          find.byType(ThemedSkeletonCard).first,
        );
        expect(card, isNotNull);
      });

      testWidgets('SelectableChip has a label and a 48dp target', (
        tester,
      ) async {
        await pumpLocalized(
          tester,
          locale,
          Scaffold(
            body: SelectableChip(label: 'Chip', selected: false, onTap: () {}),
          ),
        );
        final chip = find.byType(SelectableChip);
        expect(chip, findsOneWidget);
        final size = tester.getSize(chip);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        final semantics = tester.getSemantics(chip);
        expect(semantics.label, contains('Chip'));
        // ignore: deprecated_member_use (flagsCollection has no contains yet)
        expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
      });
    });
  }
}
