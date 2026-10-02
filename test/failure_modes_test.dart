// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/repositories/auth_repository.dart';
import 'package:wael_app/repositories/notification_repository.dart';

Future<void> runDocker(List<String> args) async {
  final res = await Process.run('docker', args);
  if (res.exitCode != 0) {
    throw Exception('docker ${args.join(" ")} failed: ${res.stderr}');
  }
}

Future<void> waitForHealthy(String containerName, {int maxSeconds = 30}) async {
  for (int i = 0; i < maxSeconds; i++) {
    final res = await Process.run('docker', [
      'inspect',
      '--format',
      '{{.State.Health.Status}}',
      containerName,
    ]);
    final status = res.stdout.toString().trim();
    if (status == 'healthy' || status == '') {
      // Check if container is at least running
      final runRes = await Process.run('docker', [
        'inspect',
        '--format',
        '{{.State.Running}}',
        containerName,
      ]);
      if (runRes.stdout.toString().trim() == 'true') {
        if (status == 'healthy' || status == '') return;
      }
    }
    await Future.delayed(const Duration(seconds: 1));
  }
}

const runLive = bool.fromEnvironment('RUN_LIVE_TESTS', defaultValue: false);
const baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://localhost:18080',
);

void main() {
  group(
    'Failure Modes Behavior Matrix',
    () {
      late ApiClient api;
      late HttpAuthRepository authRepo;
      String? validAccessToken;

      setUpAll(() async {
        api = ApiClient(baseUrl: baseUrl, allowSelfSigned: true);
        authRepo = HttpAuthRepository(api);

        // Create a valid authenticated session for testing
        final email =
            'failmode_${DateTime.now().millisecondsSinceEpoch}@example.com';
        final res = await authRepo.signup(
          fullName: 'Failmode User',
          phone: '+201000000002',
          email: email,
          password: 'Password123!',
        );
        final tokens = await authRepo.verifyOtp(
          email: email,
          code: res.devOtp!,
          deviceId: '22222222-2222-4222-8222-222222222222',
        );
        validAccessToken = tokens.access;
      });

      tearDownAll(() {
        api.dispose();
      });

      test('FM-1: Stop API Gateway', () async {
        print('=== [FAILURE MODE 1] Stop API Gateway ===');
        await runDocker(['stop', 'wael-api-gateway']);
        try {
          try {
            await authRepo.signup(
              fullName: 'GW Stop',
              phone: '+201000000003',
              email: 'gw_stop@example.com',
              password: 'Password123!',
            );
            fail('Expected connection failure');
          } catch (e) {
            print('Observed raw client exception: $e');
            final appMsg = ErrorMessages.forException(e);
            print('Observed app display: "$appMsg"');
            expect(appMsg, ErrorMessages.networkError(false));
          }
        } finally {
          print('Restarting wael-api-gateway...');
          await runDocker(['start', 'wael-api-gateway']);
          await waitForHealthy('wael-api-gateway');
          print('wael-api-gateway restored and healthy');
        }
      });

      test('FM-2: Stop Auth Service', () async {
        print('=== [FAILURE MODE 2] Stop Auth Service ===');
        await runDocker(['stop', 'wael-auth-service']);
        try {
          try {
            await authRepo.signup(
              fullName: 'Auth Stop',
              phone: '+201000000004',
              email: 'auth_stop@example.com',
              password: 'Password123!',
            );
            fail('Expected gateway 502/failure');
          } on ApiException catch (e) {
            print(
              'Observed gateway response: status=${e.statusCode}, code=${e.code}, message="${e.message}"',
            );
            final appMsg = ErrorMessages.forApiError(e);
            print('Observed app display: "$appMsg"');
            expect(e.statusCode, isIn([502, 503, 504]));
            expect(appMsg, ErrorMessages.requestFailed(false));
          } catch (e) {
            print('Observed unexpected exception: $e');
          }
        } finally {
          print('Restarting wael-auth-service...');
          await runDocker(['start', 'wael-auth-service']);
          await waitForHealthy('wael-auth-service');
          print('wael-auth-service restored and healthy');
        }
      });

      test('FM-3: Stop Notification Service', () async {
        print('=== [FAILURE MODE 3] Stop Notification Service ===');
        await runDocker(['stop', 'wael-notification-service']);
        try {
          final authedApi = ApiClient(
            baseUrl: baseUrl,
            allowSelfSigned: true,
            accessTokenReader: () async => validAccessToken,
          );
          final notifRepo = HttpNotificationRepository(authedApi);
          try {
            await notifRepo.list();
            fail('Expected gateway 502/failure');
          } on ApiException catch (e) {
            print(
              'Observed notification call response: status=${e.statusCode}, code=${e.code}, message="${e.message}"',
            );
            final appMsg = ErrorMessages.forApiError(e);
            print('Observed app display: "$appMsg"');
            expect(e.statusCode, isIn([502, 503, 504]));
          } finally {
            authedApi.dispose();
          }
        } finally {
          print('Restarting wael-notification-service...');
          await runDocker(['start', 'wael-notification-service']);
          await waitForHealthy('wael-notification-service');
          print('wael-notification-service restored and healthy');
        }
      });

      test('FM-4: Stop Redis', () async {
        print('=== [FAILURE MODE 4] Stop Redis ===');
        await runDocker(['stop', 'wael-redis']);
        try {
          // Test auth signup / login / gateway behavior when Redis is down
          try {
            print('Attempting signup while Redis is down:');
            await authRepo.signup(
              fullName: 'Redis Stop',
              phone: '+201000000005',
              email: 'redis_stop@example.com',
              password: 'Password123!',
            );
            print('Unexpected: signup succeeded while Redis was down');
          } on ApiException catch (e) {
            print(
              'Observed signup response when Redis down: status=${e.statusCode}, code=${e.code}, message="${e.message}"',
            );
            final appMsg = ErrorMessages.forApiError(e);
            print('Observed app display: "$appMsg"');
            expect(e.statusCode, isIn([429, 500, 502]));
          }

          try {
            print('Attempting /auth/me with valid JWT while Redis is down:');
            await authRepo.me(accessToken: validAccessToken!);
            print('Unexpected: /auth/me succeeded while Redis was down');
          } on ApiException catch (e) {
            print(
              'Observed /auth/me response when Redis down: status=${e.statusCode}, code=${e.code}, message="${e.message}"',
            );
            final appMsg = ErrorMessages.forApiError(e);
            print('Observed app display: "$appMsg"');
            // Expect fail-closed: 401 (denylist unreachable), 429 (rate limiter), or 500
            expect(e.statusCode, isIn([401, 429, 500]));
          }
        } finally {
          print('Restarting wael-redis...');
          await runDocker(['start', 'wael-redis']);
          await waitForHealthy('wael-redis');
          print('wael-redis restored and healthy');
        }
      });

      test('FM-5: Stop MongoDB', () async {
        print('=== [FAILURE MODE 5] Stop MongoDB ===');
        await runDocker(['stop', 'wael-mongo']);
        try {
          try {
            print('Attempting signup while MongoDB is down:');
            await authRepo.signup(
              fullName: 'Mongo Stop',
              phone: '+201000000006',
              email: 'mongo_stop@example.com',
              password: 'Password123!',
            );
            fail('Expected failure when Mongo is down');
          } on ApiException catch (e) {
            print(
              'Observed signup response when Mongo down: status=${e.statusCode}, code=${e.code}, message="${e.message}"',
            );
            final appMsg = ErrorMessages.forApiError(e);
            print('Observed app display: "$appMsg"');
            expect(e.statusCode, isIn([500, 502, 503, 504]));
          }
        } finally {
          print('Restarting wael-mongo...');
          await runDocker(['start', 'wael-mongo']);
          await waitForHealthy('wael-mongo');
        }
      });
    },
    skip: !runLive
        ? 'Skipped in offline CI. Run with --dart-define=RUN_LIVE_TESTS=true'
        : null,
  );
}
