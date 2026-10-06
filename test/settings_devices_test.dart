import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/providers/account_provider.dart';
import 'package:wael_app/repositories/account_repository.dart';
import 'package:wael_app/screens/settings/devices_screen.dart';
import 'package:wael_app/screens/settings_screen.dart';
import 'package:wael_app/widgets/confirm_action_dialog.dart';

import 'account_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

const _tall = Size(390, 1800);

DeviceSession session(
  String sid, {
  String label = 'My phone',
  bool current = false,
  DateTime? lastUsed,
}) => DeviceSession(
  sid: sid,
  deviceLabel: label,
  createdAt: DateTime.utc(2026, 9, 1),
  lastUsedAt:
      lastUsed ?? DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
  current: current,
);

Future<AccountProvider> accountsWith(
  FakeAccountRepository repo,
  Locale locale,
) async => AccountProvider(
  auth: await signedInAuth(),
  repository: repo,
  localeReader: () => locale.languageCode,
);

void main() {
  for (final (name, locale, _) in kLocales) {
    final l10n = l10nFor(locale);

    group('Devices [$name]', () {
      test('relative time renders per scale', () {
        expect(relativeLastUsed(l10n, DateTime.now().toUtc()), l10n.justNow);
        expect(
          relativeLastUsed(
            l10n,
            DateTime.now().toUtc().subtract(const Duration(minutes: 7)),
          ),
          l10n.minutesAgo(7),
        );
        expect(
          relativeLastUsed(
            l10n,
            DateTime.now().toUtc().subtract(const Duration(hours: 3)),
          ),
          l10n.hoursAgo(3),
        );
        expect(
          relativeLastUsed(
            l10n,
            DateTime.now().toUtc().subtract(const Duration(days: 2)),
          ),
          l10n.daysAgo(2),
        );
      });

      testWidgets('tile opens the device list', (tester) async {
        final repo = FakeAccountRepository()
          ..sessionList.addAll([
            session('sid-current', current: true),
            session(
              'sid-old',
              label: 'Old tablet',
              lastUsed: DateTime.now().toUtc().subtract(
                const Duration(hours: 2),
              ),
            ),
          ]);
        await pumpScreen(
          tester,
          locale,
          const SettingsScreen(),
          accounts: await accountsWith(repo, locale),
          size: _tall,
        );
        await tester.tap(find.text(l10n.myDevices).last);
        await tester.pumpAndSettle();
        expect(find.byType(DevicesScreen), findsOneWidget);
        expect(find.text('My phone'), findsOneWidget);
        expect(find.text('Old tablet'), findsOneWidget);
        expect(find.text(l10n.thisDevice), findsOneWidget);
        expect(find.text(l10n.minutesAgo(5)), findsOneWidget);
        expect(find.text(l10n.deviceLimitNote), findsOneWidget);
      });

      testWidgets('signing out asks, ends, and reloads', (tester) async {
        final repo = FakeAccountRepository()
          ..sessionList.addAll([
            session('sid-current', current: true),
            session('sid-old', label: 'Old tablet'),
          ]);
        await pumpScreen(
          tester,
          locale,
          const DevicesScreen(),
          accounts: await accountsWith(repo, locale),
          size: _tall,
        );
        await tester.tap(find.text(l10n.signOutDevice));
        await tester.pumpAndSettle();
        expect(find.byType(ConfirmActionDialog), findsOneWidget);
        await tester.tap(find.text(l10n.confirm));
        await tester.pump();
        await tester.pump();
        expect(repo.deletedSids, ['sid-old']);
        expect(find.text(l10n.deviceSignedOut), findsOneWidget);
        await tester.pumpAndSettle();
      });

      testWidgets('cancel keeps the session', (tester) async {
        final repo = FakeAccountRepository()
          ..sessionList.addAll([session('sid-old', label: 'Old tablet')]);
        await pumpScreen(
          tester,
          locale,
          const DevicesScreen(),
          accounts: await accountsWith(repo, locale),
          size: _tall,
        );
        await tester.tap(find.text(l10n.signOutDevice));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        expect(repo.deletedSids, isEmpty);
        expect(find.byType(DevicesScreen), findsOneWidget);
      });

      testWidgets('a gone session shows a clear message', (tester) async {
        final repo = FakeAccountRepository()
          ..sessionList.addAll([session('sid-old', label: 'Old tablet')])
          ..deleteSessionError = ApiException(
            statusCode: 404,
            message: 'session not found',
            code: 'not_found',
          );
        await pumpScreen(
          tester,
          locale,
          const DevicesScreen(),
          accounts: await accountsWith(repo, locale),
          size: _tall,
        );
        await tester.tap(find.text(l10n.signOutDevice));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.confirm));
        await tester.pumpAndSettle();
        expect(
          find.text(ErrorMessages.sessionNotFound(l10n.isArabic)),
          findsOneWidget,
        );
      });

      testWidgets('401 on list shows an error with retry', (tester) async {
        final repo = FakeAccountRepository()
          ..sessionsError = ApiException(
            statusCode: 401,
            message: 'invalid credentials',
          );
        await pumpScreen(
          tester,
          locale,
          const DevicesScreen(),
          accounts: await accountsWith(repo, locale),
          size: _tall,
        );
        expect(
          find.text(ErrorMessages.invalidCredentials(l10n.isArabic)),
          findsOneWidget,
        );
        repo.sessionsError = null;
        repo.sessionList.add(session('sid-current', current: true));
        await tester.tap(find.text(l10n.retry));
        await tester.pumpAndSettle();
        expect(find.text('My phone'), findsOneWidget);
      });
    });
  }
}
