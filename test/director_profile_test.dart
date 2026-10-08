import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/content/director_profile.dart';
import 'package:wael_app/core/constants.dart';

import 'director_fixture.dart';

void main() {
  group('kDirectorProfile (shipped content)', () {
    test('is the owner-verified content, exactly', () {
      const p = kDirectorProfile;
      expect(p.nameAr, 'وائل السعيد');
      expect(p.name, 'Wael El Saeed');
      // Titles: owner decision 2026-10-08, in this order.
      expect(p.titlesAr, ['محامٍ', 'محاضر قانوني', 'محكّم', 'خبير عقود']);
      expect(p.titles, [
        'Lawyer',
        'Legal lecturer',
        'Arbitrator',
        'Contracts expert',
      ]);
      expect(p.hasContent, isTrue);
    });

    test('has no biography; the portrait is the director photo', () {
      const p = kDirectorProfile;
      expect(p.bio, isEmpty);
      expect(p.bioAr, isEmpty);
      expect(p.localizedBio(true), isEmpty);
      expect(p.localizedBio(false), isEmpty);
      expect(p.portraitAsset, AppConstants.imgDirectorPortrait);
      expect(p.portraitAsset, isNot(AppConstants.imgCharacterArt));
      expect(p.hasPortrait, isTrue);
    });

    test('follows the language', () {
      const p = kDirectorProfile;
      expect(p.localizedName(true), 'وائل السعيد');
      expect(p.localizedName(false), 'Wael El Saeed');
      expect(p.localizedTitles(true), hasLength(4));
      expect(p.localizedTitles(false), hasLength(4));
      expect(
        p.localizedTagline(false),
        'Lawyer • Legal lecturer • Arbitrator • Contracts expert',
      );
      expect(
        p.localizedTagline(true),
        'محامٍ • محاضر قانوني • محكّم • خبير عقود',
      );
    });
  });

  test('the portrait asset is bundled: 800 x 800 JPEG, listed in pubspec', () {
    final file = File(AppConstants.imgDirectorPortrait);
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    expect(bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF]); // JPEG
    // Width and height from the first SOF marker (baseline or progressive).
    var i = 2;
    int? width, height;
    while (i + 9 < bytes.length) {
      if (bytes[i] != 0xFF) break;
      final marker = bytes[i + 1];
      final length = (bytes[i + 2] << 8) | bytes[i + 3];
      if (marker == 0xC0 || marker == 0xC2) {
        height = (bytes[i + 5] << 8) | bytes[i + 6];
        width = (bytes[i + 7] << 8) | bytes[i + 8];
        break;
      }
      i += 2 + length;
    }
    expect([width, height], [800, 800]);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- ${AppConstants.imgDirectorPortrait}'),
    );
  });

  group('DirectorProfile', () {
    test('an empty profile has no content and shows nothing', () {
      const p = DirectorProfile();
      expect(p.hasContent, isFalse);
      expect(p.hasPortrait, isFalse);
      expect(p.localizedTitles(true), isEmpty);
      expect(p.localizedTagline(false), isEmpty);
    });

    test('has content as soon as there is a name in either language', () {
      expect(const DirectorProfile(name: 'A').hasContent, isTrue);
      expect(const DirectorProfile(nameAr: 'أ').hasContent, isTrue);
      expect(const DirectorProfile(name: '   ').hasContent, isFalse);
      // Titles or a bio without a name are not enough to show the card.
      expect(
        const DirectorProfile(titles: ['x'], bio: 't').hasContent,
        isFalse,
      );
    });

    test('falls back to English when the Arabic text is missing', () {
      const onlyEn = DirectorProfile(name: 'A', titles: ['T'], bio: 'B');
      expect(onlyEn.localizedName(true), 'A');
      expect(onlyEn.localizedTitles(true), ['T']);
      expect(onlyEn.localizedBio(true), 'B');
    });

    test('a filled test profile follows the language', () {
      expect(testDirector.localizedName(true), testDirector.nameAr);
      expect(testDirector.localizedName(false), testDirector.name);
      expect(testDirector.localizedTitles(true), testDirector.titlesAr);
      expect(testDirector.localizedTitles(false), testDirector.titles);
    });
  });
}
