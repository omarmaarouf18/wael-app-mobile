import 'dart:io';

import 'package:flutter/material.dart' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wael_app/core/constants.dart';
import 'package:wael_app/models/app_config.dart';
import 'package:wael_app/providers/academy_catalog_provider.dart';
import 'package:wael_app/providers/app_config_provider.dart';
import 'package:wael_app/providers/home_provider.dart';
import 'package:wael_app/screens/course_detail_screen.dart';
import 'package:wael_app/widgets/subject_hero_banner.dart';

import 'academy_fakes.dart';
import 'screen_harness.dart';
import 'widget_layer_harness.dart';

/// Width and height from a JPEG's first SOF marker (baseline or progressive).
List<int?> jpegSize(List<int> bytes) {
  var i = 2;
  while (i + 9 < bytes.length) {
    if (bytes[i] != 0xFF) break;
    final marker = bytes[i + 1];
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    if (marker == 0xC0 || marker == 0xC2) {
      return [
        (bytes[i + 7] << 8) | bytes[i + 8],
        (bytes[i + 5] << 8) | bytes[i + 6],
      ];
    }
    i += 2 + length;
  }
  return [null, null];
}

void main() {
  test('the subject banner is the owner EL METR banner (1242 x 649 JPEG)', () {
    expect(AppConstants.imgSubjectBanner, 'assets/images/elmetr_banner.jpg');
    final bytes = File(AppConstants.imgSubjectBanner).readAsBytesSync();
    expect(bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    expect(jpegSize(bytes), [1242, 649]);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- ${AppConstants.imgSubjectBanner}'));
    // The old banner (source never confirmed) is gone everywhere.
    expect(File('assets/images/catalog_composure.jpg').existsSync(), isFalse);
    expect(pubspec, isNot(contains('catalog_composure')));
  });

  for (final (name, locale, _) in kLocales) {
    testWidgets('[$name] subject detail shows the banner', (tester) async {
      final repo = fake()..detailJson['d1'] = detailBody(owned: true);
      await pumpScreen(
        tester,
        locale,
        const CourseDetailScreen(courseId: 'd1'),
        appConfig: AppConfigProvider()..setForTesting(const AppConfigData()),
        extraProviders: [
          ChangeNotifierProvider<AcademyCatalogProvider>.value(
            value: AcademyCatalogProvider(repo),
          ),
          ChangeNotifierProvider(create: (_) => HomeProvider()),
        ],
        size: const Size(390, 2400),
      );
      final banner = tester.widget<SubjectHeroBanner>(
        find.byType(SubjectHeroBanner),
      );
      expect(banner.imageAsset, AppConstants.imgSubjectBanner);
      expect(banner.fallbackAsset, AppConstants.imgCharacterArt);
    });
  }
}
