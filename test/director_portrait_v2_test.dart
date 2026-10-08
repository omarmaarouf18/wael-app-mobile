import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/content/director_profile.dart';
import 'package:wael_app/core/constants.dart';
import 'package:wael_app/widgets/instructor_dossier_card.dart';

import 'widget_layer_harness.dart';

/// Director portrait v2 (owner, 2026-10-08): `director_portrait_v2.jpg`
/// replaces the photo in place under the same asset path; the four titles
/// are unchanged.
void main() {
  test('the bundled portrait is v2 (800 x 800 JPEG, same path)', () {
    expect(
      AppConstants.imgDirectorPortrait,
      'assets/images/director_portrait.jpg',
    );
    final bytes = File(AppConstants.imgDirectorPortrait).readAsBytesSync();
    expect(bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    // v2 as supplied in "Claude outputs/director/director_portrait_v2.jpg"
    // is 73836 bytes (v1 was 70391).
    expect(bytes.length, 73836);
  });

  for (final (name, locale, _) in kLocales) {
    final ar = locale.languageCode == 'ar';
    testWidgets('[$name] the card shows the v2 portrait and the 4 titles', (
      tester,
    ) async {
      await pumpLocalized(
        tester,
        locale,
        Scaffold(
          body: SingleChildScrollView(
            child: InstructorDossierCard(
              profile: kDirectorProfile,
              bioExpanded: false,
              onToggleBio: () {},
            ),
          ),
        ),
      );
      final titles = ar
          ? ['محامٍ', 'محاضر قانوني', 'محكّم', 'خبير عقود']
          : ['Lawyer', 'Legal lecturer', 'Arbitrator', 'Contracts expert'];
      for (final t in titles) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text(ar ? 'وائل السعيد' : 'Wael El Saeed'), findsOneWidget);
      final portrait = find.byWidgetPredicate((w) {
        if (w is! Container || w.decoration is! BoxDecoration) return false;
        final image = (w.decoration! as BoxDecoration).image?.image;
        return image is ResizeImage &&
            image.imageProvider is AssetImage &&
            (image.imageProvider as AssetImage).assetName ==
                AppConstants.imgDirectorPortrait;
      });
      expect(portrait, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
