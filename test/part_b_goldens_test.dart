import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/account_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/repositories/account_repository.dart';
import 'package:wael_app/screens/login_screen.dart';
import 'package:wael_app/screens/settings/delete_account_screen.dart';
import 'package:wael_app/screens/settings/devices_screen.dart';
import 'package:wael_app/screens/settings/email_change_screen.dart';
import 'package:wael_app/screens/settings/password_change_screen.dart';
import 'package:wael_app/screens/settings_screen.dart';
import 'package:wael_app/screens/update_gate_screen.dart';

import 'academy_fakes.dart';
import 'account_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

Future<void> pumpScreenForGolden(
  WidgetTester tester,
  Widget screen, {
  AuthProvider? auth,
  AcademyCatalogProvider? catalog,
  AppConfigProvider? appConfig,
  AccountProvider? accounts,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final authProvider = auth ?? makeAuth();
  final accountProvider =
      accounts ??
      AccountProvider(
        auth: authProvider,
        repository: FakeAccountRepository(),
        localeReader: () => 'ar',
      );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: NotificationsProvider()),
        ChangeNotifierProvider.value(
          value: catalog ?? AcademyCatalogProvider(fake()),
        ),
        ChangeNotifierProvider.value(value: HomeProvider()),
        ChangeNotifierProvider.value(
          value:
              appConfig ??
              (AppConfigProvider(cache: MemoryAppConfigCache())..setForTesting(
                const AppConfigData(
                  termsUrl: 'https://legal.elmetracademy.app/terms',
                  privacyUrl: 'https://legal.elmetracademy.app/privacy',
                  supportWhatsappUrl: 'https://wa.me/201000000000',
                ),
              )),
        ),
        ChangeNotifierProvider.value(value: accountProvider),
      ],
      child: localizedApp(const Locale('ar'), screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('golden: login with support contact', (tester) async {
    final auth = makeAuth();
    await auth.handleSessionReplaced();

    await pumpScreenForGolden(
      tester,
      const LoginScreen(),
      auth: auth,
      appConfig: AppConfigProvider(cache: MemoryAppConfigCache())
        ..setForTesting(
          const AppConfigData(supportWhatsappUrl: 'https://wa.me/201000000000'),
        ),
    );
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/part_b_login_support.png'),
    );
  });

  testWidgets('golden: settings with about update row and help', (
    tester,
  ) async {
    final auth = await signedInAuth();
    final appConfig =
        AppConfigProvider(
          cache: MemoryAppConfigCache(),
          versionReader: () async => '1.0.0',
        )..setForTesting(
          const AppConfigData(
            termsUrl: 'https://legal.elmetracademy.app/terms',
            privacyUrl: 'https://legal.elmetracademy.app/privacy',
            supportWhatsappUrl: 'https://wa.me/201000000000',
            latestVersion: '2.0.0',
            updateUrl: 'https://elmetracademy.app/download',
          ),
        );

    await pumpScreenForGolden(
      tester,
      const SettingsScreen(),
      auth: auth,
      appConfig: appConfig,
      size: const Size(390, 1400),
    );
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/part_b_settings_full.png'),
    );
  });

  testWidgets('golden: email change screen', (tester) async {
    final auth = await signedInAuth();
    await pumpScreenForGolden(tester, const EmailChangeScreen(), auth: auth);
    await expectLater(
      find.byType(EmailChangeScreen),
      matchesGoldenFile('goldens/part_b_email_change.png'),
    );
  });

  testWidgets('golden: password change screen', (tester) async {
    final auth = await signedInAuth();
    await pumpScreenForGolden(tester, const PasswordChangeScreen(), auth: auth);
    await expectLater(
      find.byType(PasswordChangeScreen),
      matchesGoldenFile('goldens/part_b_password_change.png'),
    );
  });

  testWidgets('golden: devices screen', (tester) async {
    final auth = await signedInAuth();
    final repo = FakeAccountRepository()
      ..sessionList.addAll([
        DeviceSession(
          sid: 's1',
          deviceLabel: 'Chrome على Android',
          current: true,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          lastUsedAt: DateTime.now(),
        ),
        DeviceSession(
          sid: 's2',
          deviceLabel: 'Safari على iPhone',
          current: false,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          lastUsedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ]);
    final accounts = AccountProvider(
      auth: auth,
      repository: repo,
      localeReader: () => 'ar',
    );

    await pumpScreenForGolden(
      tester,
      const DevicesScreen(),
      auth: auth,
      accounts: accounts,
    );
    await expectLater(
      find.byType(DevicesScreen),
      matchesGoldenFile('goldens/part_b_devices.png'),
    );
  });

  testWidgets('golden: delete account screen', (tester) async {
    final auth = await signedInAuth();
    final catalogRepo = fake();
    catalogRepo.subjectsByLevel['bachelor-y1'] = [
      subject(
        's9',
        'bachelor-y1',
        en: 'Civil Law',
        ar: 'القانون المدني',
        owned: true,
      ),
    ];
    final catalog = AcademyCatalogProvider(catalogRepo);
    await catalog.reload();

    await pumpScreenForGolden(
      tester,
      const DeleteAccountScreen(),
      auth: auth,
      catalog: catalog,
      size: const Size(390, 1000),
    );
    await expectLater(
      find.byType(DeleteAccountScreen),
      matchesGoldenFile('goldens/part_b_delete_account.png'),
    );
  });

  testWidgets('golden: update gate screen', (tester) async {
    final appConfig = AppConfigProvider(cache: MemoryAppConfigCache())
      ..setForTesting(
        const AppConfigData(
          minVersion: '2.0.0',
          updateUrl: 'https://elmetracademy.app/download',
        ),
      );

    await pumpScreenForGolden(
      tester,
      const UpdateGateScreen(),
      appConfig: appConfig,
    );
    await expectLater(
      find.byType(UpdateGateScreen),
      matchesGoldenFile('goldens/part_b_update_gate.png'),
    );
  });
}
