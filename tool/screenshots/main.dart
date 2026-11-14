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
//
// The last two shots are the iOS packages screen (`/packages`), for the App
// Store Connect review screenshots of the In-App Purchases. Prices are what
// StoreKit returns on the Simulator, never a value from Dart: the tour waits
// until IapProvider has loaded (or [_iapTimeout] passes), then prints one
// `WAEL_IAP:` line per known Product ID with StoreKit's answer, and a
// `WAEL_IAP_RESULT:` line saying whether all of them came back.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/notification_time.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/main.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/iap_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/providers/playback_speed_provider.dart';
import 'package:wael_app/screens/main_shell.dart';
import 'package:wael_app/screens/packages_screen.dart';
import 'package:wael_app/services/iap_store.dart';

const _email = String.fromEnvironment('SHOT_EMAIL');
const _password = String.fromEnvironment('SHOT_PASSWORD');
const _lang = String.fromEnvironment('SHOT_LANG', defaultValue: 'en');

/// Time for a screen's network content and images to arrive.
const _settle = Duration(seconds: 6);

/// Time the screen stays still while the host takes the screenshot.
const _hold = Duration(seconds: 4);

/// Longest wait for the package list and StoreKit's products.
const _iapTimeout = Duration(seconds: 45);

/// The App Store Connect Non-Renewing Subscriptions the review screenshots
/// are for. Only used to ask StoreKit and log its answer.
const _iapProductIds = {
  'com.wael.app.pkg.year1',
  'com.wael.app.pkg.year2',
  'com.wael.app.pkg.year3',
  'com.wael.app.pkg.year4',
};

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
      unawaited(_nav.pushNamed('/course-details', arguments: owned.first.id));
      await _shot('04_course_details');
      _nav.pop();
    }

    _openTab(2);
    await _shot('05_files');

    _openTab(3);
    await _shot('06_settings');

    unawaited(_nav.pushNamed('/notifications'));
    await _shot('07_notifications');

    await _packagesShots();

    await auth.logout();
    debugPrint('WAEL_SHOT_DONE');
  } catch (e) {
    debugPrint('WAEL_SHOT_FAIL:$e');
  }
}

/// 08_packages (top of the list) and 09_packages_bottom (scrolled to the
/// end, Restore Purchases visible), captured as rendered: when StoreKit
/// returns no product the cards show no price and no Buy button, and the
/// log says so.
Future<void> _packagesShots() async {
  await _logStoreKit();
  final iap = _read<IapProvider>();
  unawaited(_nav.pushNamed('/packages'));
  // The screen starts IapProvider.load() after its first frame.
  await Future<void>.delayed(const Duration(milliseconds: 500));
  final waited = Stopwatch()..start();
  while (iap.status == IapCatalogStatus.idle ||
      iap.status == IapCatalogStatus.loading) {
    if (waited.elapsed >= _iapTimeout) {
      debugPrint(
        'WAEL_SHOT_NOTE: packages still loading after '
        '${_iapTimeout.inSeconds}s; captured as rendered',
      );
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  _logPackages(iap);
  await _shot('08_packages');

  final scroll = _packagesScrollable();
  if (scroll == null) {
    debugPrint('WAEL_SHOT_NOTE: packages list not found; bottom shot as is');
  } else {
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
  }
  await _shot('09_packages_bottom');
  _nav.pop();
}

/// Asks StoreKit directly for every known Product ID, so the log shows what
/// the Simulator returns even when the server lists fewer packages.
Future<void> _logStoreKit() async {
  try {
    final store = StoreKitIapStore();
    final available = await store.isAvailable();
    debugPrint('WAEL_IAP: storekit available=$available');
    if (!available) {
      debugPrint('WAEL_IAP_RESULT: storekit unavailable (0/4)');
      return;
    }
    final products = await store.queryProducts(_iapProductIds);
    final byId = {for (final p in products) p.id: p};
    for (final id in _iapProductIds.toList()..sort()) {
      final p = byId[id];
      debugPrint(
        p == null
            ? 'WAEL_IAP: $id -> not returned'
            : 'WAEL_IAP: $id -> price="${p.price}" title="${p.title}"',
      );
    }
    final n = _iapProductIds.where(byId.containsKey).length;
    debugPrint(
      'WAEL_IAP_RESULT: storekit returned $n/${_iapProductIds.length}'
      '${n == _iapProductIds.length ? ' (all)' : ''}',
    );
  } on Exception catch (e) {
    debugPrint('WAEL_IAP_RESULT: storekit query failed: $e');
  }
}

/// What the packages screen shows: the server's packages and, for each,
/// StoreKit's display price (or none).
void _logPackages(IapProvider iap) {
  debugPrint(
    'WAEL_IAP: screen status=${iap.status.name} '
    'packages=${iap.packages.length}'
    '${iap.error == null ? '' : ' error=${iap.error!.code.name}'}',
  );
  for (final p in iap.packages) {
    final product = iap.productFor(p);
    debugPrint(
      'WAEL_IAP: screen ${p.productId} onSale=${p.onSale} '
      'price=${product == null ? 'none' : '"${product.price}"'}',
    );
  }
}

/// The vertical list inside the open PackagesScreen, found by walking the
/// element tree (the tour must not change lib/).
ScrollableState? _packagesScrollable() {
  ScrollableState? found;
  void inScreen(Element e) {
    if (found != null) return;
    if (e is StatefulElement &&
        e.state is ScrollableState &&
        (e.state as ScrollableState).position.axis == Axis.vertical) {
      found = e.state as ScrollableState;
      return;
    }
    e.visitChildElements(inScreen);
  }

  void findScreen(Element e) {
    if (found != null) return;
    if (e.widget is PackagesScreen) {
      e.visitChildElements(inScreen);
      return;
    }
    e.visitChildElements(findScreen);
  }

  final root = AuthProvider.navigatorKey.currentContext;
  if (root is Element) root.visitChildElements(findScreen);
  return found;
}
