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
      expect(p.titlesAr, [
        'محامٍ',
        'مدرس قانون',
        'محكم دولي وإقليمي',
        'عضو اتحاد المحامين العرب',
      ]);
      expect(p.titles, [
        'Lawyer',
        'Law lecturer',
        'International and regional arbitrator',
        'Member of the Arab Lawyers Union',
      ]);
      expect(p.hasContent, isTrue);
    });

    test('has no biography; the portrait is the character art', () {
      const p = kDirectorProfile;
      expect(p.bio, isEmpty);
      expect(p.bioAr, isEmpty);
      expect(p.localizedBio(true), isEmpty);
      expect(p.localizedBio(false), isEmpty);
      expect(p.portraitAsset, AppConstants.imgCharacterArt);
      expect(p.hasPortrait, isTrue);
    });

    test('follows the language', () {
      const p = kDirectorProfile;
      expect(p.localizedName(true), 'وائل السعيد');
      expect(p.localizedName(false), 'Wael El Saeed');
      expect(p.localizedTitles(true), hasLength(4));
      expect(p.localizedTitles(false), hasLength(4));
      expect(p.localizedTagline(false), startsWith('Lawyer • Law lecturer'));
      expect(p.localizedTagline(true), startsWith('محامٍ • مدرس قانون'));
    });
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
