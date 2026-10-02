import 'package:wael_app/content/director_profile.dart';

/// A fully filled director profile for tests. The app itself ships an empty
/// profile (`kDirectorProfile`); these values exist only here.
const testDirector = DirectorProfile(
  name: 'Test Director',
  nameAr: 'مدير الاختبار',
  title: 'Test title line',
  titleAr: 'سطر عنوان الاختبار',
  badge: 'TEST TAG',
  badgeAr: 'وسم الاختبار',
  bio:
      'Test biography text that is long enough to be clamped to two lines '
      'when collapsed and shown in full when expanded, so the toggle can be '
      'exercised by the widget tests without relying on any real content.',
  bioAr:
      'نص سيرة اختباري طويل بما يكفي ليُقتطع إلى سطرين عند الطي ويظهر كاملاً '
      'عند التوسيع، حتى يمكن اختبار زر التبديل دون الاعتماد على أي محتوى حقيقي.',
  credentials: ['Credential one', 'Credential two'],
  credentialsAr: ['صفة أولى', 'صفة ثانية'],
);
