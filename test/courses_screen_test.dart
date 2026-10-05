import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/content/director_profile.dart';
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
import 'package:wael_app/widgets/themed_skeleton.dart';

import 'academy_fakes.dart';
import 'director_fixture.dart';
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

/// The seeded axes with nothing published: bachelor years 1-4 and the one
/// vocational level, and no diploma.
FakeAcademyRepository emptyAxes() => FakeAcademyRepository(
  levelList: [
    level('bachelor-y1', 'bachelor', 1),
    level('bachelor-y2', 'bachelor', 2),
    level('bachelor-y3', 'bachelor', 3),
    level('bachelor-y4', 'bachelor', 4),
    level('vocational', 'vocational', 5),
  ],
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
      bool withDirector = true,
    }) async {
      final catalog = AcademyCatalogProvider(repo);
      await pumpScreen(
        tester,
        locale,
        const CoursesScreen(),
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
          ChangeNotifierProvider(
            create: (_) => HomeProvider(
              director: withDirector ? testDirector : const DirectorProfile(),
            ),
          ),
        ],
        size: size,
        settle: settle,
      );
      return catalog;
    }

    String title(String ar, String en) => isArabic ? ar : en;
    final director = isArabic ? testDirector.nameAr : testDirector.name;

    group('CoursesScreen [$name]', () {
      testWidgets(
        'subject cards have no director row while the profile is empty',
        (tester) async {
          await pump(tester, fake(), withDirector: false);
          expect(find.byType(CatalogSubjectCard), findsWidgets);
          expect(find.byIcon(Icons.person_pin_circle_outlined), findsNothing);
        },
      );

      testWidgets('shell, filters, level summary and subject cards', (
        tester,
      ) async {
        await pump(tester, fake());
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(SearchField), findsOneWidget);
        expect(find.text(upper(l10n.educationType)), findsOneWidget);
        // Study types (outlined) and the levels of the selected type (filled).
        // Three study types (outlined) and the two levels of the first (filled).
        expect(find.byType(SelectableChip), findsNWidgets(3 + 2));
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
        final vocational = find.text(l10n.studyTypeLabel('vocational', ''));
        await tester.ensureVisible(vocational);
        await tester.tap(vocational);
        await tester.pumpAndSettle();
        expect(catalog.selectedStudyTypeKey, 'vocational');
        expect(find.byType(CatalogSubjectCard), findsNothing);
        expect(find.byType(ThemedEmptyState), findsOneWidget);
        // A level with nothing published says so; it is not a failed search.
        expect(find.text(l10n.noSubjectsYet), findsOneWidget);
        expect(find.text(l10n.noCoursesFound), findsNothing);
        expect(find.text(l10n.subjectsCount(0)), findsOneWidget);

        // Back to bachelor, then search.
        await tester.tap(find.text(l10n.studyTypeLabel('bachelor', '')));
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
        // A search with no match, in a level that does have subjects.
        expect(find.text(l10n.noCoursesFound), findsOneWidget);
        expect(find.text(l10n.noSubjectsYet), findsNothing);
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
        expect(find.byType(ThemedSkeletonList), findsOneWidget);
        expect(find.byType(CatalogSubjectCard), findsNothing);
        expect(find.byType(ThemedErrorBanner), findsNothing);
        repo.release.complete();
        await tester.pumpAndSettle();
        expect(find.byType(ThemedSkeletonList), findsNothing);
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

      testWidgets('three study-type tabs are always there, in order', (
        tester,
      ) async {
        await pump(tester, emptyAxes(), size: const Size(700, 1800));
        final types = find.byWidgetPredicate(
          (w) => w is SelectableChip && w.variant == ChipVariant.outlined,
        );
        expect(types, findsNWidgets(3));
        for (final key in ['bachelor', 'diploma', 'vocational']) {
          // Inside the tab chips (the selected type's name is also the level
          // header's subtitle).
          expect(
            find.descendant(
              of: types,
              matching: find.text(l10n.studyTypeLabel(key, '')),
            ),
            findsOneWidget,
            reason: key,
          );
        }
        expect(
          startsBefore(tester, types.at(0), types.at(1), direction),
          isTrue,
        );
        expect(
          startsBefore(tester, types.at(1), types.at(2), direction),
          isTrue,
        );
        // Fixed labels, not the server's titles.
        expect(find.text(title('نوع bachelor', 'Type bachelor')), findsNothing);
        expect(l10n.studyTypeLabel('bachelor', ''), title('الفرق', 'Years'));
        expect(
          l10n.studyTypeLabel('diploma', ''),
          title('الدبلومات', 'Diplomas'),
        );
        expect(
          l10n.studyTypeLabel('vocational', ''),
          title('التدريب المهني', 'Vocational Training'),
        );
      });

      testWidgets('empty catalog: every tab is an honest empty state', (
        tester,
      ) async {
        final catalog = await pump(
          tester,
          emptyAxes(),
          size: const Size(700, 1800),
        );
        final levelChips = find.byWidgetPredicate(
          (w) => w is SelectableChip && w.variant == ChipVariant.filled,
        );

        // Bachelor: years 1-4, no subjects yet.
        expect(catalog.selectedStudyTypeKey, 'bachelor');
        expect(levelChips, findsNWidgets(4));
        expect(find.byType(CatalogSubjectCard), findsNothing);
        expect(find.text(l10n.noSubjectsYet), findsOneWidget);
        expect(find.text(l10n.noCoursesFound), findsNothing);

        // Diploma: no diplomas yet, no level chips, no level header.
        await tester.tap(find.text(l10n.studyTypeLabel('diploma', '')));
        await tester.pumpAndSettle();
        expect(catalog.selectedStudyTypeKey, 'diploma');
        expect(find.text(l10n.noDiplomasYet), findsOneWidget);
        expect(
          title('لا توجد دبلومات بعد', 'No diplomas yet'),
          l10n.noDiplomasYet,
        );
        expect(levelChips, findsNothing);
        expect(find.byType(CatalogLevelHeader), findsNothing);
        expect(find.text(l10n.noSubjectsYet), findsNothing);
        expect(find.text(l10n.noCoursesFound), findsNothing);

        // Vocational: its one level, no term filter, no subjects yet.
        await tester.tap(find.text(l10n.studyTypeLabel('vocational', '')));
        await tester.pumpAndSettle();
        expect(catalog.selectedStudyTypeKey, 'vocational');
        expect(levelChips, findsOneWidget);
        expect(find.text(l10n.noSubjectsYet), findsOneWidget);
        expect(
          title('لا توجد مواد بعد', 'No subjects yet'),
          l10n.noSubjectsYet,
        );
        expect(find.text(l10n.termFirst), findsNothing);
        expect(find.text(l10n.termSecond), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('all three tabs with data', (tester) async {
        final repo = FakeAcademyRepository(
          levelList: [
            level('bachelor-y1', 'bachelor', 1),
            level('diploma-crim', 'diploma', 6),
            level('diploma-civil', 'diploma', 7),
            level('vocational', 'vocational', 5),
          ],
          subjectsByLevel: {
            'bachelor-y1': [
              subject(
                'b1',
                'bachelor-y1',
                en: 'Civil Law',
                ar: 'القانون المدني',
              ),
            ],
            'diploma-crim': [
              subject('d1', 'diploma-crim', en: 'Forensics', ar: 'الطب الشرعي'),
            ],
            // diploma-civil has nothing published yet.
            'vocational': [
              AcademySubject(
                id: 'v1',
                levelKey: 'vocational',
                term: '',
                title: const LocalizedText(ar: 'الصياغة', en: 'Drafting'),
                description: const LocalizedText(),
                owned: false,
                counts: const SubjectCounts(videos: 1),
              ),
            ],
          },
        );
        final catalog = await pump(tester, repo, size: const Size(700, 1800));

        // Bachelor.
        expect(find.byType(CatalogSubjectCard), findsOneWidget);
        expect(find.text(title('القانون المدني', 'Civil Law')), findsOneWidget);

        // Diploma: two admin-created diplomas, the first selected.
        await tester.tap(find.text(l10n.studyTypeLabel('diploma', '')));
        await tester.pumpAndSettle();
        expect(catalog.selectedLevelKey, 'diploma-crim');
        expect(
          find.byWidgetPredicate(
            (w) => w is SelectableChip && w.variant == ChipVariant.filled,
          ),
          findsNWidgets(2),
        );
        expect(find.text(title('الطب الشرعي', 'Forensics')), findsOneWidget);
        expect(find.text(l10n.noDiplomasYet), findsNothing);

        // The second diploma has no subjects: "No subjects yet".
        await tester.tap(
          find.text(title('ar-diploma-civil', 'en-diploma-civil')).first,
        );
        await tester.pumpAndSettle();
        expect(catalog.selectedLevelKey, 'diploma-civil');
        expect(find.byType(CatalogSubjectCard), findsNothing);
        expect(find.text(l10n.noSubjectsYet), findsOneWidget);
        expect(find.text(l10n.noCoursesFound), findsNothing);

        // Vocational: one level, its subject, and no term anywhere.
        await tester.tap(find.text(l10n.studyTypeLabel('vocational', '')));
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (w) => w is SelectableChip && w.variant == ChipVariant.filled,
          ),
          findsOneWidget,
        );
        expect(find.text(title('الصياغة', 'Drafting')), findsOneWidget);
        expect(find.text(l10n.termFirst), findsNothing);
        expect(find.text(l10n.termSecond), findsNothing);
      });

      testWidgets(
        'a catalog that sends no levels shows the levels empty state',
        (tester) async {
          await pump(tester, FakeAcademyRepository(levelList: []));
          // Three tabs; bachelor has no levels to pick.
          expect(
            find.byWidgetPredicate(
              (w) => w is SelectableChip && w.variant == ChipVariant.outlined,
            ),
            findsNWidgets(3),
          );
          expect(find.text(l10n.noLevelsYet), findsOneWidget);
          expect(find.byType(CatalogSubjectCard), findsNothing);
        },
      );

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
