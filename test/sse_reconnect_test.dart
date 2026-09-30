// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/models/notification_model.dart';
import 'package:wael_app/providers/notifications_provider.dart';
import 'package:wael_app/repositories/auth_repository.dart';
import 'package:wael_app/repositories/notification_repository.dart';
import 'package:wael_app/services/notification_stream.dart';

const runLive = bool.fromEnvironment('RUN_LIVE_TESTS', defaultValue: false);
const baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://localhost:18080',
);

void main() {
  test(
    'SSE reconnects after notification-service restart without crash or duplicate items',
    () async {
      final api = ApiClient(baseUrl: baseUrl, allowSelfSigned: true);
      final authRepo = HttpAuthRepository(api);

      // 1. Create and verify user
      final email =
          'sse_restart_${DateTime.now().millisecondsSinceEpoch}@example.com';
      print('Signing up user for SSE test: $email');
      final signup = await authRepo.signup(
        email: email,
        password: 'SecurePassword123!',
      );
      final tokens = await authRepo.verifyOtp(
        email: email,
        code: signup.devOtp!,
      );
      final accessToken = tokens.access;

      final notifProvider = NotificationsProvider(
        repository: const EmptyNotificationRepository(),
      );

      final stream = NotificationStream(api);
      final receivedItems = <NotificationModel>[];
      final completer1 = Completer<NotificationModel>();
      Completer<NotificationModel>? completer2;

      await stream.connect(
        token: accessToken,
        onItem: (item) {
          print(
            'Live SSE frame received: id=${item.id}, title="${item.title}"',
          );
          receivedItems.add(item);
          notifProvider.addNotification(item);
          if (!completer1.isCompleted) {
            completer1.complete(item);
          } else if (completer2 != null && !completer2.isCompleted) {
            completer2.complete(item);
          }
        },
      );

      print('SSE stream initiated. Stream active: ${stream.isActive}');
      await Future.delayed(const Duration(milliseconds: 500));

      // Trigger notification 1 (password reset)
      print('Triggering notification 1 via password reset...');
      final otp1 = await authRepo.requestReset(email: email);
      final resetToken1 = await authRepo.verifyResetCode(
        email: email,
        code: otp1!,
      );
      await authRepo.confirmReset(
        resetToken: resetToken1,
        newPassword: 'NewPassword123!',
      );

      final firstItem = await completer1.future.timeout(
        const Duration(seconds: 5),
      );
      print('Notification 1 received successfully: id=${firstItem.id}');
      expect(firstItem.title, contains('Password'));
      expect(notifProvider.notifications.length, 1);

      // Now restart notification-service
      print('Restarting notification-service via docker restart...');
      final restartResult = await Process.run('docker', [
        'restart',
        'wael-notification-service',
      ]);
      print(
        'docker restart exitCode=${restartResult.exitCode}, stdout=${restartResult.stdout.toString().trim()}',
      );

      // Prepare completer 2 for post-restart notification
      completer2 = Completer<NotificationModel>();

      // Wait for notification-service to become healthy again
      print(
        'Waiting 6 seconds for notification-service to restart and SSE client to backoff & reconnect...',
      );
      await Future.delayed(const Duration(seconds: 6));

      // Trigger notification 2 (password reset again)
      print('Triggering notification 2 after restart...');
      final otp2 = await authRepo.requestReset(email: email);
      final resetToken2 = await authRepo.verifyResetCode(
        email: email,
        code: otp2!,
      );
      await authRepo.confirmReset(
        resetToken: resetToken2,
        newPassword: 'AnotherPassword456!',
      );

      final secondItem = await completer2.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Timeout waiting for second notification after restart');
          throw TimeoutException(
            'Second notification not received after SSE reconnect',
          );
        },
      );

      print(
        'Notification 2 received successfully after reconnect: id=${secondItem.id}, title="${secondItem.title}"',
      );
      expect(secondItem.title, contains('Password'));

      // Check provider state and deduplication:
      print('Total items received by listener: ${receivedItems.length}');
      print(
        'Total items in NotificationsProvider: ${notifProvider.notifications.length}',
      );

      // Intentionally inject the first item again to verify deduplication
      notifProvider.addNotification(firstItem);
      print(
        'After re-adding first item, NotificationsProvider count: ${notifProvider.notifications.length}',
      );
      expect(notifProvider.notifications.length, 2);

      await stream.stop();
      api.dispose();
    },
    skip: !runLive
        ? 'Skipped in offline CI. Run with --dart-define=RUN_LIVE_TESTS=true'
        : null,
  );
}
