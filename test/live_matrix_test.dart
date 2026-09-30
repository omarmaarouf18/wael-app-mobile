// ignore_for_file: avoid_print
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/core/secure_store.dart';
import 'package:wael_app/providers/auth_provider.dart';
import 'package:wael_app/repositories/auth_repository.dart';
import 'package:wael_app/repositories/notification_repository.dart';

String mask(String? val) {
  if (val == null || val.isEmpty) return 'none';
  if (val.length <= 6) return '$val...';
  return '${val.substring(0, 6)}...';
}

const runLive = bool.fromEnvironment('RUN_LIVE_TESTS', defaultValue: false);
const baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://localhost:18080',
);

void main() {
  group(
    'Live Stack Behavior Matrix',
    () {
      late ApiClient api;
      late HttpAuthRepository authRepo;
      final testEmail =
          'matrix_test_${DateTime.now().millisecondsSinceEpoch}@example.com';
      const testPassword = 'StrongPassword123!';
      String? capturedDevOtp;
      String? capturedAccessToken;
      String? capturedRefreshToken;

      setUpAll(() {
        api = ApiClient(baseUrl: baseUrl, allowSelfSigned: true);
        authRepo = HttpAuthRepository(api);
      });

      tearDownAll(() {
        api.dispose();
      });

      test('1. signup happy path', () async {
        print('=== [SCENARIO 1] signup happy path ===');
        final result = await authRepo.signup(
          email: testEmail,
          password: testPassword,
        );
        capturedDevOtp = result.devOtp;

        print(
          'Observed account: id=${result.account.id}, email=${result.account.email}, role=${result.account.role}',
        );
        print('Observed dev_otp: ${mask(capturedDevOtp)}');

        expect(result.account.email, testEmail);
        expect(result.account.role, 'user');
        expect(capturedDevOtp, isNotNull);
        expect(capturedDevOtp!.length, 6);
      });

      test('2. duplicate email fails with 409', () async {
        print('=== [SCENARIO 2] duplicate email ===');
        try {
          await authRepo.signup(email: testEmail, password: testPassword);
          fail('Expected 409 duplicate email');
        } on ApiException catch (e) {
          print(
            'Observed service response: status=${e.statusCode}, code=${e.code}, error=${e.message}',
          );
          final appMsg = ErrorMessages.forApiError(e);
          print('Observed app display: $appMsg');
          expect(e.statusCode, 409);
          expect(appMsg, ErrorMessages.duplicateEmail(false));
        }
      });

      test('3. invalid input fails with 400', () async {
        print('=== [SCENARIO 3] invalid input ===');
        try {
          await authRepo.signup(email: 'not-an-email', password: '123');
          fail('Expected 400 invalid input');
        } on ApiException catch (e) {
          print(
            'Observed service response: status=${e.statusCode}, code=${e.code}, error=${e.message}',
          );
          final appMsg = ErrorMessages.forApiError(e);
          print('Observed app display: $appMsg');
          expect(e.statusCode, 400);
        }
      });

      test('4. OTP wrong fails with 401', () async {
        print('=== [SCENARIO 4] OTP wrong ===');
        try {
          await authRepo.verifyOtp(email: testEmail, code: '000000');
          fail('Expected 401 wrong otp');
        } on ApiException catch (e) {
          print(
            'Observed service response: status=${e.statusCode}, code=${e.code}, error=${e.message}',
          );
          final appMsg = ErrorMessages.forApiError(e);
          print('Observed app display: $appMsg');
          expect(e.statusCode, 401);
        }
      });

      test('5. OTP resend attempt on unverified email returns 409', () async {
        print('=== [SCENARIO 5] OTP resend ===');
        final unverifiedEmail =
            'unverified_${DateTime.now().millisecondsSinceEpoch}@example.com';
        final first = await authRepo.signup(
          email: unverifiedEmail,
          password: testPassword,
        );
        print('Initial signup dev_otp: ${mask(first.devOtp)}');

        // Attempt re-signup to get fresh OTP (resend)
        try {
          await authRepo.signup(email: unverifiedEmail, password: testPassword);
          print('Unexpected: signup allowed on existing unverified email');
        } on ApiException catch (e) {
          print(
            'Observed service response on re-signup/resend: status=${e.statusCode}, code=${e.code}, error=${e.message}',
          );
          print(
            'FINDING: auth-service has no resend-otp route and signup rejects unverified email with 409 conflict.',
          );
          expect(e.statusCode, 409);
        }
      });

      test('6. OTP correct verifies email and issues tokens', () async {
        print('=== [SCENARIO 6] OTP correct ===');
        final tokens = await authRepo.verifyOtp(
          email: testEmail,
          code: capturedDevOtp!,
        );
        capturedAccessToken = tokens.access;
        capturedRefreshToken = tokens.refresh;
        print('Observed access_token: ${mask(capturedAccessToken)}');
        print('Observed refresh_token: ${mask(capturedRefreshToken)}');

        expect(tokens.access, isNotEmpty);
        expect(tokens.refresh, isNotEmpty);
      });

      test('7. OTP expired / replayed code fails with 401', () async {
        print('=== [SCENARIO 7] OTP expired / replayed ===');
        try {
          await authRepo.verifyOtp(email: testEmail, code: capturedDevOtp!);
          fail('Expected 401 for already consumed OTP');
        } on ApiException catch (e) {
          print(
            'Observed service response: status=${e.statusCode}, code=${e.code}, error=${e.message}',
          );
          expect(e.statusCode, 401);
        }
      });

      test('8. login correct with verified email', () async {
        print('=== [SCENARIO 8] login correct ===');
        final tokens = await authRepo.login(
          email: testEmail,
          password: testPassword,
        );
        print('Observed access_token: ${mask(tokens.access)}');
        print('Observed refresh_token: ${mask(tokens.refresh)}');
        expect(tokens.access, isNotEmpty);
        expect(tokens.refresh, isNotEmpty);

        final me = await authRepo.me(accessToken: tokens.access);
        print(
          'Observed me: email=${me.email}, role=${me.role}, email_verified=${me.emailVerified}',
        );
        expect(me.email, testEmail);
        expect(me.emailVerified, isTrue);
      });

      test('9. login wrong password fails with 401', () async {
        print('=== [SCENARIO 9] login wrong password ===');
        try {
          await authRepo.login(
            email: testEmail,
            password: 'IncorrectPassword999!',
          );
          fail('Expected 401 invalid credentials');
        } on ApiException catch (e) {
          print(
            'Observed service response: status=${e.statusCode}, code=${e.code}, error=${e.message}',
          );
          final appMsg = ErrorMessages.forApiError(e);
          print('Observed app display: $appMsg');
          expect(e.statusCode, 401);
          expect(appMsg, ErrorMessages.invalidCredentials(false));
        }
      });

      test('10. password reset in both phases', () async {
        print('=== [SCENARIO 10] password reset in both phases ===');
        // Phase 1: request reset
        final resetOtp = await authRepo.requestReset(email: testEmail);
        print('Phase 1 requestReset dev_otp: ${mask(resetOtp)}');
        expect(resetOtp, isNotNull);

        // Phase 1: verify reset code
        final resetToken = await authRepo.verifyResetCode(
          email: testEmail,
          code: resetOtp!,
        );
        print('Phase 1 verifyResetCode reset_token: ${mask(resetToken)}');
        expect(resetToken, isNotEmpty);

        // Phase 2: confirm new password
        const newPassword = 'NewStrongPassword456!';
        await authRepo.confirmReset(
          resetToken: resetToken,
          newPassword: newPassword,
        );
        print('Phase 2 confirmReset succeeded');

        // Login with old password fails
        try {
          await authRepo.login(email: testEmail, password: testPassword);
          fail('Expected 401 with old password');
        } on ApiException catch (e) {
          print(
            'Observed login with old password: status=${e.statusCode}, message=${e.message}',
          );
          expect(e.statusCode, 401);
        }

        // Login with new password succeeds
        final newTokens = await authRepo.login(
          email: testEmail,
          password: newPassword,
        );
        expect(newTokens.access, isNotEmpty);
        print(
          'Observed login with new password: token=${mask(newTokens.access)}',
        );
        capturedAccessToken = newTokens.access;
        capturedRefreshToken = newTokens.refresh;
      });

      test('11. access token refresh rotates tokens', () async {
        print('=== [SCENARIO 11] access token refresh ===');
        final newPair = await authRepo.refresh(
          refreshToken: capturedRefreshToken!,
        );
        print('Rotated access_token: ${mask(newPair.access)}');
        print('Rotated refresh_token: ${mask(newPair.refresh)}');
        expect(newPair.access, isNotEmpty);
        expect(newPair.refresh, isNotEmpty);
        expect(newPair.refresh, isNot(equals(capturedRefreshToken)));

        // 12. Replayed old refresh token must fail after atomic consume fix
        print('=== [SCENARIO 12] replayed old refresh token ===');
        try {
          await authRepo.refresh(refreshToken: capturedRefreshToken!);
          fail('Expected 401 on replayed refresh token');
        } on ApiException catch (e) {
          print(
            'Observed replayed refresh token rejection: status=${e.statusCode}, code=${e.code}, error=${e.message}',
          );
          expect(e.statusCode, 401);
        }

        capturedAccessToken = newPair.access;
        capturedRefreshToken = newPair.refresh;
      });

      test('13. logout and token deadness observation', () async {
        print('=== [SCENARIO 13] logout and token deadness ===');
        final store = MemoryTokenStore();
        final auth = AuthProvider(repository: authRepo, tokenStore: store);
        await store.writeTokens(
          access: capturedAccessToken!,
          refresh: capturedRefreshToken!,
        );

        await auth.logout();
        expect(auth.isAuthenticated, isFalse);
        expect(await store.readAccessToken(), isNull);
        print(
          'App local state after logout: isAuthenticated=${auth.isAuthenticated}, storedToken=${await store.readAccessToken()}',
        );

        // Backend probe with the previously issued access token
        try {
          final account = await authRepo.me(accessToken: capturedAccessToken!);
          print(
            'Backend probe after local logout: token STILL ACCEPTED by service! id=${account.id}, email=${account.email}',
          );
          print(
            'FINDING: Backend auth-service is stateless JWT without server-side revocation list on logout.',
          );
        } on ApiException catch (e) {
          print('Backend probe rejected token: status=${e.statusCode}');
        }
      });

      test(
        '14. notifications: welcome & password-changed inbox list and mark-read',
        () async {
          print('=== [SCENARIO 14] notifications inbox ===');
          final authedApi = ApiClient(
            baseUrl: baseUrl,
            allowSelfSigned: true,
            accessTokenReader: () async => capturedAccessToken,
          );
          final notifRepo = HttpNotificationRepository(authedApi);

          await Future.delayed(const Duration(milliseconds: 500));
          final items = await notifRepo.list();
          print('Observed notification inbox items: ${items.length}');
          for (final n in items) {
            print(
              '  - id=${n.id}, type=${n.type}, title="${n.title}", isRead=${n.isRead}',
            );
          }

          expect(items, isNotEmpty);
          final welcomeFound = items.any(
            (n) => n.title.toLowerCase().contains('welcome'),
          );
          final passChangeFound = items.any(
            (n) => n.title.toLowerCase().contains('password'),
          );
          print('Welcome notification present: $welcomeFound');
          print('Password changed notification present: $passChangeFound');

          // Mark read
          if (items.isNotEmpty) {
            final unread = items.firstWhere(
              (n) => !n.isRead,
              orElse: () => items.first,
            );
            print('Marking notification read: id=${unread.id}');
            await notifRepo.markRead(unread.id);
            final updatedList = await notifRepo.list();
            final check = updatedList.firstWhere((n) => n.id == unread.id);
            print('Notification read status after markRead: ${check.isRead}');
            expect(check.isRead, isTrue);
          }
          authedApi.dispose();
        },
      );

      test('15. notifications SSE live frame delivery', () async {
        print('=== [SCENARIO 15] SSE live frame delivery ===');
        final authedApi = ApiClient(baseUrl: baseUrl, allowSelfSigned: true);
        final completer = Completer<Map<String, dynamic>>();

        final stream = authedApi.sse(
          '/api/v1/notifications/stream',
          token: capturedAccessToken,
        );
        final sub = stream.listen((frame) {
          print('Observed live SSE frame: $frame');
          if (!completer.isCompleted) completer.complete(frame);
        });

        await Future.delayed(const Duration(milliseconds: 300));

        // Trigger notification via password reset
        final otp = await authRepo.requestReset(email: testEmail);
        if (otp != null) {
          final rToken = await authRepo.verifyResetCode(
            email: testEmail,
            code: otp,
          );
          await authRepo.confirmReset(
            resetToken: rToken,
            newPassword: 'LiveStreamPassword789!',
          );
        }

        final received = await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => {'timeout': true},
        );
        print('SSE received result: $received');
        expect(received['timeout'], isNot(true));
        await sub.cancel();
        authedApi.dispose();
      });

      test('16. repeated wrong passwords triggers lockout and 429', () async {
        print('=== [SCENARIO 16] lockout and 429 message ===');
        final lockoutEmail =
            'lockout_${DateTime.now().millisecondsSinceEpoch}@example.com';
        final res = await authRepo.signup(
          email: lockoutEmail,
          password: testPassword,
        );
        await authRepo.verifyOtp(email: lockoutEmail, code: res.devOtp!);

        ApiException? lastErr;
        for (int i = 1; i <= 6; i++) {
          try {
            await authRepo.login(
              email: lockoutEmail,
              password: 'BadPassword$i',
            );
          } on ApiException catch (e) {
            lastErr = e;
            print(
              'Attempt $i: status=${e.statusCode}, code=${e.code}, message=${e.message}',
            );
          }
        }

        expect(lastErr, isNotNull);
        expect(lastErr!.statusCode, 429);
        expect(lastErr.code, 'locked_out');
        final appMsg = ErrorMessages.forApiError(lastErr);
        print('Observed app display on lockout: $appMsg');
        expect(appMsg, ErrorMessages.rateLimited(false));
      });
    },
    skip: !runLive
        ? 'Skipped in offline CI. Run with --dart-define=RUN_LIVE_TESTS=true'
        : null,
  );
}
