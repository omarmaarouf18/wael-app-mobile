// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';

const runLive = bool.fromEnvironment('RUN_LIVE_TESTS', defaultValue: false);
const baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://localhost:18080',
);

void main() {
  test(
    'Gateway rate limiting returns 429 after 100 requests',
    () async {
      final api = ApiClient(baseUrl: baseUrl, allowSelfSigned: true);
      print(
        'Starting rapid requests to trigger Gateway rate limit (limit=100/min)...',
      );

      int nonRateLimitCount = 0;
      int rateLimitCount = 0;
      ApiException? captured429;

      for (int i = 1; i <= 105; i++) {
        try {
          await api.post('/api/v1/auth/signup', body: {});
          nonRateLimitCount++;
        } on ApiException catch (e) {
          if (e.statusCode == 429) {
            rateLimitCount++;
            captured429 ??= e;
            print(
              'Request $i hit 429: status=${e.statusCode}, code=${e.code}, message="${e.message}"',
            );
          } else {
            nonRateLimitCount++;
          }
        } catch (e) {
          print('Request $i unexpected exception: $e');
        }
      }

      print(
        'Finished burst: non-429 count=$nonRateLimitCount, 429 count=$rateLimitCount',
      );
      expect(rateLimitCount, greaterThan(0));
      final err429 = captured429;
      expect(err429, isNotNull);
      expect(err429!.statusCode, 429);
      expect(err429.code, 'rate_limited');

      final appMsg = ErrorMessages.forApiError(err429);
      print('Observed app display on gateway rate limit: "$appMsg"');
      expect(appMsg, ErrorMessages.rateLimited(false));

      api.dispose();
    },
    skip: !runLive
        ? 'Skipped in offline CI. Run with --dart-define=RUN_LIVE_TESTS=true'
        : null,
  );
}
