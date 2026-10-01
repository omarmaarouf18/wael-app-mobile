import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/screens/courses_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/catalog_level_header.dart';
import 'package:wael_app/widgets/catalog_subject_card.dart';
import 'package:wael_app/widgets/search_field.dart';
import 'package:wael_app/widgets/selectable_chip.dart';
import 'package:wael_app/widgets/themed_empty_state.dart';
import 'package:wael_app/widgets/themed_error_banner.dart';
import 'package:wael_app/widgets/themed_loading_indicator.dart';

import 'academy_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

class _SlowRepository extends FakeAcademyRepository {
  _SlowRepository() : super(levelList: []);
  final Completer<void> release = Completer<void>();

  @override
  Future<AcademyLevels> levels() async {
    await release.future;
    return super.levels();
  }
}

/// Long titles and descriptions in both languages, to provoke overflow.
FakeAcademyRepository longText() => FakeAcademyRepository(
  levelList: [
    level('bachelor-y1', 'bachelor', 1),
    level('bachelor-y2', 'bachelor', 2),
    level('vocational', 'vocational', 5),
  ],
  subjectsByLevel: {
    'bachelor-y1': [
      AcademySubject(
        id: 'long-1',
        levelKey: 'bachelor-y1',
        term: 'second',
        title: const LocalizedText(
          ar: 'المدخل للعلوم القانونية (نظرية القانون ونظرية الحق) والأنظمة القضائية المقارنة',
          en: 'Introduction to Legal Science: Theory of Law, Theory of Rights and Comparative Judicial Systems',
        ),
        description: const LocalizedText(
          ar: 'التأصيل الشامل لنظرية القانون وخصائص القاعدة القانونية ومصادرها، ونظرية الحق وأشخاصه ومحله وحمايته القانونية والتطبيقات القضائية الحديثة.',
          en: 'Comprehensive grounding in the theory of rule of law, legal sources, interpretation, and the classification of subjective rights and their judicial protection.',
        ),
        owned: false,
        counts: const SubjectCounts(videos: 12, books: 1, notes: 3),
      ),
      subject('s2', 'bachelor-y1', en: 'Criminal Law', ar: 'القانون الجنائي'),
    ],
    'bachelor-y2': [
      subject(
        's3',
        'bachelor-y2',
        owned: true,
        en: 'Civil Law',
        ar: 'القانون المدني',
      ),
    ],
    'vocational': [],
  },
);

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';

    Future<AcademyCatalogProvider> pump(
      WidgetTester tester,
      FakeAcademyRepository repo, {
      Size size = const Size(390, 1800),
      bool settle = true,
    }) async {
      final catalog = AcademyCatalogProvider(repo);
      await pumpScreen(
        tester,
        locale,
        const CoursesScreen(),
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
          ChangeNotifierProvider(create: (_) => HomeProvider()),
        ],
        size: size,
        settle: settle,
      );
      return catalog;
    }

    String title(String ar, String en) => isArabic ? ar : en;
    final director = isArabic ? 'المستشار د. وائل المتر' : 'Dean Wael El Metr';

    group('CoursesScreen [$name]', () {
      testWidgets('shell, filters, level summary and subject cards', (
        tester,
      ) async {
        await pump(tester, fake());
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(SearchField), findsOneWidget);
        expect(find.text(upper(l10n.educationType)), findsOneWidget);
        // Study types (outlined) and the levels of the selected type (filled).
        expect(find.byType(SelectableChip), findsNWidgets(2 + 2));
        expect(find.byType(CatalogLevelHeader), findsOneWidget);
        expect(find.text(l10n.subjectsCount(2)), findsOneWidget);
        expect(find.byType(CatalogSubjectCard), findsNWidgets(2));
        expect(find.text(director), findsNWidgets(2));
        expect(find.text(l10n.termLabel('first')), findsNWidgets(2));
        expect(find.text('1 ${l10n.tabVideos}'), findsNWidgets(2));
        // No data behind these exists any more.
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.schedule), findsNothing);
        expect(find.textContaining('%'), findsNothing);
      });

      testWidgets('filters and cards mirror ($direction)', (tester) async {
        await pump(tester, fake());
        // First study type chip nearer the start edge than the second.
        final types = find.byWidgetPredicate(
          (w) => w is SelectableChip && w.variant == ChipVariant.outlined,
        );
        expect(
          startsBefore(tester, types.at(0), types.at(1), direction),
          isTrue,
        );
        final levels = find.byWidgetPredicate(
          (w) => w is SelectableChip && w.variant == ChipVariant.filled,
        );
        expect(
          startsBefore(tester, levels.at(0), levels.at(1), direction),
          isTrue,
        );
        // Level summary: icon, title, count badge.
        final header = find.byType(CatalogLevelHeader);
        final icon = find.descendant(
          of: header,
          matching: find.byIcon(Icons.account_balance),
        );
        final badge = find.text(l10n.subjectsCount(2));
        expect(startsBefore(tester, icon, badge, direction), isTrue);
        // Card: instructor icon at the start, the link text before its arrow.
        final card = find.byType(CatalogSubjectCard).first;
        final pin = find.descendant(
          of: card,
          matching: find.byIcon(Icons.person_pin_circle_outlined),
        );
        final name = find.descendant(of: card, matching: find.text(director));
        expect(startsBefore(tester, pin, name, direction), isTrue);
        final link = find.descendant(
          of: card,
          matching: find.text(l10n.viewSubject),
        );
        final arrow = find.descendant(
          of: card,
          matching: find.byIcon(Icons.arrow_forward),
        );
        expect(startsBefore(tester, link, arrow, direction), isTrue);
        // The link sits at the end edge of the card.
        final cardRect = tester.getRect(card);
        final arrowRect = tester.getRect(arrow);
        if (direction == TextDirection.ltr) {
          expect(cardRect.right - arrowRect.right, lessThan(24));
        } else {
          expect(arrowRect.left - cardRect.left, lessThan(24));
        }
      });

      testWidgets('selection: study type then level then search', (
        tester,
      ) async {
        // Wide enough that every chip is on screen.
        final catalog = await pump(tester, fake(), size: const Size(700, 1800));
        // Level 2 holds one owned subject: its card says Continue.
        await tester.tap(
          find.text(title('ar-bachelor-y2', 'en-bachelor-y2')).first,
        );
        await tester.pumpAndSettle();
        expect(catalog.selectedLevelKey, 'bachelor-y2');
        expect(find.byType(CatalogSubjectCard), findsOneWidget);
        expect(find.text(l10n.continueSubject), findsOneWidget);
        expect(find.text(l10n.subjectsCount(1)), findsOneWidget);

        // Vocational: one level, no subjects -> empty state.
        final vocational = find.text(
          title('نوع vocational', 'Type vocational'),
        );
        await tester.ensureVisible(vocational);
        await tester.tap(vocational);
        await tester.pumpAndSettle();
        expect(catalog.selectedStudyTypeKey, 'vocational');
        expect(find.byType(CatalogSubjectCard), findsNothing);
        expect(find.byType(ThemedEmptyState), findsOneWidget);
        expect(find.text(l10n.noCoursesFound), findsOneWidget);
        expect(find.text(l10n.subjectsCount(0)), findsOneWidget);

        // Back to bachelor, then search.
        await tester.tap(find.text(title('نوع bachelor', 'Type bachelor')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(title('ar-bachelor-y1', 'en-bachelor-y1')).first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          isArabic ? 'القانون المدني' : 'Civil',
        );
        await tester.pump();
        expect(find.byType(CatalogSubjectCard), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CatalogSubjectCard),
            matching: find.text(title('القانون المدني', 'Civil Law')),
          ),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pump();
        expect(find.text(l10n.noCoursesFound), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(find.byType(CatalogSubjectCard), findsNWidgets(2));
      });

      testWidgets('tapping a card opens its detail with the subject id', (
        tester,
      ) async {
        await pump(tester, fake());
        await tester.tap(find.text(title('القانون الجنائي', 'Criminal Law')));
        await tester.pumpAndSettle();
        expect(find.text('route:/course-details:s2'), findsOneWidget);
      });

      testWidgets('loading state until the catalog arrives', (tester) async {
        final repo = _SlowRepository();
        await pump(tester, repo, settle: false);
        expect(find.byType(ThemedLoadingIndicator), findsOneWidget);
        expect(find.byType(CatalogSubjectCard), findsNothing);
        expect(find.byType(ThemedErrorBanner), findsNothing);
        repo.release.complete();
        await tester.pumpAndSettle();
        expect(find.byType(ThemedLoadingIndicator), findsNothing);
      });

      testWidgets('error state: persistent banner, retry recovers', (
        tester,
      ) async {
        final repo = fake()..levelsError = const SocketException('unreachable');
        await pump(tester, repo);
        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        expect(find.text(ErrorMessages.networkError(isArabic)), findsOneWidget);
        expect(find.byType(CatalogSubjectCard), findsNothing);
        expect(find.byType(SelectableChip), findsNothing);
        await tester.pump(const Duration(minutes: 1));
        expect(find.byType(ThemedErrorBanner), findsOneWidget);

        repo.levelsError = null;
        await tester.tap(find.text(l10n.retry));
        await tester.pumpAndSettle();
        expect(repo.levelsCalls, 2);
        expect(find.byType(ThemedErrorBanner), findsNothing);
        expect(find.byType(CatalogSubjectCard), findsNWidgets(2));
      });

      testWidgets('empty catalog shows the empty state', (tester) async {
        await pump(tester, FakeAcademyRepository(levelList: []));
        expect(find.byType(ThemedEmptyState), findsOneWidget);
        expect(find.byType(SelectableChip), findsNothing);
      });

      for (final width in [360.0, 390.0]) {
        testWidgets('no overflow with long text at ${width.toInt()}px', (
          tester,
        ) async {
          await pump(tester, longText(), size: Size(width, 2600));
          expect(find.byType(CatalogSubjectCard), findsNWidgets(2));
          expect(tester.takeException(), isNull);
          // The section header texts shrink instead of overflowing.
          expect(find.text(upper(l10n.subjectEntity)), findsOneWidget);
          expect(find.text(l10n.curriculumCatalog), findsOneWidget);
          final screenWidth = width;
          final headerRight = tester
              .getRect(find.text(l10n.curriculumCatalog))
              .right;
          final headerLeft = tester
              .getRect(find.text(l10n.curriculumCatalog))
              .left;
          expect(headerRight <= screenWidth && headerLeft >= 0, isTrue);
        });
      }
    });
  }
}

// Latin labels are upper-cased by AppTypography.uppercaseLabel; Arabic is not.
String upper(String s) => s.toUpperCase();
