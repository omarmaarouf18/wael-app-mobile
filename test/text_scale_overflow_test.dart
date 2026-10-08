import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:wael_app/core/theme.dart';
import 'package:wael_app/l10n/app_localizations.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/models/notification_model.dart';
import 'package:wael_app/player/player_engine.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/account_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/screens/course_detail_screen.dart';
import 'package:wael_app/screens/courses_screen.dart';
import 'package:wael_app/screens/ebook_screen.dart';
import 'package:wael_app/screens/home_screen.dart';
import 'package:wael_app/screens/login_screen.dart';
import 'package:wael_app/screens/notifications_screen.dart';
import 'package:wael_app/screens/settings_screen.dart';
import 'package:wael_app/screens/update_gate_screen.dart';
import 'package:wael_app/widgets/player_next_cards.dart';
import 'package:wael_app/widgets/protected_video_surface.dart';

import 'academy_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

/// Pumps [screen] at 2.0x text scaling with the app's providers backed by
/// fakes. No fixed heights on text containers: any clipping fails via
/// [tester.takeException].
Future<void> pumpScaled(
  WidgetTester tester,
  Locale locale,
  Widget screen, {
  AuthProvider? auth,
  NotificationsProvider? notifications,
  AcademyCatalogProvider? catalog,
  HomeProvider? home,
  AppConfigProvider? appConfig,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final authProvider = auth ?? makeAuth();

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: appConfig ?? AppConfigProvider()),
        ChangeNotifierProvider.value(
          value: AccountProvider(
            auth: authProvider,
            repository: null,
            localeReader: () => locale.languageCode,
          ),
        ),
        ChangeNotifierProvider.value(
          value: notifications ?? NotificationsProvider(),
        ),
        ChangeNotifierProvider.value(
          value: catalog ?? AcademyCatalogProvider(fake()),
        ),
        ChangeNotifierProvider.value(value: home ?? HomeProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: locale,
        supportedLocales: const [Locale('en', ''), Locale('ar', '')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<AcademyCatalogProvider> loadedCatalog() async {
  final catalog = AcademyCatalogProvider(fake());
  await catalog.reload();
  return catalog;
}

NotificationsProvider notificationsWithItems() {
  final notifications = NotificationsProvider();
  const longAr =
      'تم قبول طلبك لتفعيل مادة القانون المدني للفرقة الأولى ويمكنك الآن مشاهدة جميع الحصص والفيديوهات الخاصة بها';
  const longEn =
      'Your request to activate Civil Law for First Year was approved and you can now watch every lesson and video in it';
  notifications.addNotification(
    const NotificationModel(
      id: 'n1',
      title: longAr,
      body: longEn,
      timestamp: 'now',
      type: 'course',
    ),
  );
  notifications.addNotification(
    const NotificationModel(
      id: 'n2',
      title: longEn,
      body: longAr,
      timestamp: 'now',
      type: 'payment',
    ),
  );
  return notifications;
}

void main() {
  for (final (name, locale, _) in kLocales) {
    group('TextScaler 2.0 [$name]', () {
      testWidgets('login has no overflow', (tester) async {
        await pumpScaled(tester, locale, const LoginScreen());
        expect(tester.takeException(), isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('login with session replaced active has no overflow', (
        tester,
      ) async {
        final auth = makeAuth();
        await auth.handleSessionReplaced();
        final config = AppConfigProvider()
          ..setForTesting(
            const AppConfigData(
              supportWhatsappUrl: 'https://wa.me/201000000000',
            ),
          );
        await pumpScaled(
          tester,
          locale,
          const LoginScreen(),
          auth: auth,
          appConfig: config,
          size: const Size(390, 1000),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('home has no overflow', (tester) async {
        await pumpScaled(
          tester,
          locale,
          HomeScreen(onExploreCourses: () {}),
          catalog: await loadedCatalog(),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('courses has no overflow', (tester) async {
        await pumpScaled(
          tester,
          locale,
          const CoursesScreen(),
          catalog: await loadedCatalog(),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('subject detail has no overflow', (tester) async {
        final catalog = await loadedCatalog();
        await catalog.openSubject('s1');
        await pumpScaled(
          tester,
          locale,
          const CourseDetailScreen(courseId: 's1'),
          catalog: catalog,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('notifications has no overflow', (tester) async {
        await pumpScaled(
          tester,
          locale,
          const NotificationsScreen(),
          notifications: notificationsWithItems(),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('settings has no overflow', (tester) async {
        await pumpScaled(
          tester,
          locale,
          const SettingsScreen(),
          auth: await signedInAuth(),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('settings with Help section has no overflow', (tester) async {
        final config = AppConfigProvider()
          ..setForTesting(
            const AppConfigData(
              supportWhatsappUrl: 'https://wa.me/201000000000',
              center: CenterInfo(
                nameAr: 'السنتر',
                nameEn: 'El Metr Center',
                addressAr: 'مدينة نصر، القاهرة — سطر عنوان طويل للالتفاف',
                addressEn:
                    'Nasr City, Cairo — a long address line for wrapping',
                hoursAr: 'يوميًا من العاشرة صباحًا حتى العاشرة مساءً',
                hoursEn: 'Daily from 10 in the morning until 10 at night',
                mapUrl: 'https://maps.example/center',
              ),
            ),
          );
        await pumpScaled(
          tester,
          locale,
          const SettingsScreen(),
          auth: await signedInAuth(),
          appConfig: config,
          size: const Size(390, 1200),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('e-book has no overflow', (tester) async {
        await pumpScaled(tester, locale, const EbookScreen());
        expect(tester.takeException(), isNull);
      });

      testWidgets('player next-lesson button has no overflow', (tester) async {
        await pumpScaled(
          tester,
          locale,
          NextLessonButton(title: _longLessonTitle, onTap: () {}),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('player next-lesson countdown has no overflow', (
        tester,
      ) async {
        await pumpScaled(
          tester,
          locale,
          NextCountdownCard(
            title: _longLessonTitle,
            secondsLeft: 5,
            onCancel: () {},
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('player subject-end card has no overflow', (tester) async {
        await pumpScaled(tester, locale, SubjectEndCard(onBack: () {}));
        expect(tester.takeException(), isNull);
      });

      testWidgets('player ended cover with footer has no overflow', (
        tester,
      ) async {
        await pumpScaled(
          tester,
          locale,
          ProtectedVideoSurface(
            video: const SizedBox.expand(),
            snapshot: const PlayerSnapshot(
              phase: PlayerPhase.ended,
              duration: Duration(minutes: 3),
            ),
            watermarkText: 'Wael El Saeed 01234567890',
            controlsVisible: false,
            isFullscreen: false,
            onTap: () {},
            onPlayPause: () {},
            onSeek: (_) {},
            onToggleFullscreen: () {},
            onReplay: () {},
            endedFooter: NextCountdownCard(
              title: _longLessonTitle,
              secondsLeft: 5,
              onCancel: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('UpdateGateScreen does not overflow at 2.0x text scaling', (
        tester,
      ) async {
        await pumpScaled(tester, locale, const UpdateGateScreen());
        expect(tester.takeException(), isNull);
      });
    });
  }
}

/// A lesson title long enough to wrap at 2.0x scaling, in both languages.
const _longLessonTitle =
    'الدرس الثاني: شرح مفصل لأحكام القانون المدني مع الأمثلة والتطبيقات '
    'العملية — Lesson two: a detailed walkthrough of civil law rules with '
    'examples and practice';
