import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guards: sample people, sample data and demo behaviour must not come
/// back into `lib/`. Anything a student sees as real comes from the API or
/// from `lib/content/director_profile.dart`.
List<File> _dartFiles(String root) => [
  for (final e in Directory(root).listSync(recursive: true))
    if (e is File && e.path.endsWith('.dart')) e,
];

void main() {
  final lib = _dartFiles('lib');

  test('no removed mock class, demo mode or sample link is in lib/', () {
    const forbidden = [
      'MockNotificationRepository',
      'dispatchMockNotification',
      'PushNotificationService',
      'EBookProvider',
      'SettingsProvider',
      'PaymentStatus',
      'StatusBadge',
      'MockAcademyRepository',
      'example.com/', // sample PDF links (the `name@example.com` hint is fine)
      'Demo Mode',
      'demo mode',
      'Interactive Demo',
    ];
    final hits = <String>[];
    for (final f in lib) {
      final text = f.readAsStringSync();
      for (final needle in forbidden) {
        if (text.contains(needle)) hits.add('${f.path}: $needle');
      }
    }
    expect(hits, isEmpty);
  });

  test('no sample person, credential or student statistic is in lib/', () {
    const forbidden = [
      'Wael El Metr', // the old director card text
      'وائل المتر',
      'Alexander Vane',
      'alexander_vane',
      'Top 3%',
      'Senior Scholar',
      'Arab Lawyers Union',
      'International Arbitrator',
      'Counselor Wael El Saeed',
    ];
    final hits = <String>[];
    for (final f in lib) {
      final text = f.readAsStringSync();
      for (final needle in forbidden) {
        if (text.contains(needle)) hits.add('${f.path}: $needle');
      }
    }
    expect(hits, isEmpty);
  });

  test('every committed asset is referenced by lib/ (or listed below)', () {
    // Committed but unreferenced on purpose; see docs/asset-provenance.md.
    const knownUnreferenced = {'el_metr_landscape.jpg'};
    final all = lib.map((f) => f.readAsStringSync()).join('\n');
    final orphans = <String>[];
    for (final e in Directory('assets').listSync(recursive: true)) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (knownUnreferenced.contains(name)) continue;
      if (!all.contains(name)) orphans.add(e.path);
    }
    expect(orphans, isEmpty);
  });

  test('lib/content holds only the director profile', () {
    final names = Directory(
      'lib/content',
    ).listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList();
    expect(names, ['director_profile.dart']);
  });
}
