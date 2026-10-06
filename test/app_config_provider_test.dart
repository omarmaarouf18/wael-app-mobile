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
  });

  group('compareAppVersions', () {
    test('compares numerically per segment', () {
      expect(compareAppVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareAppVersions('1.9.0', '1.9.0'), 0);
      expect(compareAppVersions('1.9', '1.9.1'), lessThan(0));
      expect(compareAppVersions('2.0', '1.99.99'), greaterThan(0));
      expect(compareAppVersions('x', '1.0.0'), lessThan(0));
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
