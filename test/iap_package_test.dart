import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/models/iap_package.dart';

import 'iap_fakes.dart';

// Issue #57: the app parses exactly the IAP brief Section 3 JSON and
// ignores unknown fields.
void main() {
  group('IapCatalog', () {
    test('parses the contract example', () {
      final c = IapCatalog.fromJson(packagesJson());
      expect(c.appAccountToken, kToken);
      expect(c.packages, hasLength(1));
      final p = c.packages.single;
      expect(p.id, 'pkg_1');
      expect(p.productId, 'com.wael.app.pkg.year1');
      expect(p.title.ar, 'الفرقة الأولى');
      expect(p.title.en, 'Year 1');
      expect(p.description.en, '');
      expect(p.availableUntil, DateTime.utc(2027, 1, 20));
      expect(p.onSale, isTrue);
      expect(p.position, 1);
      final s = p.subjects.single;
      expect(s.id, 'subj_a');
      expect(s.levelKey, 'bachelor-y1');
      expect(s.term, 'first');
      expect(s.owned, isFalse);
      expect(p.allOwned, isFalse);
      expect(c.byProductId('com.wael.app.pkg.year1'), same(p));
      expect(c.byProductId('com.wael.app.pkg.year2'), isNull);
    });

    test('available_until null, absent or zero time means no end date', () {
      for (final v in [null, '', '0001-01-01T00:00:00Z', 'not a date']) {
        final c = IapCatalog.fromJson(packagesJson(availableUntil: v));
        expect(c.packages.single.availableUntil, isNull, reason: '$v');
      }
    });

    test('owned and on_sale are read; allOwned needs every subject owned', () {
      final c = IapCatalog.fromJson(packagesJson(onSale: false, owned: true));
      expect(c.packages.single.onSale, isFalse);
      expect(c.packages.single.subjects.single.owned, isTrue);
      expect(c.packages.single.allOwned, isTrue);
    });

    test('unknown fields are ignored, null lists are empty', () {
      final json = packagesJson();
      json['future_field'] = {'x': 1};
      final pkg = (json['packages'] as List).single as Map<String, dynamic>;
      pkg['price'] = '9.99';
      pkg['subjects'] = null;
      final c = IapCatalog.fromJson(json);
      expect(c.packages.single.subjects, isEmpty);
      expect(c.packages.single.allOwned, isFalse);

      final empty = IapCatalog.fromJson({
        'app_account_token': kToken,
        'packages': null,
      });
      expect(empty.packages, isEmpty);
    });

    test('a missing or non-UUID app_account_token is a contract error', () {
      for (final t in [null, '', '8c7e...-uuid', 'not-a-uuid']) {
        final json = packagesJson()..['app_account_token'] = t;
        expect(
          () => IapCatalog.fromJson(json),
          throwsA(isA<AcademyParseException>()),
          reason: '$t',
        );
      }
    });

    test('a package without product_id is a contract error', () {
      final json = packagesJson();
      ((json['packages'] as List).single as Map).remove('product_id');
      expect(
        () => IapCatalog.fromJson(json),
        throwsA(isA<AcademyParseException>()),
      );
    });
  });

  group('IapTransactionResult', () {
    test('parses granted with skipped subjects', () {
      final r = IapTransactionResult.fromJson(grantedJson());
      expect(r.status, IapTransactionStatus.granted);
      expect(r.transactionId, '2000000123');
      expect(r.productId, 'com.wael.app.pkg.year1');
      expect(r.packageId, 'pkg_1');
      expect(r.grantedSubjectIds, ['subj_a']);
      expect(r.skipped.single.subjectId, 'subj_b');
      expect(r.skipped.single.reason, 'already_owned');
    });

    test('already_processed and unknown statuses', () {
      expect(
        IapTransactionResult.fromJson(
          grantedJson(status: 'already_processed'),
        ).status,
        IapTransactionStatus.alreadyProcessed,
      );
      expect(
        IapTransactionResult.fromJson(grantedJson(status: 'later')).status,
        IapTransactionStatus.unknown,
      );
    });

    test('null lists are empty; a missing status is a contract error', () {
      final r = IapTransactionResult.fromJson({
        'status': 'granted',
        'granted_subject_ids': null,
        'skipped': null,
      });
      expect(r.grantedSubjectIds, isEmpty);
      expect(r.skipped, isEmpty);
      expect(
        () => IapTransactionResult.fromJson({}),
        throwsA(isA<AcademyParseException>()),
      );
    });
  });
}
