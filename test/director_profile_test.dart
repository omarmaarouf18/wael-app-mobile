import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/content/director_profile.dart';

import 'director_fixture.dart';

void main() {
  group('kDirectorProfile (shipped content)', () {
    test('is empty: no placeholder or sample text is committed', () {
      const p = kDirectorProfile;
      expect(p.name, isEmpty);
      expect(p.nameAr, isEmpty);
      expect(p.title, isEmpty);
      expect(p.titleAr, isEmpty);
      expect(p.badge, isEmpty);
      expect(p.badgeAr, isEmpty);
      expect(p.bio, isEmpty);
      expect(p.bioAr, isEmpty);
      expect(p.credentials, isEmpty);
      expect(p.credentialsAr, isEmpty);
      expect(p.portraitAsset, isEmpty);
      expect(p.hasContent, isFalse);
      expect(p.hasPortrait, isFalse);
    });
  });

  group('DirectorProfile', () {
    test('has content as soon as there is a name in either language', () {
      expect(const DirectorProfile(name: 'A').hasContent, isTrue);
      expect(const DirectorProfile(nameAr: 'أ').hasContent, isTrue);
      expect(const DirectorProfile(name: '   ').hasContent, isFalse);
      // A bio without a name is not enough to show the card.
      expect(const DirectorProfile(bio: 'text').hasContent, isFalse);
    });

    test('picks the active language and falls back to the other', () {
      expect(testDirector.localizedName(true), testDirector.nameAr);
      expect(testDirector.localizedName(false), testDirector.name);
      const onlyEn = DirectorProfile(name: 'A', title: 'T', bio: 'B');
      expect(onlyEn.localizedName(true), 'A');
      expect(onlyEn.localizedTitle(true), 'T');
      expect(onlyEn.localizedBio(true), 'B');
      expect(onlyEn.localizedBadge(true), isEmpty);
      expect(onlyEn.localizedCredentials(true), isEmpty);
    });

    test('credentials follow the language, with fallback', () {
      expect(
        testDirector.localizedCredentials(true),
        testDirector.credentialsAr,
      );
      expect(
        testDirector.localizedCredentials(false),
        testDirector.credentials,
      );
      const onlyEn = DirectorProfile(name: 'A', credentials: ['x']);
      expect(onlyEn.localizedCredentials(true), ['x']);
    });
  });
}
