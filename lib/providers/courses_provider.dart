import 'package:flutter/material.dart';

/// Compatibility shim. The catalog now lives in `AcademyCatalogProvider`
/// (academy-service); the bundled mock catalog that used to be here is gone.
///
/// `payment_screen.dart` still calls [markEnrolled] when its (mock) payment
/// flow completes. Remove this class together with that flow (SPEC Phase 5).
class CoursesProvider extends ChangeNotifier {
  void markEnrolled(String courseId) {
    notifyListeners();
  }
}
