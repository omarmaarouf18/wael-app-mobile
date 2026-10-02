import 'package:wael_app/content/director_profile.dart';

/// A fully filled director profile for tests, including a biography so the
/// expand/collapse toggle can be exercised. The shipped profile
/// (`kDirectorProfile`) has no biography; these values exist only here.
const testDirector = DirectorProfile(
  name: 'Test Director',
  nameAr: 'مدير الاختبار',
  titles: ['Test title one', 'Test title two'],
  titlesAr: ['لقب اختبار أول', 'لقب اختبار ثان'],
  bio:
      'Test biography text that is long enough to be clamped to two lines '
      'when collapsed and shown in full when expanded, so the toggle can be '
      'exercised by the widget tests without relying on any real content.',
  bioAr:
      'نص سيرة اختباري طويل بما يكفي ليُقتطع إلى سطرين عند الطي ويظهر كاملاً '
      'عند التوسيع، حتى يمكن اختبار زر التبديل دون الاعتماد على أي محتوى حقيقي.',
);
