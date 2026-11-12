import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/error_messages.dart';
import 'package:wael_app/core/field_validators.dart';
import 'package:wael_app/core/store_policy.dart';

// Phone at signup (owner amendment 2026-11-12): optional in the iOS app only;
// Android requires it. The app tells the server which one it is with
// X-Client, and the server lets only `ios` leave the phone out.
void main() {
  group('StorePolicy', () {
    test('phone is optional at signup on iOS only', () {
      expect(StorePolicy.phoneOptionalAtSignup(TargetPlatform.iOS), isTrue);
      for (final p in [
        TargetPlatform.android,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        expect(StorePolicy.phoneOptionalAtSignup(p), isFalse, reason: '$p');
      }
    });

    test('client id is ios / android, null elsewhere', () {
      expect(StorePolicy.clientId(TargetPlatform.iOS), 'ios');
      expect(StorePolicy.clientId(TargetPlatform.android), 'android');
      expect(StorePolicy.clientId(TargetPlatform.macOS), isNull);
    });

    test('contentOnly is true on iOS only', () {
      expect(StorePolicy.contentOnly(TargetPlatform.iOS), isTrue);
      for (final p in [
        TargetPlatform.android,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        expect(StorePolicy.contentOnly(p), isFalse, reason: '$p');
      }
    });
  });

  group('FieldValidators.requiredPhone', () {
    for (final isArabic in [false, true]) {
      test('empty is refused, typed numbers follow optionalPhone '
          '(${isArabic ? 'ar' : 'en'})', () {
        expect(
          FieldValidators.requiredPhone('', isArabic: isArabic),
          ErrorMessages.emptyField(isArabic),
        );
        expect(
          FieldValidators.requiredPhone('   ', isArabic: isArabic),
          ErrorMessages.emptyField(isArabic),
        );
        expect(
          FieldValidators.requiredPhone('12ab', isArabic: isArabic),
          ErrorMessages.invalidPhone(isArabic),
        );
        expect(
          FieldValidators.requiredPhone('+20 100 000 0000', isArabic: isArabic),
          isNull,
        );
      });
    }
  });

  group('ApiClient X-Client header', () {
    Future<String?> sentHeader() async {
      String? seen;
      final mock = MockClient((req) async {
        seen = req.headers['X-Client'];
        return http.Response(jsonEncode({'id': 'u1'}), 201);
      });
      final api = ApiClient(baseUrl: 'https://localhost:8080', client: mock);
      await api.post('/api/v1/auth/signup', body: {'email': 'u@e.com'});
      return seen;
    }

    testWidgets(
      'iOS sends X-Client: ios',
      (tester) async {
        expect(await tester.runAsync(sentHeader), 'ios');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'Android sends X-Client: android',
      (tester) async {
        expect(await tester.runAsync(sentHeader), 'android');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });
}
