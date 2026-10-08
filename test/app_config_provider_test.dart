import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/api_client.dart';
import 'package:wael_app/core/app_config_cache.dart';
import 'package:wael_app/models/academy_catalog.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/repositories/academy_repository.dart';

class _Repo implements AcademyRepository {
  AppConfigData data = const AppConfigData(
    termsUrl: 'https://legal.elmetracademy.app/terms',
    privacyUrl: 'https://legal.elmetracademy.app/privacy',
    minVersion: '1.2.0',
    latestVersion: '1.4.0',
  );
  Object? error;
  int calls = 0;

  @override
  Future<AppConfigData> appConfig() async {
    calls++;
    if (error != null) throw error!;
    return data;
  }

  @override
  Future<AcademyLevels> levels() => throw UnimplementedError();

  @override
  Future<SubjectPage> subjects({
    String? levelKey,
    String? term,
    int page = 1,
    int limit = 20,
  }) => throw UnimplementedError();

  @override
  Future<AcademySubjectDetail> subject(String id) => throw UnimplementedError();

  @override
  Future<VideoPlayback> playVideo(String videoId) => throw UnimplementedError();

  @override
  Future<AccessRequest> requestAccess(String subjectId) =>
      throw UnimplementedError();
}

void main() {
  group('AppConfigData.fromJson', () {
    test('keeps https URLs, drops the rest', () {
      const config = AppConfigData();
      expect(config.termsUrl, isEmpty);
      final parsed = AppConfigData.fromJson({
        'support_whatsapp_url': 'https://wa.me/201000000000',
        'terms_url': 'https://legal.elmetracademy.app/terms',
        'privacy_url': 'http://plain.example/privacy',
        'min_version': ' 1.2.0 ',
        'latest_version': null,
        'update_url': 'javascript:alert(1)',
      });
      expect(parsed.supportWhatsappUrl, 'https://wa.me/201000000000');
      expect(parsed.termsUrl, 'https://legal.elmetracademy.app/terms');
      expect(parsed.privacyUrl, isEmpty);
      expect(parsed.minVersion, '1.2.0');
      expect(parsed.latestVersion, isEmpty);
      expect(parsed.updateUrl, isEmpty);
    });

    test('tolerates a missing or partial body', () {
      expect(AppConfigData.fromJson({}).termsUrl, isEmpty);
    });

    test('show_prices is true only for a real boolean true', () {
      expect(AppConfigData.fromJson({'show_prices': true}).showPrices, isTrue);
      expect(AppConfigData.fromJson({}).showPrices, isFalse);
      expect(
        AppConfigData.fromJson({'show_prices': false}).showPrices,
        isFalse,
      );
      for (final junk in [1, 'true', 'yes', <Object?>[], <String, Object?>{}]) {
        expect(
          AppConfigData.fromJson({'show_prices': junk}).showPrices,
          isFalse,
          reason: 'show_prices: $junk',
        );
      }
      expect(const AppConfigData().showPrices, isFalse);
    });

    test('center parses both shapes: absent and present', () {
      expect(AppConfigData.fromJson({}).center, isNull);
      expect(AppConfigData.fromJson({'center': 'Cairo'}).center, isNull);
      expect(AppConfigData.fromJson({'center': 42}).center, isNull);
      expect(
        AppConfigData.fromJson({'center': <String, Object?>{}}).center,
        isNotNull,
      );
    });

    test('center keeps display strings and an https map link only', () {
      final parsed = AppConfigData.fromJson({
        'center': {
          'name': {'ar': '  السنتر  ', 'en': 'El Metr Center'},
          'address': {'ar': 'مدينة نصر، القاهرة', 'en': 'Nasr City, Cairo'},
          'hours': {'ar': 'يوميًا ١٠ص-١٠م', 'en': 'Daily 10am-10pm'},
          'map_url': 'https://maps.example/center',
        },
      });
      final center = parsed.center!;
      expect(center.nameFor(true), 'السنتر');
      expect(center.nameFor(false), 'El Metr Center');
      expect(center.addressFor(true), 'مدينة نصر، القاهرة');
      expect(center.addressFor(false), 'Nasr City, Cairo');
      expect(center.hoursFor(true), 'يوميًا ١٠ص-١٠م');
      expect(center.hoursFor(false), 'Daily 10am-10pm');
      expect(center.mapUrl, 'https://maps.example/center');
      expect(center.hasContent, isTrue);
    });

    test('center name and address fall back to the other language', () {
      final parsed = AppConfigData.fromJson({
        'center': {
          'name': {'ar': 'السنتر'},
          'address': {'en': 'Nasr City, Cairo'},
        },
      });
      final center = parsed.center!;
      expect(center.nameFor(true), 'السنتر');
      expect(center.nameFor(false), 'السنتر');
      expect(center.addressFor(true), 'Nasr City, Cairo');
      expect(center.addressFor(false), 'Nasr City, Cairo');
      expect(center.hasContent, isTrue);
    });

    test('center name and address still accept a plain string', () {
      final parsed = AppConfigData.fromJson({
        'center': {'name': 'El Metr Center', 'address': 'Nasr City, Cairo'},
      });
      final center = parsed.center!;
      expect(center.nameFor(true), 'El Metr Center');
      expect(center.nameFor(false), 'El Metr Center');
      expect(center.addressFor(true), 'Nasr City, Cairo');
      expect(center.addressFor(false), 'Nasr City, Cairo');
      expect(center.hasContent, isTrue);
    });

    test('center name and address ignore malformed values', () {
      final parsed = AppConfigData.fromJson({
        'center': {
          'name': 42,
          'address': ['Cairo'],
          'hours': {'ar': 'يوميًا ١٠ص-١٠م'},
        },
      });
      final center = parsed.center!;
      expect(center.nameFor(true), isEmpty);
      expect(center.nameFor(false), isEmpty);
      expect(center.addressFor(true), isEmpty);
      expect(center.hasContent, isTrue);
    });

    test('center hours fall back to the other language', () {
      final parsed = AppConfigData.fromJson({
        'center': {
          'name': 'El Metr Center',
          'hours': {'ar': 'يوميًا ١٠ص-١٠م'},
        },
      });
      final center = parsed.center!;
      expect(center.hoursFor(true), 'يوميًا ١٠ص-١٠م');
      expect(center.hoursFor(false), 'يوميًا ١٠ص-١٠م');
      expect(center.mapUrl, isEmpty);
      expect(center.hasContent, isTrue);
    });

    test('center drops a non-https map link, bare objects show nothing', () {
      final parsed = AppConfigData.fromJson({
        'center': {'map_url': 'http://plain.example/map'},
      });
      final center = parsed.center!;
      expect(center.mapUrl, isEmpty);
      expect(center.hasContent, isFalse);
    });

    test('toJson round-trips the new fields through the cache shape', () {
      final parsed = AppConfigData.fromJson({
        'show_prices': true,
        'center': {
          'name': {'ar': 'السنتر', 'en': 'El Metr Center'},
          'address': 'Nasr City, Cairo',
          'hours': {'ar': 'يوميًا ١٠ص-١٠م', 'en': 'Daily 10am-10pm'},
          'map_url': 'https://maps.example/center',
        },
      });
      final reparsed = AppConfigData.fromJson(parsed.toJson());
      expect(reparsed.showPrices, isTrue);
      expect(reparsed.center?.nameFor(true), 'السنتر');
      expect(reparsed.center?.nameFor(false), 'El Metr Center');
      expect(reparsed.center?.addressFor(false), 'Nasr City, Cairo');
      expect(reparsed.center?.hoursFor(false), 'Daily 10am-10pm');
      expect(reparsed.center?.mapUrl, 'https://maps.example/center');
    });
  });

  group('compareAppVersions and parseAppVersion', () {
    test('equal versions', () {
      expect(compareAppVersions('1.2.0', '1.2.0'), 0);
      expect(compareAppVersions('1.2', '1.2.0'), 0);
      expect(compareAppVersions('1.2.0', '1.2'), 0);
      expect(compareAppVersions('v1.2.3', '1.2.3'), 0);
      expect(compareAppVersions('V1.2.3', '1.2.3'), 0);
      expect(compareAppVersions('1.2.3+4', '1.2.3+4'), 0);
      expect(compareAppVersions('1.2.3-beta', '1.2.3'), 0);
    });

    test('lower versions', () {
      expect(compareAppVersions('1.2.0', '1.3.0'), lessThan(0));
      expect(compareAppVersions('1.2', '1.2.1'), lessThan(0));
      expect(compareAppVersions('1.2.3', '1.2.3+1'), lessThan(0));
      expect(compareAppVersions('1.2.3+4', '1.2.3+5'), lessThan(0));
      expect(compareAppVersions('0.9.9', '1.0.0'), lessThan(0));
    });

    test('higher versions', () {
      expect(compareAppVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareAppVersions('2.0', '1.99.99'), greaterThan(0));
      expect(compareAppVersions('1.2.3+5', '1.2.3+4'), greaterThan(0));
      expect(compareAppVersions('1.2.3+1', '1.2.3'), greaterThan(0));
      expect(compareAppVersions('1.3.0', '1.2.9'), greaterThan(0));
    });

    test('suffixes tolerance', () {
      expect(isValidAppVersion('1.2.3+4'), isTrue);
      expect(isValidAppVersion('1.2.3+100'), isTrue);
      expect(isValidAppVersion('v1.2.3'), isTrue);
      expect(isValidAppVersion('V2.0.0'), isTrue);
      expect(isValidAppVersion('1.2.3-rc1'), isTrue);
    });

    test('junk and invalid versions', () {
      expect(isValidAppVersion(''), isFalse);
      expect(isValidAppVersion('   '), isFalse);
      expect(isValidAppVersion('abc'), isFalse);
      expect(isValidAppVersion('1.a.3'), isFalse);
      expect(isValidAppVersion('1..2'), isFalse);
      expect(isValidAppVersion('1.2.3+abc'), isFalse);
      expect(isValidAppVersion('v'), isFalse);

      expect(compareAppVersions('junk', '1.0.0'), lessThan(0));
      expect(compareAppVersions('1.0.0', 'junk'), greaterThan(0));
      expect(compareAppVersions('junk', 'garbage'), 0);
      expect(compareAppVersions('', ''), 0);
    });
  });

  group('AppConfigProvider', () {
    test('loads once and reuses the cache within the TTL', () async {
      final repo = _Repo();
      final now = DateTime.utc(2026, 10, 6, 12);
      var clock = now;
      final provider = AppConfigProvider(
        repository: repo,
        cache: MemoryAppConfigCache(),
        clock: () => clock,
      );
      await provider.load();
      expect(provider.termsUrl, contains('/terms'));
      expect(repo.calls, 1);
      clock = now.add(const Duration(minutes: 4));
      await provider.load();
      expect(repo.calls, 1);
      clock = now.add(const Duration(minutes: 6));
      await provider.load();
      expect(repo.calls, 2);
    });

    test('an error keeps the last values and never throws', () async {
      final repo = _Repo();
      final provider = AppConfigProvider(
        repository: repo,
        cache: MemoryAppConfigCache(),
      );
      await provider.load();
      expect(provider.termsUrl, isNotEmpty);
      repo.error = ApiException(statusCode: 500, message: 'down');
      await provider.load(force: true);
      expect(provider.termsUrl, isNotEmpty);
      expect(provider.updateState('9.9.9'), UpdateState.none);
    });

    test('an error with no cache leaves empty values', () async {
      final repo = _Repo()
        ..error = ApiException(statusCode: -1, message: 'timeout');
      final provider = AppConfigProvider(
        repository: repo,
        cache: MemoryAppConfigCache(),
      );
      await provider.load();
      expect(provider.termsUrl, isEmpty);
      expect(provider.updateState('1.0.0'), UpdateState.none);
    });

    test('updateState follows min/latest', () {
      final provider = AppConfigProvider(cache: MemoryAppConfigCache())
        ..setForTesting(
          const AppConfigData(minVersion: '1.2.0', latestVersion: '1.4.0'),
        );
      expect(provider.updateState('1.1.9'), UpdateState.required);
      expect(provider.updateState('1.2.0'), UpdateState.available);
      expect(provider.updateState('1.4.0'), UpdateState.none);
      expect(provider.updateState('9.0.0'), UpdateState.none);
      expect(provider.updateState(''), UpdateState.none);
      expect(provider.updateState('junk'), UpdateState.none);
      expect(provider.updateState('   '), UpdateState.none);
    });

    test('updateState with invalid min/latest in config returns none', () {
      final provider = AppConfigProvider(cache: MemoryAppConfigCache())
        ..setForTesting(
          const AppConfigData(minVersion: 'invalid', latestVersion: 'garbage'),
        );
      expect(provider.updateState('1.0.0'), UpdateState.none);
    });

    test('concurrent loads share one fetch', () async {
      final repo = _Repo();
      final provider = AppConfigProvider(
        repository: repo,
        cache: MemoryAppConfigCache(),
      );
      await Future.wait([provider.load(), provider.load(), provider.load()]);
      expect(repo.calls, 1);
    });
  });
}
