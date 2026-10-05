import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/screens/ebook_screen.dart';
import 'package:wael_app/widgets/app_badge.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/themed_card.dart';
import 'package:wael_app/widgets/themed_empty_state.dart';

import 'screen_harness.dart';
import 'widget_layer_harness.dart';

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);

    group('EbookScreen [$name]', () {
      testWidgets('coming-soon state with the tab name as title', (
        tester,
      ) async {
        await pumpScreen(tester, locale, const EbookScreen());

        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(ThemedEmptyState), findsOneWidget);
        // Tab label and screen title share one name.
        expect(find.text(l10n.navNotes), findsOneWidget);
        // Clear coming-soon state, no payment wording.
        expect(find.text(l10n.comingSoon), findsOneWidget);
        expect(find.byType(AppBadge), findsOneWidget);
        expect(find.text(l10n.ebookComingSoon), findsOneWidget);
        expect(
          find.textContaining(RegExp('pay|price|buy|شراء|دفع|سعر')),
          findsNothing,
        );

        // No books, notes, search box, filters, buttons or cards: no mock
        // library is drawn.
        expect(find.byType(ThemedCard), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(ListView), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      });

      testWidgets('pull-to-refresh exists', (tester) async {
        await pumpScreen(tester, locale, const EbookScreen());
        expect(find.byType(RefreshIndicator), findsOneWidget);
      });

      testWidgets('does not overflow on a small phone', (tester) async {
        await pumpScreen(
          tester,
          locale,
          const EbookScreen(),
          size: const Size(320, 568),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.ebookComingSoon), findsOneWidget);
      });
    });
  }
}
