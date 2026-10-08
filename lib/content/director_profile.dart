/// The academy director's profile, shown on Home and as a strip on each
/// subject. This file is the only place to change it.
///
/// The content is the owner's own. Name: from the owner's business card,
/// verified by the owner on 2026-10-02. Titles and portrait: supplied by the
/// owner on 2026-10-08, replacing the 2026-10-02 business-card titles and the
/// character art; the photo is used with the director's consent. There is
/// deliberately no biography. The card is hidden when the profile has no
/// name, and every part with no text is simply not drawn.
library;

import '../core/constants.dart';

class DirectorProfile {
  const DirectorProfile({
    this.name = '',
    this.nameAr = '',
    this.titles = const [],
    this.titlesAr = const [],
    this.bio = '',
    this.bioAr = '',
    this.portraitAsset = '',
  });

  final String name;
  final String nameAr;

  /// Short titles shown under the name, one chip each.
  final List<String> titles;
  final List<String> titlesAr;

  final String bio;
  final String bioAr;

  /// Asset path of the portrait. Empty shows a neutral person icon.
  final String portraitAsset;

  /// The card and the subject strip are shown only when there is a name.
  bool get hasContent => name.trim().isNotEmpty || nameAr.trim().isNotEmpty;

  bool get hasPortrait => portraitAsset.isNotEmpty;

  static String _pick(String ar, String en, bool isArabic) =>
      isArabic && ar.trim().isNotEmpty ? ar : en;

  String localizedName(bool isArabic) => _pick(nameAr, name, isArabic);
  String localizedBio(bool isArabic) => _pick(bioAr, bio, isArabic);

  List<String> localizedTitles(bool isArabic) =>
      isArabic && titlesAr.isNotEmpty ? titlesAr : titles;

  /// All titles on one line, for the compact strip on a subject.
  String localizedTagline(bool isArabic) =>
      localizedTitles(isArabic).join(' • ');
}

/// The one director profile of the app.
const DirectorProfile kDirectorProfile = DirectorProfile(
  name: 'Wael El Saeed',
  nameAr: 'وائل السعيد',
  titles: ['Lawyer', 'Legal lecturer', 'Arbitrator', 'Contracts expert'],
  titlesAr: ['محامٍ', 'محاضر قانوني', 'محكّم', 'خبير عقود'],
  portraitAsset: AppConstants.imgDirectorPortrait,
);
