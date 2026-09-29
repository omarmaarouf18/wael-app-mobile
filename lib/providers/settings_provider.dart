import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  bool _biometricEnabled = true;
  final bool _twoFactorEnabled = true;
  bool _eventReminders = true;
  bool _curriculumUpdates = true;

  bool get biometricEnabled => _biometricEnabled;
  bool get twoFactorEnabled => _twoFactorEnabled;
  bool get eventReminders => _eventReminders;
  bool get curriculumUpdates => _curriculumUpdates;

  void toggleBiometric() {
    _biometricEnabled = !_biometricEnabled;
    notifyListeners();
  }

  void toggleReminders() {
    _eventReminders = !_eventReminders;
    notifyListeners();
  }

  void toggleUpdates() {
    _curriculumUpdates = !_curriculumUpdates;
    notifyListeners();
  }
}
