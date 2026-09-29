import 'package:flutter/material.dart';
import '../models/instructor_profile.dart';
import '../core/constants.dart';

class HomeProvider extends ChangeNotifier {
  bool _isRsvpConfirmed = false;
  bool _isLoading = false;
  bool _isBioExpanded = false;

  final InstructorProfile _instructor = const InstructorProfile(
    id: 'wael-el-metr',
    name: 'Dean Wael El Metr',
    nameAr: 'المستشار د. وائل المتر',
    title:
        'Ph.D. in Law • Certified International Arbitrator • Academy Founder',
    titleAr: 'دكتوراه في القانون • محكم دولي معتمد • مؤسس أكاديمية المتر',
    bio:
        'Counselor Dr. Wael El Metr is a distinguished jurist, international arbitrator, and legal scholar with over 15 years of academic and courtroom experience in civil and criminal jurisprudence. Founder of EL METR Academy, he established an uncompromising educational paradigm fusing deep university doctrinal rigor with elite forensic advocacy and strategic judicial argumentation.',
    bioAr:
        'المستشار الدكتور وائل المتر، فقيه ومحاضر قانوني ومحكم دولي ذو خبرة أكاديمية وتطبيقية تزيد عن 15 عاماً في تدريس وتأصيل علوم القانون الجنائي والمدني والمرافعات. أسس أكاديمية المتر لتقديم منهج تعليمي رصين يجمع بين العمق الفقهي الأكاديمي، والبراعة العملية في الترافع أمام المحاكم وصياغة الدفوع القانونية الاستراتيجية.',
    imagePath: AppConstants.imgCharacterArt,
    credentials: [
      'Ph.D. in Law',
      'International Arbitrator',
      'Senior Legal Lecturer',
      'Author of EL METR Series',
    ],
    credentialsAr: [
      'دكتوراه في القانون',
      'محكم دولي معتمد',
      'محاضر قانوني رائد',
      'مؤلف سلسلة المتر القانونية',
    ],
  );

  bool get isRsvpConfirmed => _isRsvpConfirmed;
  bool get isLoading => _isLoading;
  bool get isBioExpanded => _isBioExpanded;
  InstructorProfile get instructor => _instructor;

  void toggleRsvp() {
    _isRsvpConfirmed = !_isRsvpConfirmed;
    notifyListeners();
  }

  void toggleBioExpansion() {
    _isBioExpanded = !_isBioExpanded;
    notifyListeners();
  }

  Future<void> refreshDashboard() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    _isLoading = false;
    notifyListeners();
  }
}
