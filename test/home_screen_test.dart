import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/content/director_profile.dart';
import 'package:wael_app/core/constants.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/screens/home_screen.dart';
import 'package:wael_app/widgets/app_badge.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/home_hero_banner.dart';
import 'package:wael_app/widgets/instructor_dossier_card.dart';
import 'package:wael_app/widgets/owned_subject_tile.dart';
import 'package:wael_app/widgets/themed_empty_state.dart';
import 'package:wael_app/widgets/themed_error_banner.dart';
import 'package:wael_app/widgets/themed_skeleton.dart';

import 'academy_fakes.dart';
import 'director_fixture.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

/// Repository whose `levels()` waits until [release] completes.
class _SlowRepository extends FakeAcademyRepository {
  _SlowRepository() : super(levelList: []);

  final Completer<void> release = Completer<void>();

  @override
  Future<AcademyLevels> levels() async {
    await release.future;
    return super.levels();
  }
}

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';

    Future<AcademyCatalogProvider> pump(
      WidgetTester tester,
      FakeAcademyRepository repo, {
      VoidCallback? onExplore,
      HomeProvider? home,
      bool settle = true,
      Size size = const Size(390, 1600),
    }) async {
      final catalog = AcademyCatalogProvider(repo);
      await pumpScreen(
        tester,
        locale,
        HomeScreen(onExploreCourses: onExplore),
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
          ChangeNotifierProvider<HomeProvider>.value(
            value: home ?? HomeProvider(director: testDirector),
          ),
        ],
        settle: settle,
        size: size,
      );
      return catalog;
    }

    // `fake()` has one owned subject (s3, bachelor-y2).
    FakeAcademyRepository noOwned() => FakeAcademyRepository(
      levelList: [level('bachelor-y1', 'bachelor', 1)],
      subjectsByLevel: {
        'bachelor-y1': [subject('s1', 'bachelor-y1')],
      },
    );

    group('HomeScreen [$name]', () {
      testWidgets('shell, hero, director and my-courses header', (
        tester,
      ) async {
        await pump(tester, fake());
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(HomeHeroBanner), findsOneWidget);
        expect(find.text(l10n.heroHeadline), findsOneWidget);
        expect(find.byType(InstructorDossierCard), findsOneWidget);
        expect(find.text(l10n.instructorSectionTitle), findsOneWidget);
        expect(
          find.text(isArabic ? testDirector.nameAr : testDirector.name),
          findsOneWidget,
        );
        expect(find.text(l10n.myCourses), findsOneWidget);
        expect(find.text(l10n.viewAll), findsOneWidget);
        // Removed: mock "continue learning" and upcoming-event sections.
        expect(find.text(l10n.continueLearning), findsNothing);
        expect(find.text(l10n.upcoming), findsNothing);
      });

      testWidgets('the shipped director card: portrait, name and four titles', (
        tester,
      ) async {
        // The default HomeProvider carries the shipped, owner-verified profile.
        await pump(tester, fake(), home: HomeProvider());
        final card = find.byType(InstructorDossierCard);
        expect(card, findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.text(isArabic ? 'وائل السعيد' : 'Wael El Saeed'),
          ),
          findsOneWidget,
        );
        final titles = isArabic
            ? kDirectorProfile.titlesAr
            : kDirectorProfile.titles;
        expect(titles, hasLength(4));
        for (final t in titles) {
          expect(
            find.descendant(of: card, matching: find.text(t)),
            findsOneWidget,
            reason: t,
          );
        }
        // One chip per title and no biography or "read more".
        expect(
          find.descendant(of: card, matching: find.byType(AppBadge)),
          findsNWidgets(4),
        );
        expect(find.text(l10n.readMore), findsNothing);
        // The portrait is the character art.
        final portrait = find.descendant(
          of: card,
          matching: find.byWidgetPredicate((w) {
            if (w is! Container || w.decoration is! BoxDecoration) return false;
            final image = (w.decoration! as BoxDecoration).image?.image;
            return image is ResizeImage &&
                image.imageProvider is AssetImage &&
                (image.imageProvider as AssetImage).assetName ==
                    AppConstants.imgCharacterArt;
          }),
        );
        expect(portrait, findsOneWidget);
        // Portrait, then the name.
        expect(
          startsBefore(
            tester,
            portrait,
            find.descendant(
              of: card,
              matching: find.text(isArabic ? 'وائل السعيد' : 'Wael El Saeed'),
            ),
            direction,
          ),
          isTrue,
        );
      });

      testWidgets('Home still shows the character art in the hero', (
        tester,
      ) async {
        await pump(tester, fake());
        final hero = tester.widget<Image>(
          find.descendant(
            of: find.byType(HomeHeroBanner),
            matching: find.byType(Image),
          ),
        );
        // home_hero.png is the character art, scaled down.
        expect((hero.image as AssetImage).assetName, AppConstants.imgHomeHero);
        // And the login poster is not used here.
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName == AppConstants.imgPoster,
          ),
          findsNothing,
        );
      });

      testWidgets('the director card is hidden while the profile is empty', (
        tester,
      ) async {
        await pump(
          tester,
          fake(),
          home: HomeProvider(director: const DirectorProfile()),
        );
        expect(find.byType(InstructorDossierCard), findsNothing);
        expect(find.text(l10n.instructorSectionTitle), findsNothing);
        expect(find.text(l10n.readMore), findsNothing);
        // The rest of Home is unaffected.
        expect(find.byType(HomeHeroBanner), findsOneWidget);
        expect(find.text(l10n.myCourses), findsOneWidget);
      });

      testWidgets('layout mirrors ($direction)', (tester) async {
        await pump(tester, fake());
        final width = 390.0;
        // Hero text at the start edge, art at the end edge.
        final headline = find.text(l10n.heroHeadline);
        final art = find.byType(Image).first;
        if (direction == TextDirection.ltr) {
          expect(tester.getTopLeft(headline).dx, lessThan(40));
          expect(tester.getCenter(art).dx, greaterThan(width / 2));
        } else {
          expect(tester.getTopRight(headline).dx, greaterThan(width - 40));
          expect(tester.getCenter(art).dx, lessThan(width / 2));
        }
        // Director card: the name, then the title chips under it.
        final name = find.text(
          isArabic ? testDirector.nameAr : testDirector.name,
        );
        final firstTitle = find.text(
          isArabic ? testDirector.titlesAr.first : testDirector.titles.first,
        );
        expect(
          tester.getTopLeft(name).dy,
          lessThan(tester.getTopLeft(firstTitle).dy),
        );
        // "View all" is at the end edge of the my-courses header.
        expect(
          startsBefore(
            tester,
            find.text(l10n.myCourses),
            find.text(l10n.viewAll),
            direction,
          ),
          isTrue,
        );
      });

      testWidgets('loads the catalog once on open', (tester) async {
        final repo = fake();
        await pump(tester, repo);
        expect(repo.levelsCalls, 1);
      });

      testWidgets('shows a loading state until the catalog arrives', (
        tester,
      ) async {
        final repo = _SlowRepository();
        final catalog = await pump(tester, repo, settle: false);
        expect(find.byType(ThemedSkeletonList), findsOneWidget);
        expect(find.byType(ThemedEmptyState), findsNothing);
        expect(find.byType(ThemedErrorBanner), findsNothing);
        repo.release.complete();
        await tester.pumpAndSettle();
        expect(catalog.isReady, isTrue);
        expect(find.byType(ThemedSkeletonList), findsNothing);
        expect(find.byType(ThemedEmptyState), findsOneWidget);
      });

      testWidgets('owned subjects are listed and open the detail screen', (
        tester,
      ) async {
        await pump(tester, fake());
        expect(find.byType(OwnedSubjectTile), findsOneWidget);
        expect(find.byType(ThemedEmptyState), findsNothing);
        await tester.tap(find.byType(OwnedSubjectTile));
        await tester.pumpAndSettle();
        expect(find.text('route:/course-details:s3'), findsOneWidget);
      });

      testWidgets('owned tile mirrors: icon, text, chevron', (tester) async {
        await pump(tester, fake());
        final tile = find.byType(OwnedSubjectTile);
        final icon = find.descendant(
          of: tile,
          matching: find.byIcon(Icons.school_outlined),
        );
        final chevron = find.descendant(
          of: tile,
          matching: find.byIcon(Icons.chevron_right),
        );
        final title = find.descendant(
          of: tile,
          matching: find.text(isArabic ? 'مادة' : 'Subject'),
        );
        expect(startsBefore(tester, icon, title, direction), isTrue);
        expect(startsBefore(tester, title, chevron, direction), isTrue);
      });

      testWidgets('nothing owned: empty state whose button explores', (
        tester,
      ) async {
        var explored = 0;
        await pump(tester, noOwned(), onExplore: () => explored++);
        expect(find.byType(OwnedSubjectTile), findsNothing);
        expect(find.text(l10n.noOwnedCourses), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(ThemedEmptyState),
            matching: find.text(l10n.exploreCourses),
          ),
        );
        expect(explored, 1);
      });

      testWidgets('hero button and "view all" both explore', (tester) async {
        var explored = 0;
        await pump(tester, noOwned(), onExplore: () => explored++);
        await tester.tap(
          find.descendant(
            of: find.byType(HomeHeroBanner),
            matching: find.text(l10n.exploreCourses),
          ),
        );
        await tester.tap(find.text(l10n.viewAll));
        expect(explored, 2);
      });

      testWidgets('a failed load shows a persistent banner; retry reloads', (
        tester,
      ) async {
        final repo = fake()
          ..levelsError = ApiException(statusCode: 503, message: 'down');
        await pump(tester, repo);
        expect(find.byType(ThemedErrorBanner), findsOneWidget);
        expect(
          find.text(ErrorMessages.serviceUnavailable(isArabic)),
          findsOneWidget,
        );
        expect(find.byType(OwnedSubjectTile), findsNothing);
        await tester.pump(const Duration(minutes: 1));
        expect(find.byType(ThemedErrorBanner), findsOneWidget);

        repo.levelsError = null;
        await tester.tap(find.text(l10n.retry));
        await tester.pumpAndSettle();
        expect(repo.levelsCalls, 2);
        expect(find.byType(ThemedErrorBanner), findsNothing);
        expect(find.byType(OwnedSubjectTile), findsOneWidget);
      });

      testWidgets('pull to refresh reloads the catalog', (tester) async {
        final repo = fake();
        await pump(tester, repo, size: const Size(390, 844));
        expect(repo.levelsCalls, 1);
        await tester.fling(
          find.byType(SingleChildScrollView).first,
          const Offset(0, 400),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(repo.levelsCalls, 2);
      });

      testWidgets('biography toggle expands and collapses', (tester) async {
        final home = HomeProvider(director: testDirector);
        await pump(tester, fake(), home: home);
        expect(home.isBioExpanded, isFalse);
        await tester.tap(find.text(l10n.readMore));
        await tester.pumpAndSettle();
        expect(home.isBioExpanded, isTrue);
        expect(find.text(l10n.showLess), findsOneWidget);
      });
    });
  }

  test('OwnedSubjectTile.formatDate pads month and day', () {
    expect(OwnedSubjectTile.formatDate(DateTime.utc(2026, 3, 7)), '2026-03-07');
  });
}
