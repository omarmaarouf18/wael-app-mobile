import 'package:flutter/material.dart';

import '../content/director_profile.dart';

/// State of the Home tab: the director profile (from
/// `lib/content/director_profile.dart`) and whether its biography is expanded.
class HomeProvider extends ChangeNotifier {
  HomeProvider({this._director = kDirectorProfile});

  final DirectorProfile _director;
  bool _isBioExpanded = false;

  bool get isBioExpanded => _isBioExpanded;
  DirectorProfile get director => _director;

  void toggleBioExpansion() {
    _isBioExpanded = !_isBioExpanded;
    notifyListeners();
  }
}
