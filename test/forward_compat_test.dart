import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:provider/provider.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/main.dart' show buildAppRoutes;
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/models/notification_model.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/files_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/repositories/account_repository.dart';
import 'package:wael_app/repositories/auth_repository.dart';
import 'package:wael_app/repositories/notification_repository.dart';
import 'package:wael_app/screens/main_shell.dart';
import 'package:wael_app/screens/notifications_screen.dart';
import 'package:wael_app/screens/splash_screen.dart';

import 'academy_fakes.dart';
import 'files_fakes.dart';
import 'screen_harness.dart';
import 'store_safety_l10n_test.dart' show hasPaymentWord;
import 'widget_layer_harness.dart';

/// Forward compatibility (owner strategy 2026-10-08, C2): a newer (or
/// older) server must never crash the store build or put raw server text on
/// screen. Unknown fields are ignored, missing optional fields default, and
/// unknown codes, notification types and routes degrade to safe behaviour.

const _unknown = {
  'brand_new_field': 'x',
  'nested_future': {
    'a': [1, 2, 3],
  },
  'future_number': 42,
};

Map<String, dynamic> withUnknown(Map<String, dynamic> m) => {...m, ..._unknown};

/// The `GET /academy/app-config` body production serves today (the F-UX2 A7
/// shape: no `show_prices`, `center` or `features`).
const productionAppConfig = {
  'support_whatsapp_url': 'https://wa.me/201000000000',
  'terms_url': 'https://legal.elmetracademy.app/terms',
  'privacy_url': 'https://legal.elmetracademy.app/privacy',
};

/// Answers `appConfig()` by parsing [body] the way the HTTP repository does,
/// or throws [error].
class _JsonConfigRepo extends FakeAcademyRepository {
  _JsonConfigRepo({this.body, this.error})
    : super(levelList: [level('bachelor-y1', 'bachelor', 1)]);

  final Map<String, dynamic>? body;
  final Object? error;

  @override
  Future<AppConfigData> appConfig() async {
    if (error != null) throw error!;
    return AppConfigData.fromJson(body!);
  }
}

