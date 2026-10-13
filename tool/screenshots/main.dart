// App Store screenshot tour. NOT part of the shipped app: lib/ never imports
// it, and only .github/workflows/screenshots-ios.yml builds it, with
// `flutter run -t tool/screenshots/main.dart` on an iOS Simulator.
//
// It starts the real app against the production API (API_BASE_URL), shows
// the login screen, signs in with the store demo account (SHOT_EMAIL,
// SHOT_PASSWORD), walks the main screens and signs out (the account keeps
// its 2-device cap free). Before each screen it waits for the content to
// load, then prints `WAEL_SHOT:<lang>:<name>` and holds still while
// tool/screenshots/capture_ios.sh takes a Simulator screenshot (real status
// bar, native resolution). It prints `WAEL_SHOT_DONE` at the end or
// `WAEL_SHOT_FAIL:<reason>` on any error; it never prints the credentials.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/notification_time.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/main.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/providers/playback_speed_provider.dart';
import 'package:wael_app/screens/main_shell.dart';

const _email = String.fromEnvironment('SHOT_EMAIL');
const _password = String.fromEnvironment('SHOT_PASSWORD');
const _lang = String.fromEnvironment('SHOT_LANG', defaultValue: 'en');

/// Time for a screen's network content and images to arrive.
const _settle = Duration(seconds: 6);

/// Time the screen stays still while the host takes the screenshot.
const _hold = Duration(seconds: 4);

Future<void> main() async {
  // Same start-up as lib/main.dart, plus a fixed language.
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final tokenStore = SecureTokenStore();
  final localeProvider = LocaleProvider(store: tokenStore);
  await localeProvider.load();
  localeProvider.setLocale(const Locale(_lang));
  final speedProvider = PlaybackSpeedProvider(store: tokenStore);
  await speedProvider.load();
  await ensureNotificationTimeInitialized();
  runApp(
    WaelApp(
      localeProvider: localeProvider,
      tokenStore: tokenStore,
      speedProvider: speedProvider,
    ),
  );
  unawaited(_tour());
}

NavigatorState get _nav => AuthProvider.navigatorKey.currentState!;

/// A provider from the app's tree. A plain function with no async gap, so the
/// tour never holds a BuildContext across an await.
T _read<T>() => AuthProvider.navigatorKey.currentContext!.read<T>();

Future<void> _shot(String name) async {
  await Future<void>.delayed(_settle);
  debugPrint('WAEL_SHOT:$_lang:$name');
  await Future<void>.delayed(_hold);
}

/// Opens the main shell on [tab] (0 home, 1 courses, 2 files, 3 settings)
/// with no transition, as if the tab had been tapped.
void _openTab(int tab) {
  _nav.pushAndRemoveUntil(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/main'),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          MainShell(initialTab: tab),
    ),
    (route) => false,
  );
}

Future<void> _tour() async {
  try {
    if (_email.isEmpty || _password.isEmpty) {
      throw StateError('SHOT_EMAIL and SHOT_PASSWORD are required');
    }
    if (_lang != 'ar' && _lang != 'en') {
      throw StateError('SHOT_LANG must be ar or en');
    }
    // Splash restores no session on a fresh install and lands on login.
    await Future<void>.delayed(_settle);
    final auth = _read<AuthProvider>();
    if (auth.isAuthenticated) {
      await auth.logout();
      unawaited(_nav.pushNamedAndRemoveUntil('/login', (route) => false));
    }
    await _shot('01_login');

    final ok = await auth.login(
      _email,
      _password,
      deviceLabel: 'Store screenshots',
    );
    if (!ok) {
      throw StateError('login failed: ${auth.errorMessage ?? 'unknown'}');
    }
    _openTab(0);
    final catalog = _read<AcademyCatalogProvider>();
    await catalog.ensureLoaded();
    await _shot('02_home');

    _openTab(1);
    await _shot('03_courses');

    final owned = catalog.ownedSubjects;
    if (owned.isEmpty) {
      debugPrint('WAEL_SHOT_NOTE: the demo account owns no subject');
    } else {
      unawaited(
        _nav.pushNamed('/course-details', arguments: owned.first.id),
      );
      await _shot('04_course_details');
      _nav.pop();
    }

    _openTab(2);
    await _shot('05_files');

    _openTab(3);
    await _shot('06_settings');

    unawaited(_nav.pushNamed('/notifications'));
    await _shot('07_notifications');

    await auth.logout();
    debugPrint('WAEL_SHOT_DONE');
  } catch (e) {
    debugPrint('WAEL_SHOT_FAIL:$e');
  }
}
