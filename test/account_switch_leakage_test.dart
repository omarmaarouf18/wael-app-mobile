import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/catalog_cache.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/models/notification_model.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/account_provider.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';

import 'academy_fakes.dart';
import 'fakes.dart';

void main() {
  group('Account switch leakage prevention', () {
    test('AuthProvider logout clears catalog cache', () async {
      final cache = MemoryCatalogCache();
      await cache.write(
        CatalogSnapshot(
          levelsJson: {'levels': []},
          subjectsJson: const {},
          savedAt: DateTime.now(),
        ),
      );
      expect(await cache.read(), isNotNull);

      final auth = AuthProvider(
        repository: FakeAuthRepository(),
        tokenStore: MemoryTokenStore(),
        catalogCache: cache,
      );
      await auth.login('u@e.com', 'pass');
      await auth.logout();

      expect(await cache.read(), isNull);
    });

    testWidgets('ProxyProviders reset on unauthenticated state transition', (
      tester,
    ) async {
      final auth = AuthProvider(
        repository: FakeAuthRepository(),
        tokenStore: MemoryTokenStore(),
        catalogCache: MemoryCatalogCache(),
      );
      await auth.login('u@e.com', 'pass');

      late NotificationsProvider notifs;
      late AcademyCatalogProvider catalog;
      late AccountProvider accounts;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProxyProvider<AuthProvider, AccountProvider>(
              create: (_) => AccountProvider(auth: auth),
              update: (_, a, acc) {
                if (!a.isAuthenticated) acc!.reset();
                return acc!;
              },
            ),
            ChangeNotifierProxyProvider<AuthProvider, AcademyCatalogProvider>(
              create: (_) => AcademyCatalogProvider(
                FakeAcademyRepository(levelList: []),
                cache: MemoryCatalogCache(),
              ),
              update: (_, a, cat) {
                if (!a.isAuthenticated) cat!.reset(notify: false);
                return cat!;
              },
            ),
            ChangeNotifierProxyProvider<AuthProvider, NotificationsProvider>(
              create: (_) => NotificationsProvider(),
              update: (_, a, n) {
                if (!a.isAuthenticated) n!.reset(notify: false);
                return n!;
              },
            ),
          ],
          child: Builder(
            builder: (ctx) {
              notifs = ctx.watch<NotificationsProvider>();
              catalog = ctx.watch<AcademyCatalogProvider>();
              accounts = ctx.watch<AccountProvider>();
              return const SizedBox();
            },
          ),
        ),
      );

      notifs.addNotification(
        const NotificationModel(
          id: 'n1',
          title: 'A Notification',
          titleAr: 'تنبيه',
          body: 'B',
          bodyAr: 'م',
          timestamp: 'now',
          timestampAr: 'الآن',
          isRead: false,
          type: 'system',
        ),
      );
      expect(notifs.notifications, isNotEmpty);

      // User A signs out
      await auth.logout();
      await tester.pumpAndSettle();

      // State is completely reset
      expect(notifs.notifications, isEmpty);
      expect(catalog.isPristine, isTrue);
      expect(accounts.errorMessage, isNull);
    });
  });
}