void main() {
  group('unknown JSON fields are ignored', () {
    test('levels, study types, subject list and detail', () {
      final levels = AcademyLevels.fromJson(
        withUnknown({
          'levels': [
            withUnknown({
              'key': 'bachelor-y1',
              'study_type': 'bachelor',
              'title': withUnknown({'ar': 'أ', 'en': 'A'}),
              'position': 1,
            }),
          ],
          'study_types': [
            withUnknown({
              'key': 'bachelor',
              'title': {'ar': 'ب', 'en': 'B'},
              'levels': <Object>[],
            }),
          ],
        }),
      );
      expect(levels.levels.single.key, 'bachelor-y1');
      expect(levels.studyTypes.single.key, 'bachelor');

      final page = SubjectPage.fromJson(
        withUnknown({
          'items': [
            withUnknown({
              'id': 's1',
              'level_key': 'bachelor-y1',
              'title': {'ar': 'م', 'en': 'S'},
              'owned': true,
              'counts': withUnknown({'videos': 1, 'books': 0, 'notes': 0}),
            }),
          ],
          'total': 1,
          'page': 1,
          'limit': 20,
        }),
      );
      expect(page.items.single.owned, isTrue);

      final detail = AcademySubjectDetail.fromJson(
        withUnknown({
          ...detailBody(
            owned: false,
            videos: [withUnknown(videoBody('v1', 1))],
            files: [withUnknown(fileBody('f1', 'note'))],
          ),
          'request': withUnknown({'status': 'pending'}),
        }),
      );
      expect(detail.videos.single.id, 'v1');
      expect(detail.files.single.id, 'f1');
      expect(detail.hasPendingRequest, isTrue);
    });

    test('play, access request and app-config', () {
      final play = VideoPlayback.fromJson(
        withUnknown({'video_id': 'v1', 'youtube_video_id': 'abcdefghijk'}),
      );
      expect(play.videoId, 'v1');
      final req = AccessRequest.fromJson(
        withUnknown({
          'id': 'r1',
          'subject_id': 's1',
          'status': 'pending',
          'created_at': '2026-10-08T10:00:00Z',
          'whatsapp_url': 'https://wa.me/201000000000',
        }),
      );
      expect(req.isPending, isTrue);
      final config = AppConfigData.fromJson(
        withUnknown({
          ...productionAppConfig,
          'features': withUnknown({'files': true}),
          'center': withUnknown({'name': 'C'}),
        }),
      );
      expect(config.filesEnabled, isTrue);
      expect(config.center?.nameFor(false), 'C');
    });

    test('auth, account and notification payloads', () async {
      final account = AuthAccount.fromJson(
        withUnknown({'id': 'u1', 'email': 'a@b.c', 'role': 'user'}),
      );
      expect(account.id, 'u1');
      final tokens = AuthTokens.fromJson(
        withUnknown({'access_token': 'a', 'refresh_token': 'r'}),
      );
      expect(tokens.access, 'a');
      final session = DeviceSession.fromJson(
        withUnknown({'sid': 's', 'current': true}),
      );
      expect(session.current, isTrue);

      final api = ApiClient(
        baseUrl: 'https://gw.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(
              withUnknown({
                'notifications': [
                  withUnknown({'id': 'n1', 'title': 'T', 'type': 'system'}),
                ],
              }),
            ),
            200,
          ),
        ),
      );
      final list = await HttpNotificationRepository(api).list();
      expect(list.single.id, 'n1');
    });
  });

  group('missing optional fields never crash', () {
    test('subject detail without optional keys', () {
      final detail = AcademySubjectDetail.fromJson({
        'id': 's1',
        'level_key': 'bachelor-y1',
        'title': {'ar': 'م'},
        'counts': {'videos': 0, 'books': 0, 'notes': 0},
        // no description, term, owned, price, currency, expiry, request,
        // videos or files
      });
      expect(detail.owned, isFalse);
      expect(detail.videos, isEmpty);
      expect(detail.files, isEmpty);
      expect(detail.request, isNull);
      expect(detail.price, isNull);
      expect(detail.accessExpiresAt, isNull);
      expect(detail.description.ar, isEmpty);
    });

    test('null videos and files lists read as empty', () {
      final detail = AcademySubjectDetail.fromJson({
        ...detailBody(),
        'videos': null,
        'files': null,
      });
      expect(detail.videos, isEmpty);
      expect(detail.files, isEmpty);
    });

    test('app-config, notification and account with empty bodies', () async {
      final config = AppConfigData.fromJson(const {});
      expect(config.filesEnabled, isFalse);
      expect(config.showPrices, isFalse);
      expect(config.center, isNull);
      expect(config.minVersion, isEmpty);

      final account = AuthAccount.fromJson(const {});
      expect(account.fullName, isEmpty);

      final api = ApiClient(
        baseUrl: 'https://gw.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'notifications': [<String, dynamic>{}, 'not-an-object', 7],
            }),
            200,
          ),
        ),
      );
      final list = await HttpNotificationRepository(api).list();
      expect(list, hasLength(1));
      expect(list.single.type, 'system');
      expect(list.single.subjectId, isNull);
    });

    test('an unknown file kind is labelled generically, never raw', () {
      final detail = AcademySubjectDetail.fromJson(
        detailBody(
          owned: true,
          files: [fileBody('x1', 'exam_sheet'), fileBody('n1', 'note')],
        ),
      );
      final unknown = detail.files.first;
      expect(unknown.isKnownKind, isFalse);
      expect(detail.books, isEmpty);
      expect(detail.notes.single.id, 'n1');
      for (final ar in [false, true]) {
        final label = l10nFor(
          ar ? const Locale('ar') : const Locale('en'),
        ).fileKind(unknown.kind);
        expect(label, isNot(contains('exam')));
        expect(label, ar ? 'ملف' : 'File');
      }
    });
  });

  group('unknown notification types and target routes', () {
    test(
      'parse to plain notifications; a non-string subject_id is ignored',
      () async {
        final api = ApiClient(
          baseUrl: 'https://gw.test',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'notifications': [
                  {
                    'id': 'n1',
                    'title': 'Hi',
                    'type': 'quantum_event',
                    'target_route': '/brand-new',
                    'subject_id': {'nested': true},
                  },
                  {'id': 'n2', 'title': 'Hi', 'subject_id': 12345},
                ],
              }),
              200,
            ),
          ),
        );
        final list = await HttpNotificationRepository(api).list();
        expect(list[0].type, 'quantum_event');
        expect(list[0].subjectId, isNull);
        expect(list[1].subjectId, isNull);
      },
    );

    test('allowlist kept; only registered routes are openable', () {
      for (final r in NotificationsScreen.allowedRoutes) {
        expect(NotificationsScreen.isValidTargetRoute(r), isTrue);
      }
      expect(NotificationsScreen.canOpenTargetRoute('/settings'), isTrue);
      for (final r in [
        '/courses',
        '/device-management',
        '/login',
        '/update-gate',
        '/brand-new',
        'https://evil.example',
        'javascript:alert(1)',
        '',
        null,
      ]) {
        expect(NotificationsScreen.canOpenTargetRoute(r), isFalse, reason: r);
      }
      // Every openable route is one the app registers.
      for (final r in NotificationsScreen.openableRoutes) {
        expect(
          r == '/course-details' ||
              buildAppRoutes(includeDebugRoutes: false).containsKey(r),
          isTrue,
          reason: r,
        );
      }
    });

    for (final (name, locale, _) in kLocales) {
      for (final route in [
        '/courses',
        '/device-management',
        '/brand-new',
        'https://evil.example',
        '',
      ]) {
        testWidgets('[$name] tap on type=quantum_event route="$route" '
            'marks read and stays', (tester) async {
          final provider = NotificationsProvider(
            repository: _OneItemRepo(
              NotificationModel(
                id: 'n1',
                title: 'Future',
                titleAr: 'مستقبل',
                body: 'b',
                bodyAr: 'ب',
                timestamp: 'now',
                timestampAr: 'الآن',
                type: 'quantum_event',
                targetRoute: route,
              ),
            ),
          );
          await pumpScreen(
            tester,
            locale,
            const NotificationsScreen(),
            notifications: provider,
          );
          await tester.tap(
            find.text(locale.languageCode == 'ar' ? 'مستقبل' : 'Future'),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(provider.notifications.first.isRead, isTrue);
          expect(find.byType(NotificationsScreen), findsOneWidget);
          expect(find.textContaining('route:'), findsNothing);
          // Shown as a plain notification (default icon).
          expect(find.byIcon(Icons.info_outline), findsOneWidget);
        });
      }
    }
  });

  group('unknown server error codes get a generic localized message', () {
    for (final ar in [false, true]) {
      test('[${ar ? 'ar' : 'en'}] every mapper', () {
        for (final status in [400, 409, 418, 422, 451, 500, 502, 504]) {
          final e = ApiException(
            statusCode: status,
            message: 'RAW SERVER TEXT',
            code: 'brand_new_code',
          );
          final messages = [
            ErrorMessages.forApiError(e, isArabic: ar),
            ErrorMessages.forException(e, isArabic: ar),
            ErrorMessages.forCatalog(e, isArabic: ar),
            ErrorMessages.forAccessRequest(e, isArabic: ar),
            ErrorMessages.forAccountError(e, isArabic: ar),
            ErrorMessages.forFileDownload(e, isArabic: ar),
          ];
          for (final m in messages) {
            expect(m, isNot(contains('RAW')), reason: '$status');
            expect(m, isNot(contains('brand_new_code')));
            expect(m, isNotEmpty);
            expect(hasPaymentWord(m), isFalse, reason: m);
            expect(RegExp('[؀-ۿ]').hasMatch(m), ar, reason: 'language of "$m"');
          }
        }
      });
    }
  });

  group('update gate: the emergency lever', () {
    AppConfigProvider provider(Map<String, dynamic> body) => AppConfigProvider(
      repository: _JsonConfigRepo(body: body),
      cache: MemoryAppConfigCache(),
      versionReader: () async => '1.0.0',
    );

    test('min_version above the build blocks; latest above offers', () async {
      final blocking = provider({
        ...productionAppConfig,
        'min_version': '1.0.1',
        'update_url': 'https://play.google.com/store/apps/details?id=x',
      });
      await blocking.load();
      expect(blocking.updateState('1.0.0'), UpdateState.required);
      expect(blocking.config.updateUrl, startsWith('https://'));

      final soft = provider({...productionAppConfig, 'latest_version': '1.1'});
      await soft.load();
      expect(soft.updateState('1.0.0'), UpdateState.available);

      final none = provider({
        ...productionAppConfig,
        'min_version': '1.0.0',
        'latest_version': '1.0.0',
      });
      await none.load();
      expect(none.updateState('1.0.0'), UpdateState.none);

      // A non-https update_url is dropped (the gate then says "contact
      // support" instead of opening it); the block itself still holds.
      final insecure = provider({
        ...productionAppConfig,
        'min_version': '2.0.0',
        'update_url': 'http://evil.example/app.apk',
      });
      await insecure.load();
      expect(insecure.updateState('1.0.0'), UpdateState.required);
      expect(insecure.config.updateUrl, isEmpty);
    });

    for (final (name, locale, _) in kLocales) {
      testWidgets('[$name] splash blocks on min_version from the server', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          locale,
          const SplashScreen(),
          appConfig: provider({...productionAppConfig, 'min_version': '9.0'}),
        );
        expect(find.text('route:/update-gate'), findsOneWidget);
      });

      testWidgets('[$name] splash does not block on latest_version only', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          locale,
          const SplashScreen(),
          appConfig: provider({
            ...productionAppConfig,
            'latest_version': '9.0',
          }),
        );
        expect(find.text('route:/update-gate'), findsNothing);
        expect(find.text('route:/login'), findsOneWidget);
      });
    }
  });

  group('works with production app-config and with it unreachable', () {
    for (final (name, locale, _) in kLocales) {
      final l10n = l10nFor(locale);
      for (final (label, repo) in [
        ('production shape', _JsonConfigRepo(body: productionAppConfig)),
        (
          'unreachable (404)',
          _JsonConfigRepo(error: ApiException(statusCode: 404, message: 'x')),
        ),
        ('offline', _JsonConfigRepo(error: const SocketException('down'))),
      ]) {
        testWidgets('[$name] $label: every tab renders, features off', (
          tester,
        ) async {
          final config = AppConfigProvider(
            repository: repo,
            cache: MemoryAppConfigCache(),
            versionReader: () async => '1.0.0',
          );
          await config.load();
          expect(config.filesEnabled, isFalse);
          expect(config.showPrices, isFalse);

          final catalogRepo = fake();
          await pumpScreen(
            tester,
            locale,
            const MainShell(),
            appConfig: config,
            extraProviders: [
              ChangeNotifierProvider(
                create: (_) => AcademyCatalogProvider(catalogRepo),
              ),
              ChangeNotifierProvider<FilesProvider>(
                create: (_) => FilesProvider(
                  store: FakeFileDownloadStore(),
                  opener: FakeOpener(),
                ),
              ),
              ChangeNotifierProvider(create: (_) => HomeProvider()),
            ],
          );
          // Bottom-bar labels are shown upper-cased (a no-op in Arabic).
          final tabs = [
            l10n.navHome,
            l10n.navCourses,
            l10n.navNotes,
            l10n.navSettings,
          ].map((t) => t.toUpperCase()).toList();
          for (final tab in [1, 3, 0, 2]) {
            await tester.tap(find.text(tabs[tab]).last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'tab $tab');
          }
          // Notes tab (last tapped): today's coming-soon state.
          expect(find.text(l10n.ebookComingSoon), findsOneWidget);
          expect(find.text(l10n.navNotesAndBooks), findsNothing);
        });
      }
    }
  });
}

class _OneItemRepo implements NotificationRepository {
  _OneItemRepo(this.item);

  final NotificationModel item;

  @override
  List<NotificationModel> initial() => [item];

  @override
  Future<List<NotificationModel>> list({int page = 1, int limit = 20}) async =>
      [item];

  @override
  Future<void> markRead(String id) async {}
}
