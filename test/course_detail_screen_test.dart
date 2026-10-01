import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/models/course.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/ebook_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/screens/course_detail/subject_content_section.dart';
import 'package:wael_app/screens/course_detail_screen.dart';
import 'package:wael_app/screens/video_player_screen.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/catalog_file_tile.dart';
import 'package:wael_app/widgets/catalog_video_tile.dart';
import 'package:wael_app/widgets/director_strip.dart';
import 'package:wael_app/widgets/primary_button.dart';
import 'package:wael_app/widgets/selectable_chip.dart';
import 'package:wael_app/widgets/subject_hero_banner.dart';
import 'package:wael_app/widgets/themed_empty_state.dart';
import 'package:wael_app/widgets/themed_error_banner.dart';
import 'package:wael_app/widgets/themed_loading_indicator.dart';

import 'academy_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

/// The tab bar scrolls horizontally, so bring a tab into view before tapping.
Future<void> tapTab(WidgetTester tester, String label) async {
  final tab = find.text(label);
  await tester.ensureVisible(tab);
  await tester.pump();
  await tester.tap(tab);
  await tester.pump();
}

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    final isArabic = locale.languageCode == 'ar';
    String title(String ar, String en) => isArabic ? ar : en;

    Future<(AcademyCatalogProvider, FakeAcademyRepository, EBookProvider)> pump(
      WidgetTester tester,
      Map<String, dynamic> detail, {
      FakeAcademyRepository? repo,
      Size size = const Size(390, 2400),
      bool settle = true,
    }) async {
      final repository = repo ?? fake();
      if (detail.isNotEmpty) repository.detailJson['d1'] = detail;
      final catalog = AcademyCatalogProvider(repository);
      final ebooks = EBookProvider();
      await pumpScreen(
        tester,
        locale,
        const CourseDetailScreen(courseId: 'd1'),
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
          ChangeNotifierProvider(create: (_) => HomeProvider()),
          ChangeNotifierProvider<EBookProvider>.value(value: ebooks),
        ],
        size: size,
        settle: settle,
      );
      return (catalog, repository, ebooks);
    }

    Finder videoTiles() => find.byType(CatalogVideoTile);
    bool isLocked(WidgetTester tester, int index) =>
        tester.widget<CatalogVideoTile>(videoTiles().at(index)).locked;

    final lockedBody = detailBody(
      price: 1800,
      videos: [videoBody('v1', 1), videoBody('v2', 2)],
      files: [fileBody('b1', 'book'), fileBody('n1', 'note', size: 2048)],
    );

    group('CourseDetailScreen [$name]', () {
      testWidgets('loads the subject by id and shows the ready state', (
        tester,
      ) async {
        final (_, repo, _) = await pump(tester, lockedBody);
        expect(repo.detailCalls, 1);
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.text(upper(l10n.courseDossier)), findsOneWidget);
        expect(find.text(title('القانون المدني', 'Civil Law')), findsOneWidget);
        expect(
          find.text(title('وصف المادة', 'About the subject')),
          findsOneWidget,
        );
        expect(find.byType(SubjectHeroBanner), findsOneWidget);
        expect(find.text(upper(l10n.termLabel('first'))), findsOneWidget);
        expect(find.byType(DirectorStrip), findsOneWidget);
        expect(
          find.text(title('المستشار د. وائل المتر', 'Dean Wael El Metr')),
          findsOneWidget,
        );
        // Gone with the mock: rating, hours, bookmark, share, syllabus download.
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.bookmark_border), findsNothing);
        expect(find.byIcon(Icons.share_outlined), findsNothing);
        expect(find.text(l10n.downloadSyllabus), findsNothing);
        expect(find.text(l10n.tabClasses), findsNothing);
      });

      testWidgets('loading state until the detail arrives', (tester) async {
        final gate = Completer<void>();
        final repo = fake()..detailGate = gate.future;
        await pump(tester, lockedBody, repo: repo, settle: false);
        expect(find.byType(ThemedLoadingIndicator), findsOneWidget);
        expect(find.byType(ThemedErrorBanner), findsNothing);
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.byType(ThemedLoadingIndicator), findsNothing);
        expect(find.byType(CatalogVideoTile), findsNWidgets(2));
      });

      testWidgets(
        'an unknown subject (404) is a persistent banner; retry works',
        (tester) async {
          final repo = fake()
            ..detailError = ApiException(statusCode: 404, message: 'nf');
          await pump(tester, lockedBody, repo: repo);
          expect(find.byType(ThemedErrorBanner), findsOneWidget);
          expect(
            find.text(ErrorMessages.subjectNotFound(isArabic)),
            findsOneWidget,
          );
          expect(find.byType(SubjectHeroBanner), findsNothing);
          await tester.pump(const Duration(minutes: 1));
          expect(find.byType(ThemedErrorBanner), findsOneWidget);

          repo.detailError = null;
          await tester.tap(find.text(l10n.retry));
          await tester.pumpAndSettle();
          expect(repo.detailCalls, 2);
          expect(find.byType(ThemedErrorBanner), findsNothing);
          expect(find.byType(CatalogVideoTile), findsNWidgets(2));
        },
      );

      testWidgets('a network failure shows the network message', (
        tester,
      ) async {
        final repo = fake()..detailError = const SocketException('down');
        await pump(tester, lockedBody, repo: repo);
        expect(find.text(ErrorMessages.networkError(isArabic)), findsOneWidget);
      });

      testWidgets('layout mirrors ($direction)', (tester) async {
        await pump(tester, lockedBody);
        final width = 390.0;
        // Hero tag at the start edge.
        final tag = find.text(upper(l10n.termLabel('first')));
        if (direction == TextDirection.ltr) {
          expect(tester.getTopLeft(tag).dx, lessThan(width / 2));
        } else {
          expect(tester.getTopRight(tag).dx, greaterThan(width / 2));
        }
        // Back button before the header title.
        expect(
          startsBefore(
            tester,
            find.byTooltip(l10n.back),
            find.text(upper(l10n.courseDossier)),
            direction,
          ),
          isTrue,
        );
        // Director portrait before the name; title at the start edge.
        final strip = find.byType(DirectorStrip);
        final avatar = find
            .descendant(of: strip, matching: find.byType(Container))
            .first;
        final director = find.text(
          title('المستشار د. وائل المتر', 'Dean Wael El Metr'),
        );
        expect(startsBefore(tester, avatar, director, direction), isTrue);
        final heading = find.text(title('القانون المدني', 'Civil Law'));
        if (direction == TextDirection.ltr) {
          expect(tester.getTopLeft(heading).dx, lessThan(40));
        } else {
          expect(tester.getTopRight(heading).dx, greaterThan(width - 40));
        }
        // Tabs run from the start edge; a video tile's icon precedes its title
        // and the lock is at the end.
        final chips = find.byType(SelectableChip);
        expect(
          startsBefore(tester, chips.at(0), chips.at(1), direction),
          isTrue,
        );
        expect(
          startsBefore(tester, chips.at(1), chips.at(2), direction),
          isTrue,
        );
        final tile = videoTiles().first;
        final tileLock = find.descendant(
          of: tile,
          matching: find.byIcon(Icons.lock_outline),
        );
        final tileTitle = find.descendant(
          of: tile,
          matching: find.text(title('درس 1', 'Lesson 1')),
        );
        expect(
          startsBefore(tester, tileLock.first, tileTitle, direction),
          isTrue,
        );
        expect(
          startsBefore(tester, tileTitle, tileLock.last, direction),
          isTrue,
        );
      });
    });

    group('CourseDetailScreen access rules [$name]', () {
      testWidgets('not owned: every video is locked and tapping says so', (
        tester,
      ) async {
        await pump(tester, lockedBody);
        expect(videoTiles(), findsNWidgets(2));
        expect(isLocked(tester, 0), isTrue);
        expect(isLocked(tester, 1), isTrue);
        expect(find.byIcon(Icons.play_arrow), findsNothing);
        await tester.tap(videoTiles().first);
        await tester.pump();
        expect(find.text(ErrorMessages.courseLocked(isArabic)), findsOneWidget);
        expect(stubRouteArguments, isEmpty);
      });

      testWidgets('owned but not playable: still locked', (tester) async {
        await pump(
          tester,
          detailBody(
            owned: true,
            videos: [videoBody('v1', 1), videoBody('v2', 2)],
          ),
        );
        expect(isLocked(tester, 0), isTrue);
        expect(isLocked(tester, 1), isTrue);
      });

      testWidgets('playable video is unlocked; others stay locked', (
        tester,
      ) async {
        await pump(
          tester,
          detailBody(
            owned: true,
            videos: [videoBody('v1', 1, playable: true), videoBody('v2', 2)],
          ),
        );
        expect(isLocked(tester, 0), isFalse);
        expect(isLocked(tester, 1), isTrue);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        await tester.tap(videoTiles().first);
        await tester.pump();
        await tester.pumpAndSettle();
        // The player route gets the academy's video id and text, never a
        // YouTube id.
        expect(find.textContaining('route:/video-player'), findsOneWidget);
        final args = stubRouteArguments.last! as VideoPlayerArgs;
        expect(args.videoId, 'v1');
        expect(args.title, title('درس 1', 'Lesson 1'));
      });

      testWidgets('playable unlocks even when owned is false', (tester) async {
        await pump(
          tester,
          detailBody(
            owned: false,
            videos: [videoBody('v1', 1, playable: true)],
          ),
        );
        expect(isLocked(tester, 0), isFalse);
      });

      testWidgets('owned alone does not unlock a video that is not playable', (
        tester,
      ) async {
        await pump(
          tester,
          detailBody(owned: true, videos: [videoBody('v1', 1)]),
        );
        expect(isLocked(tester, 0), isTrue);
      });

      testWidgets('videos are shown in position order', (tester) async {
        await pump(
          tester,
          detailBody(
            videos: [
              videoBody('v3', 3),
              videoBody('v1', 1),
              videoBody('v2', 2),
            ],
          ),
        );
        final titles = tester
            .widgetList<CatalogVideoTile>(videoTiles())
            .map((t) => t.video.position)
            .toList();
        expect(titles, [1, 2, 3]);
      });

      test('videoUnlocked is exactly the playable flag', () {
        AcademySubjectDetail d({required bool owned, required bool playable}) =>
            AcademySubjectDetail.fromJson(
              detailBody(
                owned: owned,
                videos: [videoBody('v', 1, playable: playable)],
              ),
            );
        bool u(AcademySubjectDetail x) =>
            SubjectContentSection.videoUnlocked(x, x.videos.single);
        expect(u(d(owned: true, playable: true)), isTrue);
        expect(u(d(owned: false, playable: true)), isTrue);
        expect(u(d(owned: true, playable: false)), isFalse);
        expect(u(d(owned: false, playable: false)), isFalse);
      });

      test('no YouTube URL is built anywhere in lib/', () {
        final offenders = <String>[];
        for (final entity in Directory('lib').listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final text = entity.readAsStringSync();
          for (final needle in [
            'youtube.com',
            'youtu.be',
            'watch?v=',
            'embed/',
          ]) {
            if (text.contains(needle)) offenders.add('${entity.path}: $needle');
          }
        }
        expect(offenders, isEmpty);
      });
    });

    group('CourseDetailScreen content [$name]', () {
      testWidgets('three tabs with counts; classes is gone', (tester) async {
        await pump(tester, lockedBody);
        expect(find.byType(SelectableChip), findsNWidgets(3));
        expect(find.text(l10n.tabVideos), findsOneWidget);
        expect(find.text(l10n.tabBooks), findsOneWidget);
        expect(find.text(l10n.tabMaterials), findsOneWidget);
        expect(find.text(l10n.itemsCount(4)), findsOneWidget);
      });

      testWidgets('books and notes tabs list files by kind; files are locked', (
        tester,
      ) async {
        await pump(tester, lockedBody);
        await tapTab(tester, l10n.tabBooks);
        await tester.pump();
        expect(find.byType(CatalogFileTile), findsOneWidget);
        expect(find.text('1.0 MB'), findsOneWidget);
        expect(
          tester.widget<CatalogFileTile>(find.byType(CatalogFileTile)).file.id,
          'b1',
        );
        expect(
          tester.widget<CatalogFileTile>(find.byType(CatalogFileTile)).locked,
          isTrue,
        );

        await tapTab(tester, l10n.tabMaterials);
        await tester.pump();
        expect(
          tester.widget<CatalogFileTile>(find.byType(CatalogFileTile)).file.id,
          'n1',
        );
        expect(find.text('2 KB'), findsOneWidget);
      });

      testWidgets('empty tabs show their own message', (tester) async {
        await pump(tester, detailBody());
        expect(find.byType(ThemedEmptyState), findsOneWidget);
        expect(find.text(l10n.emptyVideos), findsOneWidget);
        await tapTab(tester, l10n.tabBooks);
        await tester.pump();
        expect(find.text(l10n.emptyBooks), findsOneWidget);
        await tapTab(tester, l10n.tabMaterials);
        await tester.pump();
        expect(find.text(l10n.emptyMaterials), findsOneWidget);
      });

      testWidgets('tapping a locked file explains why', (tester) async {
        await pump(tester, lockedBody);
        await tapTab(tester, l10n.tabBooks);
        await tester.pump();
        await tester.tap(find.byType(CatalogFileTile));
        await tester.pumpAndSettle();
        expect(find.text(ErrorMessages.courseLocked(isArabic)), findsOneWidget);
        expect(find.text(title('ملف b1', 'File b1')), findsNWidgets(2));
      });

      testWidgets('an owned file says downloads are not available yet', (
        tester,
      ) async {
        await pump(
          tester,
          detailBody(owned: true, files: [fileBody('b1', 'book')]),
        );
        await tapTab(tester, l10n.tabBooks);
        await tester.pump();
        expect(
          tester.widget<CatalogFileTile>(find.byType(CatalogFileTile)).locked,
          isFalse,
        );
        await tester.tap(find.byType(CatalogFileTile));
        await tester.pumpAndSettle();
        expect(find.text(l10n.downloadsSoon), findsOneWidget);
      });
    });

    group('CourseDetailScreen actions [$name]', () {
      testWidgets('not owned: enrol button shows the price and opens payment', (
        tester,
      ) async {
        await pump(tester, lockedBody);
        final button = find.widgetWithText(
          PrimaryButton,
          '${l10n.enrollNow} (1800 EGP)',
        );
        expect(button, findsOneWidget);
        expect(find.text(l10n.accessActive), findsNothing);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.textContaining('route:/payment'), findsOneWidget);
        final course = stubRouteArguments.last! as Course;
        expect(course.id, 'd1');
        expect(course.title, 'Civil Law');
        expect(course.titleAr, 'القانون المدني');
        expect(course.priceEgp, 1800);
        expect(course.isEnrolled, isFalse);
        expect(course.imagePath, isNotEmpty);
      });

      testWidgets(
        'price absent: the button has no price and the bridge uses 0',
        (tester) async {
          await pump(tester, detailBody(videos: [videoBody('v1', 1)]));
          final button = find.widgetWithText(PrimaryButton, l10n.enrollNow);
          expect(button, findsOneWidget);
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect((stubRouteArguments.last! as Course).priceEgp, 0);
        },
      );

      testWidgets(
        'owned: access banner with the expiry date, no enrol button',
        (tester) async {
          await pump(
            tester,
            detailBody(owned: true, expires: '2027-01-15T10:00:00Z'),
          );
          expect(find.text(l10n.accessActive), findsOneWidget);
          expect(find.text(l10n.accessUntil('2027-01-15')), findsOneWidget);
          expect(find.byType(PrimaryButton), findsNothing);
        },
      );

      testWidgets('owned without an expiry: banner only', (tester) async {
        await pump(tester, detailBody(owned: true));
        expect(find.text(l10n.accessActive), findsOneWidget);
        expect(find.textContaining(l10n.accessUntil('').trim()), findsNothing);
      });

      testWidgets('add to notes creates a study note', (tester) async {
        final (_, _, ebooks) = await pump(tester, lockedBody);
        final before = ebooks.personalNotes.length;
        final card = find.text(l10n.addToNotes);
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pump();
        expect(ebooks.personalNotes.length, before + 1);
        expect(ebooks.personalNotes.first.course, 'Civil Law');
        expect(find.text(l10n.noteCreated), findsOneWidget);
      });

      testWidgets('back button pops the screen', (tester) async {
        await pumpScreen(
          tester,
          locale,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CourseDetailScreen(courseId: 'd1'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
          extraProviders: [
            ChangeNotifierProvider(
              create: (_) =>
                  AcademyCatalogProvider(fake()..detailJson['d1'] = lockedBody),
            ),
            ChangeNotifierProvider(create: (_) => HomeProvider()),
            ChangeNotifierProvider(create: (_) => EBookProvider()),
          ],
          size: const Size(390, 2400),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(CourseDetailScreen), findsOneWidget);
        await tester.tap(find.byTooltip(l10n.back));
        await tester.pumpAndSettle();
        expect(find.byType(CourseDetailScreen), findsNothing);
      });
    });

    for (final width in [360.0, 390.0]) {
      testWidgets('[$name] no overflow with long text at ${width.toInt()}px', (
        tester,
      ) async {
        await pump(
          tester,
          detailBody(
            price: 1800,
            titleAr:
                'المدخل للعلوم القانونية (نظرية القانون ونظرية الحق) والأنظمة القضائية المقارنة',
            titleEn:
                'Introduction to Legal Science: Theory of Law, Theory of Rights and Comparative Judicial Systems',
            videos: [
              videoBody(
                'v1',
                1,
                en: 'A very long lesson title that keeps going well past the width of a phone screen',
                ar: 'عنوان درس طويل جداً يستمر إلى ما بعد عرض شاشة الهاتف بكثير',
              ),
            ],
            files: [
              fileBody(
                'b1',
                'book',
                en: 'An extremely long book title for the overflow check',
                ar: 'عنوان كتاب طويل للغاية لاختبار الفيض',
              ),
            ],
          ),
          size: Size(width, 3000),
        );
        expect(tester.takeException(), isNull);
        await tapTab(tester, l10n.tabBooks);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(CatalogFileTile), findsOneWidget);
      });
    }
  }
}

String upper(String s) => s.toUpperCase();
