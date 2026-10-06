import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/screens/courses_screen.dart';
import 'package:wael_app/screens/login_screen.dart';
import 'package:wael_app/screens/settings_screen.dart';

import 'academy_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

/// Before/after screenshots for the F-UX4 contrast and tap-target work
/// (see the report). Pumped at 390x844 in English; golden files live in
/// `test/goldens/` (`before_*` captured on the pre-change tree).
Future<void> pumpGolden(
  WidgetTester tester,
  Widget screen, {
  AuthProvider? auth,
  AcademyCatalogProvider? catalog,
  AppConfigProvider? appConfig,
}) async {
  const size = Size(390, 844);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: auth ?? makeAuth()),
        ChangeNotifierProvider.value(value: NotificationsProvider()),
        ChangeNotifierProvider.value(
          value: catalog ?? AcademyCatalogProvider(fake()),
        ),
        ChangeNotifierProvider.value(value: HomeProvider()),
        ChangeNotifierProvider.value(
          value:
              appConfig ??
              (AppConfigProvider()..setForTesting(
                const AppConfigData(
                  termsUrl: 'https://legal.elmetracademy.app/terms',
                  privacyUrl: 'https://legal.elmetracademy.app/privacy',
                ),
              )),
        ),
      ],
      child: localizedApp(const Locale('en'), screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('golden: login', (tester) async {
    await pumpGolden(tester, const LoginScreen());
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/after_login.png'),
    );
  });

  testWidgets('golden: courses', (tester) async {
    final catalog = AcademyCatalogProvider(fake());
    await catalog.reload();
    await pumpGolden(tester, const CoursesScreen(), catalog: catalog);
    await expectLater(
      find.byType(CoursesScreen),
      matchesGoldenFile('goldens/after_courses.png'),
    );
  });

  testWidgets('golden: settings', (tester) async {
    await pumpGolden(
      tester,
      const SettingsScreen(),
      auth: await signedInAuth(),
    );
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/after_settings.png'),
    );
  });
}
