import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/locale_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/providers/settings_provider.dart';

import 'fakes.dart';
import 'widget_layer_harness.dart';

/// Names of the stub routes registered by [pumpScreen]. Each renders a Text
/// with the route name, so tests can assert where a screen navigated to.
const kStubRoutes = [
  '/splash',
  '/login',
  '/signup',
  '/otp',
  '/forgot',
  '/main',
  '/notifications',
  '/settings',
  '/ebooks',
  '/course-details',
  '/payment',
];

/// Pumps [screen] on a phone-sized view under [locale], with the app's
/// providers backed by fakes and stub routes for navigation targets.
///
/// Pass `settle: false` for screens with an indeterminate spinner and `size`
/// for a taller view when the content scrolls.
Future<void> pumpScreen(
  WidgetTester tester,
  Locale locale,
  Widget screen, {
  AuthProvider? auth,
  NotificationsProvider? notifications,
  SettingsProvider? settings,
  List<SingleChildWidget> extraProviders = const [],
  bool settle = true,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: auth ?? makeAuth()),
        ChangeNotifierProvider.value(
          value: notifications ?? NotificationsProvider(),
        ),
        ChangeNotifierProvider.value(value: settings ?? SettingsProvider()),
        ...extraProviders,
      ],
      child: localizedApp(
        locale,
        screen,
        routes: {
          for (final r in kStubRoutes)
            r: (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments;
              return Scaffold(
                body: Text(args == null ? 'route:$r' : 'route:$r:$args'),
              );
            },
        },
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

AuthProvider makeAuth({
  FakeAuthRepository? repository,
  MemoryTokenStore? tokens,
}) => AuthProvider(
  repository: repository ?? FakeAuthRepository(),
  tokenStore: tokens ?? MemoryTokenStore(),
);

/// Left/right position helper: true when [a] is laid out before [b] in the
/// reading direction of [direction].
bool startsBefore(
  WidgetTester tester,
  Finder a,
  Finder b,
  TextDirection direction,
) {
  final ax = tester.getCenter(a).dx;
  final bx = tester.getCenter(b).dx;
  return direction == TextDirection.ltr ? ax < bx : ax > bx;
}
