import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/models/notification_model.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/screens/main_shell.dart';
import 'package:wael_app/widgets/app_bottom_nav.dart';
import 'package:wael_app/widgets/app_shell.dart';
import 'package:wael_app/widgets/brand_lockup.dart';
import 'package:wael_app/widgets/header_icon_button.dart';
import 'package:wael_app/widgets/status_dot.dart';

import 'academy_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

void main() {
  for (final (name, locale, direction) in kLocales) {
    final l10n = l10nFor(locale);
    String upper(String s) => s.toUpperCase();

    Future<void> pump(
      WidgetTester tester, {
      int initialTab = 0,
      Size size = const Size(390, 844),
      NotificationsProvider? notifications,
    }) => pumpScreen(
      tester,
      locale,
      MainShell(initialTab: initialTab),
      notifications: notifications,
      extraProviders: [
        ChangeNotifierProvider(create: (_) => AcademyCatalogProvider(fake())),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
      ],
      size: size,
    );

    int tabIndex(WidgetTester tester) =>
        tester.widget<IndexedStack>(find.byType(IndexedStack).first).index!;

    final navLabels = [
      l10n.navHome,
      l10n.navCourses,
      l10n.navNotes,
      l10n.navSettings,
    ];

    group('MainShell [$name]', () {
      testWidgets('header, brand lockup and four localised tabs', (
        tester,
      ) async {
        await pump(tester);
        expect(find.byType(AppShell), findsAtLeastNWidgets(1));
        expect(find.byType(BrandLockup), findsOneWidget);
        expect(find.text('EL METR'), findsOneWidget);
        expect(find.byType(AppBottomNav), findsOneWidget);
        for (final label in navLabels) {
          expect(
            find.descendant(
              of: find.byType(AppBottomNav),
              matching: find.text(upper(label)),
            ),
            findsOneWidget,
          );
        }
        expect(tabIndex(tester), 0);
      });

      testWidgets('header mirrors: brand at the start, actions at the end', (
        tester,
      ) async {
        await pump(tester);
        final brand = find.byType(BrandLockup);
        final notifications = find.byKey(
          const ValueKey('top_bar_notifications_button'),
        );
        final profile = find.byIcon(Icons.person_outline);
        expect(startsBefore(tester, brand, notifications, direction), isTrue);
        expect(startsBefore(tester, notifications, profile, direction), isTrue);
        final width = 390.0;
        if (direction == TextDirection.ltr) {
          expect(tester.getTopLeft(brand).dx, lessThan(40));
          expect(tester.getTopRight(profile).dx, greaterThan(width - 40));
        } else {
          expect(tester.getTopRight(brand).dx, greaterThan(width - 40));
          expect(tester.getTopLeft(profile).dx, lessThan(40));
        }
      });

      testWidgets('notification pip sits at the end corner of its button', (
        tester,
      ) async {
        await pump(tester, notifications: _withUnread());
        final button = find.byKey(
          const ValueKey('top_bar_notifications_button'),
        );
        final pip = find.descendant(
          of: button,
          matching: find.byType(StatusDot),
        );
        final centre = tester.getCenter(button).dx;
        final pipX = tester.getCenter(pip).dx;
        if (direction == TextDirection.ltr) {
          expect(pipX, greaterThan(centre));
        } else {
          expect(pipX, lessThan(centre));
        }
      });

      testWidgets('the notification pip is hidden while nothing is unread', (
        tester,
      ) async {
        await pump(tester);
        final button = find.byKey(
          const ValueKey('top_bar_notifications_button'),
        );
        expect(button, findsOneWidget);
        expect(
          find.descendant(of: button, matching: find.byType(StatusDot)),
          findsNothing,
        );
      });

      testWidgets('the pip follows the unread count', (tester) async {
        final notifications = _withUnread();
        await pump(tester, notifications: notifications);
        final pip = find.descendant(
          of: find.byKey(const ValueKey('top_bar_notifications_button')),
          matching: find.byType(StatusDot),
        );
        expect(pip, findsOneWidget);
        notifications.markAllAsRead();
        await tester.pump();
        expect(pip, findsNothing);
      });

      testWidgets('bottom nav order mirrors', (tester) async {
        await pump(tester);
        Finder label(String s) => find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text(upper(s)),
        );
        expect(
          startsBefore(
            tester,
            label(l10n.navHome),
            label(l10n.navCourses),
            direction,
          ),
          isTrue,
        );
        expect(
          startsBefore(
            tester,
            label(l10n.navCourses),
            label(l10n.navNotes),
            direction,
          ),
          isTrue,
        );
        expect(
          startsBefore(
            tester,
            label(l10n.navNotes),
            label(l10n.navSettings),
            direction,
          ),
          isTrue,
        );
      });

      testWidgets('tapping tabs switches the stack', (tester) async {
        // Wider than a phone: the catalog Courses tab overflows a row by 22px
        // at 390px in Arabic (courses_screen.dart:390, not part of this task).
        await pump(tester, size: const Size(600, 844));
        for (final (i, label) in navLabels.indexed) {
          await tester.tap(
            find.descendant(
              of: find.byType(AppBottomNav),
              matching: find.text(upper(label)),
            ),
          );
          await tester.pump();
          expect(tabIndex(tester), i);
        }
      });

      testWidgets('initialTab is honoured', (tester) async {
        await pump(tester, initialTab: 2);
        expect(tabIndex(tester), 2);
      });

      testWidgets('profile button opens the settings tab', (tester) async {
        await pump(tester);
        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pump();
        expect(tabIndex(tester), 3);
      });

      testWidgets('notifications button pushes /notifications', (tester) async {
        await pump(tester);
        await tester.tap(
          find.byKey(const ValueKey('top_bar_notifications_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('route:/notifications'), findsOneWidget);
      });
    });
  }

  test('HeaderIconButton shows a pip only when asked', () {
    const withPip = HeaderIconButton(
      icon: Icons.add,
      onTap: _noop,
      showPip: true,
    );
    const without = HeaderIconButton(icon: Icons.add, onTap: _noop);
    expect(withPip.showPip, isTrue);
    expect(without.showPip, isFalse);
  });
}

void _noop() {}

NotificationsProvider _withUnread() => NotificationsProvider()
  ..addNotification(
    const NotificationModel(
      id: 'u1',
      title: 'Unread',
      body: 'b',
      timestamp: 'now',
      type: 'system',
    ),
  );
