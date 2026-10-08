import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:wael_app/content/director_profile.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/constants.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/core/external_links.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
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
import 'package:wael_app/widgets/themed_skeleton.dart';

import 'academy_fakes.dart';
import 'director_fixture.dart';
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

    Future<(AcademyCatalogProvider, FakeAcademyRepository)> pump(
      WidgetTester tester,
      Map<String, dynamic> detail, {
      FakeAcademyRepository? repo,
      Size size = const Size(390, 2400),
      bool settle = true,
      DirectorProfile director = testDirector,
      bool showPrices = false,
    }) async {
      final repository = repo ?? fake();
      if (detail.isNotEmpty) repository.detailJson['d1'] = detail;
      final catalog = AcademyCatalogProvider(repository);
      final appConfig = AppConfigProvider()
        ..setForTesting(AppConfigData(showPrices: showPrices));
      await pumpScreen(
        tester,
        locale,
        const CourseDetailScreen(courseId: 'd1'),
        appConfig: appConfig,
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
          ChangeNotifierProvider(
            create: (_) => HomeProvider(director: director),
          ),
        ],
        size: size,
        settle: settle,
      );
      return (catalog, repository);
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
        final (_, repo) = await pump(tester, lockedBody);
        // Detail, then the automatic access request, then the detail again.
        expect(repo.detailCalls, 2);
        expect(repo.accessCalls, ['d1']);
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
          find.text(title(testDirector.nameAr, testDirector.name)),
          findsOneWidget,
        );
        expect(
          find.text(
            title(
              testDirector.localizedTagline(true),
              testDirector.localizedTagline(false),
            ),
          ),
          findsOneWidget,
        );
        // Gone with the mock: rating, hours, bookmark, share, syllabus download.
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.bookmark_border), findsNothing);
        expect(find.byIcon(Icons.share_outlined), findsNothing);
        expect(find.text(l10n.downloadSyllabus), findsNothing);
        expect(find.text(l10n.tabClasses), findsNothing);
      });

      testWidgets('the shipped director strip: portrait, name and titles', (
        tester,
      ) async {
        await pump(tester, lockedBody, director: kDirectorProfile);
        final strip = find.byType(DirectorStrip);
        expect(strip, findsOneWidget);
        expect(
          find.descendant(
            of: strip,
            matching: find.text(isArabic ? 'وائل السعيد' : 'Wael El Saeed'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: strip,
            matching: find.text(kDirectorProfile.localizedTagline(isArabic)),
          ),
          findsOneWidget,
        );
        final image = tester
            .widgetList<Container>(
              find.descendant(of: strip, matching: find.byType(Container)),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.image?.image)
            .whereType<ResizeImage>()
            .single;
        expect(
          (image.imageProvider as AssetImage).assetName,
          AppConstants.imgDirectorPortrait,
        );
        final decoration = tester
            .widgetList<Container>(
              find.descendant(of: strip, matching: find.byType(Container)),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.image)
            .whereType<DecorationImage>()
            .single;
        expect(decoration.fit, BoxFit.cover); // never stretched
      });

      testWidgets('no director strip while the director profile is empty', (
        tester,
      ) async {
        await pump(tester, lockedBody, director: const DirectorProfile());
        expect(find.byType(DirectorStrip), findsNothing);
        // The subject itself is unaffected.
        expect(find.text(title('القانون المدني', 'Civil Law')), findsOneWidget);
        expect(find.byType(CatalogVideoTile), findsNWidgets(2));
      });

      testWidgets('loading state until the detail arrives', (tester) async {
        final gate = Completer<void>();
        final repo = fake()..detailGate = gate.future;
        await pump(tester, lockedBody, repo: repo, settle: false);
        expect(find.byType(ThemedSkeletonList), findsOneWidget);
        expect(find.byType(ThemedErrorBanner), findsNothing);
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.byType(ThemedSkeletonList), findsNothing);
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
          // Retry: detail, the access request, then the detail again.
          expect(repo.detailCalls, 3);
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
            .descendant(
              of: strip,
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration! as BoxDecoration).shape == BoxShape.circle,
              ),
            )
            .first; // the 48px portrait; the status dot is the second circle
        final director = find.text(
          title(testDirector.nameAr, testDirector.name),
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
      testWidgets('owned: access banner with the expiry date, no request', (
        tester,
      ) async {
        final (_, repo) = await pump(
          tester,
          detailBody(owned: true, expires: '2027-01-15T10:00:00Z'),
        );
        expect(find.text(l10n.accessActive), findsOneWidget);
        expect(find.text(l10n.accessUntil('2027-01-15')), findsOneWidget);
        expect(find.byType(PrimaryButton), findsNothing);
        expect(find.text(l10n.requestPending), findsNothing);
        expect(find.text(l10n.sendingAccessRequest), findsNothing);
        expect(repo.accessCalls, isEmpty);
      });

      testWidgets('owned without an expiry: banner only', (tester) async {
        await pump(tester, detailBody(owned: true));
        expect(find.text(l10n.accessActive), findsOneWidget);
        expect(find.textContaining(l10n.accessUntil('').trim()), findsNothing);
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

    group('CourseDetailScreen access request [$name]', () {
      Finder copyButton() => find.text(l10n.copySupportLink);

      testWidgets('not owned, no request: it is sent on open, then pending', (
        tester,
      ) async {
        final (catalog, repo) = await pump(tester, lockedBody);
        expect(repo.accessCalls, ['d1']);
        // The detail was refetched, so pending is the server's answer.
        expect(repo.detailCalls, 2);
        expect(catalog.detailOf('d1').detail!.hasPendingRequest, isTrue);
        expect(find.text(l10n.requestPending), findsOneWidget);
        expect(find.text(l10n.contactSupportToActivate), findsOneWidget);
        expect(find.text(l10n.sendingAccessRequest), findsNothing);
        expect(find.text(l10n.accessActive), findsNothing);
        // The WhatsApp chat is the primary action; copy stays secondary.
        expect(find.text(l10n.openWhatsApp), findsOneWidget);
        expect(copyButton(), findsOneWidget);
        expect(find.byType(ThemedErrorBanner), findsNothing);
      });

      testWidgets('sending: progress while the request is in flight', (
        tester,
      ) async {
        final gate = Completer<void>();
        final repo = fake()..accessGate = gate.future;
        await pump(tester, lockedBody, repo: repo, settle: false);
        await tester.pump();
        await tester.pump();
        expect(find.text(l10n.sendingAccessRequest), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(l10n.requestPending), findsNothing);
        expect(find.byType(PrimaryButton), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text(l10n.sendingAccessRequest), findsNothing);
        expect(find.text(l10n.requestPending), findsOneWidget);
      });

      testWidgets('already pending on the server: nothing is sent', (
        tester,
      ) async {
        final repo = fake()..pendingIds.add('d1');
        await pump(tester, lockedBody, repo: repo);
        expect(repo.accessCalls, isEmpty);
        expect(find.text(l10n.requestPending), findsOneWidget);
        expect(find.text(l10n.contactSupportToActivate), findsOneWidget);
        expect(find.byType(PrimaryButton), findsNothing);
        // The detail carries no support link, so none is shown.
        expect(copyButton(), findsNothing);
      });

      testWidgets('409: a clear message, no retry, nothing pending', (
        tester,
      ) async {
        final repo = fake()
          ..accessError = ApiException(statusCode: 409, message: 'raw-409');
        await pump(tester, lockedBody, repo: repo);
        expect(
          find.text(ErrorMessages.accessRequestUnavailable(isArabic)),
          findsOneWidget,
        );
        expect(find.text('raw-409'), findsNothing);
        expect(find.text(l10n.retry), findsNothing);
        expect(find.text(l10n.requestPending), findsNothing);
        expect(repo.accessCalls, hasLength(1));
        // The content below is still there and still locked.
        expect(find.byType(CatalogVideoTile), findsNWidgets(2));
        expect(isLocked(tester, 0), isTrue);
      });

      testWidgets('404: the unknown-subject message, no retry', (tester) async {
        final repo = fake()
          ..accessError = ApiException(statusCode: 404, message: 'raw-404');
        await pump(tester, lockedBody, repo: repo);
        expect(
          find.text(ErrorMessages.subjectNotFound(isArabic)),
          findsOneWidget,
        );
        expect(find.text(l10n.retry), findsNothing);
      });

      testWidgets('429: try again later, and retry sends it again', (
        tester,
      ) async {
        final repo = fake()
          ..accessError = ApiException(statusCode: 429, message: 'raw-429');
        await pump(tester, lockedBody, repo: repo);
        expect(
          find.text(ErrorMessages.tryAgainLater(isArabic)),
          findsOneWidget,
        );
        expect(find.text('raw-429'), findsNothing);
        expect(repo.accessCalls, hasLength(1));

        repo.accessError = null;
        final retry = find.text(l10n.retry);
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(repo.accessCalls, hasLength(2));
        expect(find.byType(ThemedErrorBanner), findsNothing);
        expect(find.text(l10n.requestPending), findsOneWidget);
      });

      testWidgets('a network failure shows the network message with retry', (
        tester,
      ) async {
        final repo = fake()..accessError = const SocketException('raw-net');
        await pump(tester, lockedBody, repo: repo);
        expect(find.text(ErrorMessages.networkError(isArabic)), findsOneWidget);
        expect(find.textContaining('raw-net'), findsNothing);
        expect(find.text(l10n.retry), findsOneWidget);
      });

      testWidgets('the support link from the response can be copied', (
        tester,
      ) async {
        final copied = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await pump(tester, lockedBody);
        expect(copyButton(), findsOneWidget);
        await tester.ensureVisible(copyButton());
        await tester.tap(copyButton());
        await tester.pump();
        expect(copied, ['https://wa.me/201000000000']);
        expect(find.text(l10n.supportLinkCopied), findsOneWidget);
      });

      testWidgets('a locked subject shows its price when the API sends it', (
        tester,
      ) async {
        await pump(tester, lockedBody, showPrices: true);
        expect(find.text(l10n.priceLabel), findsOneWidget);
        expect(find.text(title('1800 ج.م', 'EGP 1800')), findsOneWidget);
        expect(find.textContaining('route:/payment'), findsNothing);
        expect(stubRouteArguments, isEmpty);
      });

      testWidgets('the price stays hidden when show_prices is off', (
        tester,
      ) async {
        await pump(tester, lockedBody, showPrices: false);
        expect(find.text(l10n.priceLabel), findsNothing);
        expect(find.text(title('1800 ج.م', 'EGP 1800')), findsNothing);
      });

      testWidgets('rebuilding the screen does not send the request again', (
        tester,
      ) async {
        final (catalog, repo) = await pump(tester, lockedBody);
        expect(repo.accessCalls, hasLength(1));
        catalog.setSearchQuery('x');
        await tester.pumpAndSettle();
        expect(repo.accessCalls, hasLength(1));
      });

      testWidgets('detail retry after a load failure then sends the request', (
        tester,
      ) async {
        final repo = fake()..detailError = const SocketException('down');
        await pump(tester, lockedBody, repo: repo);
        expect(repo.accessCalls, isEmpty);
        repo.detailError = null;
        await tester.tap(find.text(l10n.retry));
        await tester.pumpAndSettle();
        expect(repo.accessCalls, ['d1']);
        expect(find.text(l10n.requestPending), findsOneWidget);
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

  /// Records `Clipboard.setData` texts; the platform clipboard is mocked
  /// like the existing copy test does.
  Future<List<String>> captureClipboard(WidgetTester tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return copied;
  }

  group('support WhatsApp', () {
    Future<(AcademyCatalogProvider, FakeAcademyRepository)> pumpWithLauncher(
      WidgetTester tester,
      LaunchUrl launcher, {
      bool launcherSucceeds = true,
      Locale locale = const Locale('en'),
    }) async {
      final repository = fake();
      repository.detailJson['d1'] = detailBody(
        price: 1800,
        videos: [videoBody('v1', 1)],
        files: const [],
      );
      final catalog = AcademyCatalogProvider(repository);
      await pumpScreen(
        tester,
        locale,
        CourseDetailScreen(courseId: 'd1', launchUrl: launcher),
        auth: await signedInAuth(),
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(value: catalog),
          ChangeNotifierProvider(
            create: (_) => HomeProvider(director: testDirector),
          ),
        ],
        size: const Size(390, 2400),
      );
      return (catalog, repository);
    }

    testWidgets('opens the chat with the encoded prefilled message', (
      tester,
    ) async {
      final launched = <Uri>[];
      LaunchMode? usedMode;
      await pumpWithLauncher(tester, (
        url, {
        mode = LaunchMode.platformDefault,
      }) async {
        launched.add(url);
        usedMode = mode;
        return true;
      });
      final l10n = l10nFor(const Locale('en'));
      expect(find.text(l10n.requestPending), findsOneWidget);
      expect(find.text(l10n.openWhatsApp), findsOneWidget);

      await tester.tap(find.text(l10n.openWhatsApp));
      await tester.pumpAndSettle();

      expect(launched, hasLength(1));
      expect(usedMode, LaunchMode.externalApplication);
      final uri = launched.single;
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(
        uri.queryParameters['text'],
        l10n.whatsappRequestText('Civil Law', 'u@e.com'),
      );
    });

    testWidgets('a failed launch falls back to copying the link', (
      tester,
    ) async {
      final copied = await captureClipboard(tester);
      var launcherCalls = 0;
      await pumpWithLauncher(tester, (
        url, {
        mode = LaunchMode.platformDefault,
      }) async {
        launcherCalls++;
        return false;
      });
      final l10n = l10nFor(const Locale('en'));
      final openButton = find.text(l10n.openWhatsApp);
      await tester.ensureVisible(openButton);
      await tester.tap(openButton);
      await tester.pump();

      expect(launcherCalls, 1);
      expect(copied, ['https://wa.me/201000000000']);
      expect(find.text(l10n.supportLinkCopied), findsOneWidget);
    });

    testWidgets('copy stays a secondary action', (tester) async {
      final copied = await captureClipboard(tester);
      await pumpWithLauncher(
        tester,
        (url, {mode = LaunchMode.platformDefault}) async => true,
      );
      final l10n = l10nFor(const Locale('en'));
      final copyButton = find.text(l10n.copySupportLink);
      await tester.ensureVisible(copyButton);
      await tester.tap(copyButton);
      await tester.pump();

      expect(copied, ['https://wa.me/201000000000']);
      expect(find.text(l10n.supportLinkCopied), findsOneWidget);
    });
  });
}

String upper(String s) => s.toUpperCase();
