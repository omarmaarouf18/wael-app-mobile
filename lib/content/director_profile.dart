/// The academy director's profile, shown on Home and as a strip on each
/// subject. This file is the only place to fill it in.
///
/// Every field is empty on purpose, and the director card is hidden until
/// [DirectorProfile.hasContent] is true, so the app never shows text the owner
/// has not supplied. Fill the Arabic (`*Ar`) and English fields below with the
/// owner-approved text; an empty `*Ar` field falls back to the English one.
library;

class DirectorProfile {
  const DirectorProfile({
    this.name = '',
    this.nameAr = '',
    this.title = '',
    this.titleAr = '',
    this.badge = '',
    this.badgeAr = '',
    this.bio = '',
    this.bioAr = '',
    this.credentials = const [],
    this.credentialsAr = const [],
    this.portraitAsset = '',
  });

  final String name;
  final String nameAr;

  /// One-line title under the name (also the tagline on a subject).
  final String title;
  final String titleAr;

  /// Short tag next to the name (for example a role label). Empty hides it.
  final String badge;
  final String badgeAr;

  final String bio;
  final String bioAr;

  final List<String> credentials;
  final List<String> credentialsAr;

  /// Asset path of the portrait. Empty shows a neutral person icon.
  final String portraitAsset;

  /// The card and the subject strip are shown only when there is a name.
  bool get hasContent => name.trim().isNotEmpty || nameAr.trim().isNotEmpty;

  bool get hasPortrait => portraitAsset.isNotEmpty;

  static String _pick(String ar, String en, bool isArabic) =>
      isArabic && ar.trim().isNotEmpty ? ar : en;

  String localizedName(bool isArabic) => _pick(nameAr, name, isArabic);
  String localizedTitle(bool isArabic) => _pick(titleAr, title, isArabic);
  String localizedBadge(bool isArabic) => _pick(badgeAr, badge, isArabic);
  String localizedBio(bool isArabic) => _pick(bioAr, bio, isArabic);

  List<String> localizedCredentials(bool isArabic) =>
      isArabic && credentialsAr.isNotEmpty ? credentialsAr : credentials;
}

/// The one director profile of the app. Empty until the owner sends the text.
const DirectorProfile kDirectorProfile = DirectorProfile();
