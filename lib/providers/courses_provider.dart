import 'package:flutter/material.dart';
import '../models/education_category.dart';
import '../models/academic_level.dart';
import '../models/subject.dart';
import '../models/lesson.dart';
import '../models/subject_video.dart';
import '../models/academic_material.dart';
import '../models/course.dart';
import '../core/constants.dart';

class CoursesProvider extends ChangeNotifier {
  String _selectedEducationType =
      'lisence'; // 'lisence', 'diploma', 'vocational'
  String _selectedAcademicLevel =
      'year_3'; // 'year_1', 'year_2', 'year_3', 'year_4'
  String _searchQuery = '';
  String? _selectedSubjectId;

  late final List<EducationCategory> _educationCategories;

  CoursesProvider() {
    _educationCategories = _buildAcademicData();
  }

  String get selectedEducationType => _selectedEducationType;
  String get selectedAcademicLevel => _selectedAcademicLevel;
  String get searchQuery => _searchQuery;
  String? get selectedSubjectId => _selectedSubjectId;
  List<EducationCategory> get educationCategories => _educationCategories;

  // Selected Category Object
  EducationCategory get currentEducationCategory {
    return _educationCategories.firstWhere(
      (cat) => cat.id == _selectedEducationType,
      orElse: () => _educationCategories.first,
    );
  }

  // Available Academic Levels for selected category
  List<AcademicLevel> get availableLevels => currentEducationCategory.levels;

  // Selected Level Object
  AcademicLevel get currentAcademicLevel {
    final levels = availableLevels;
    return levels.firstWhere(
      (lvl) => lvl.id == _selectedAcademicLevel,
      orElse: () => levels.isNotEmpty
          ? levels.first
          : _educationCategories.first.levels.first,
    );
  }

  // Subjects for selected Level (with search filter)
  List<Subject> get currentSubjects {
    final list = currentAcademicLevel.subjects;
    if (_searchQuery.trim().isEmpty) {
      return list;
    }
    final q = _searchQuery.trim().toLowerCase();
    return list.where((subj) {
      final name = subj.name.toLowerCase();
      final nameAr = subj.nameAr?.toLowerCase() ?? '';
      final code = subj.code.toLowerCase();
      final inst = subj.instructor.toLowerCase();
      final instAr = subj.instructorAr?.toLowerCase() ?? '';
      return name.contains(q) ||
          nameAr.contains(q) ||
          code.contains(q) ||
          inst.contains(q) ||
          instAr.contains(q);
    }).toList();
  }

  // All subjects across all levels (flat list helper)
  List<Subject> get allSubjects {
    final List<Subject> list = [];
    for (final cat in _educationCategories) {
      for (final lvl in cat.levels) {
        list.addAll(lvl.subjects);
      }
    }
    return list;
  }

  // Get Subject by ID
  Subject? getSubjectById(String id) {
    for (final cat in _educationCategories) {
      for (final lvl in cat.levels) {
        for (final s in lvl.subjects) {
          if (s.id == id) return s;
        }
      }
    }
    return null;
  }

  // Legacy Course bridge for backward-compatibility with routes, tests, and payment
  Course? getCourseById(String id) {
    final subj = getSubjectById(id);
    if (subj != null) {
      return _subjectToCourse(subj);
    }
    // Check fallback by matching id directly or default
    return _legacyCourses.firstWhere(
      (c) => c.id == id,
      orElse: () => _legacyCourses.first,
    );
  }

  List<Course> get allCourses {
    final list = allSubjects.map((s) => _subjectToCourse(s)).toList();
    if (list.isEmpty) {
      return _legacyCourses;
    }
    return list;
  }

  void markEnrolled(String courseId) {
    notifyListeners();
  }

  List<Course> get filteredCourses {
    return currentSubjects.map((s) => _subjectToCourse(s)).toList();
  }

  String get selectedCategory => _selectedEducationType;

  void setCategory(String categoryId) {
    setEducationType(categoryId);
  }

  void setEducationType(String categoryId) {
    _selectedEducationType = categoryId;
    final cat = currentEducationCategory;
    if (cat.levels.isNotEmpty) {
      // Pick first level of the new category if current not present
      if (!cat.levels.any((l) => l.id == _selectedAcademicLevel)) {
        _selectedAcademicLevel = cat.levels.first.id;
      }
    }
    notifyListeners();
  }

  void setAcademicLevel(String levelId) {
    _selectedAcademicLevel = levelId;
    notifyListeners();
  }

  void selectSubject(String? subjectId) {
    _selectedSubjectId = subjectId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  // Helper converter from Subject to Course for backward-compatible screens
  Course _subjectToCourse(Subject s) {
    return Course(
      id: s.id,
      title: s.name,
      titleAr: s.nameAr,
      instructor: s.instructor,
      instructorAr: s.instructorAr,
      category: s.categoryId,
      categoryAr: s.levelName,
      lessonsCount: s.classes.length,
      hoursCount: s.hoursCount,
      rating: s.rating,
      studentsCount: s.studentsCount,
      progress: s.progress,
      isEnrolled: s.isEnrolled,
      imagePath: s.imagePath,
      description: s.description,
      descriptionAr: s.descriptionAr,
      level: s.levelName,
      tag: s.code,
      priceEgp: 1800,
      modules: [
        CourseModule(
          id: '${s.id}-mod1',
          title: 'Classes & Sessions Module',
          titleAr: 'الحصص والمحاضرات الأساسية',
          statusTag: s.progress > 0 ? 'Current ▶' : 'Ready',
          lessons: s.classes,
        ),
      ],
    );
  }

  // Mock Data Definition
  List<EducationCategory> _buildAcademicData() {
    // -------------------------------------------------------------
    // 1. ليسانس الحقوق (LL.B. Bachelor of Laws)
    // -------------------------------------------------------------
    final year1Subjects = [
      Subject(
        id: 'law-101',
        categoryId: 'lisence',
        levelId: 'year_1',
        levelName: 'الفرقة الأولى',
        levelNameAr: 'الفرقة الأولى',
        name: 'Introduction to Legal Science',
        nameAr: 'المدخل للعلوم القانونية (نظرية القانون والحق)',
        code: 'LAW-101',
        term: 'الفصل الدراسي الأول',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Comprehensive grounding in the theory of rule of law, legal sources, interpretation, and the classification of subjective rights.',
        descriptionAr:
            'التأصيل الشامل لنظرية القانون وخصائص القاعدة القانونية ومصادرها، ونظرية الحق وأشخاصه ومحله وحمايته القانونية.',
        imagePath: AppConstants.imgCatalogComposure,
        hoursCount: 32,
        rating: 4.9,
        studentsCount: 1800,
        progress: 0,
        isEnrolled: false,
        classes: [
          const Lesson(
            id: 'l101-1',
            courseId: 'law-101',
            title: 'Foundations of the Legal Rule',
            titleAr: 'مفهوم القاعدة القانونية وخصائصها الإلزامية',
            duration: '22:15',
            lessonNumber: 1,
            isCompleted: false,
            overview:
                'General theory of law and distinguishing legal rules from social norms.',
            overviewAr:
                'النظرية العامة للقانون والتمييز بين القواعد القانونية وقواعد الأخلاق والمجاملات.',
          ),
          const Lesson(
            id: 'l101-2',
            courseId: 'law-101',
            title: 'Classification of Public & Private Law',
            titleAr: 'تقسيمات القانون إلى عام وخاص ومعايير التفرقة',
            duration: '25:40',
            lessonNumber: 2,
            isCompleted: false,
          ),
        ],
        videos: [
          const SubjectVideo(
            id: 'v101-1',
            subjectId: 'law-101',
            title: 'Legal Rule Character & Sanction Dynamics',
            titleAr: 'شرح تطبيقي: الجزاء القانوني وصوره المختلفة',
            duration: '38:10',
            thumbnailUrl: AppConstants.imgCatalogComposure,
          ),
        ],
        books: [
          const AcademicMaterial(
            id: 'b101-1',
            subjectId: 'law-101',
            subjectName: 'المدخل للعلوم القانونية',
            subjectNameAr: 'المدخل للعلوم القانونية',
            title: 'The Sovereign Primer in Legal Sciences',
            titleAr: 'الوجيز في المدخل للعلوم القانونية - د. وائل المتر',
            type: AcademicMaterialType.book,
            fileSize: '18.4 MB',
            pageCount: 310,
            author: 'Dean Wael El Metr',
            authorAr: 'المستشار د. وائل المتر',
            coverImage: AppConstants.imgCatalogComposure,
          ),
        ],
        notes: [
          const AcademicMaterial(
            id: 'n101-1',
            subjectId: 'law-101',
            subjectName: 'المدخل للعلوم القانونية',
            title: 'Executive Revision Notes: Legal Theory',
            titleAr: 'مذكرة المراجعة المركزة ونماذج الامتحانات المقالية',
            type: AcademicMaterialType.handout,
            fileSize: '6.2 MB',
            pageCount: 64,
            author: 'Dean Wael El Metr',
            authorAr: 'المستشار د. وائل المتر',
            coverImage: AppConstants.imgCardFront,
          ),
        ],
      ),
      Subject(
        id: 'law-102',
        categoryId: 'lisence',
        levelId: 'year_1',
        levelName: 'الفرقة الأولى',
        name: 'Constitutional Law & Political Systems',
        nameAr: 'القانون الدستوري والأنظمة السياسية',
        code: 'LAW-102',
        term: 'الفصل الدراسي الأول',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Constitutional supremacy, constitutional review, political systems, and constitutional rights guarantees.',
        descriptionAr:
            'مبدأ سمو الدستور، والرقابة على دستورية القوانين، وفصل السلطات، والضمانات الدستورية للحريات العامة.',
        imagePath: AppConstants.imgCatalogProtocol,
        hoursCount: 28,
        rating: 4.8,
        studentsCount: 1650,
      ),
      Subject(
        id: 'law-103',
        categoryId: 'lisence',
        levelId: 'year_1',
        levelName: 'الفرقة الأولى',
        name: 'Criminology & Penology',
        nameAr: 'علم الإجرام وعلم العقاب',
        code: 'LAW-103',
        term: 'الفصل الدراسي الثاني',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Etiology of criminal behavior, social factors of crime, and penological systems.',
        descriptionAr:
            'تفسير الظاهرة الإجرامية والعوامل الدافعة للجريمة، والأنظمة العقابية الحديثة والمعاملة العقابية.',
        imagePath: AppConstants.imgCoursePsychology,
        hoursCount: 26,
        rating: 4.9,
        studentsCount: 1580,
      ),
    ];

    final year2Subjects = [
      Subject(
        id: 'law-201',
        categoryId: 'lisence',
        levelId: 'year_2',
        levelName: 'الفرقة الثانية',
        name: 'Civil Law: Sources & Provisions of Obligations',
        nameAr: 'القانون المدني (مصادر وأحكام الالتزام)',
        code: 'LAW-201',
        term: 'ممتد على مدار العام',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'General theory of contract, tortious liability, unjust enrichment, and modes of execution.',
        descriptionAr:
            'النظرية العامة للعقد وشروط صحته وبطلانه، والمسؤولية التقصيرية، والإثراء بلا سبب، وضمانات تنفيذ الالتزام.',
        imagePath: AppConstants.imgCatalogRhetoric,
        hoursCount: 42,
        rating: 4.9,
        studentsCount: 1950,
      ),
      Subject(
        id: 'law-202',
        categoryId: 'lisence',
        levelId: 'year_2',
        levelName: 'الفرقة الثانية',
        name: 'General Criminal Law',
        nameAr: 'القانون الجنائي (القسم العام)',
        code: 'LAW-202',
        term: 'ممتد على مدار العام',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'General theory of crime and punishment: actus reus, mens rea, justifications, and excuses.',
        descriptionAr:
            'النظرية العامة للجريمة والعقوبة: الركن المادي والمعنوي، وأسباب الإباحة وموانع المسؤولية والعقاب.',
        imagePath: AppConstants.imgFeaturedArchitectural,
        hoursCount: 38,
        rating: 5.0,
        studentsCount: 2100,
      ),
      Subject(
        id: 'law-203',
        categoryId: 'lisence',
        levelId: 'year_2',
        levelName: 'الفرقة الثانية',
        name: 'Administrative Law',
        nameAr: 'القانون الإداري (التنظيم الإداري والنشاط الإداري)',
        code: 'LAW-203',
        term: 'الفصل الدراسي الأول',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Administrative centralization, public utility, police power, and administrative contracts.',
        descriptionAr:
            'المركزية واللامركزية الإدارية، والمرافق العامة، والضبط الإداري، والقرارات والعقود الإدارية.',
        imagePath: AppConstants.imgCourseStrategic,
        hoursCount: 30,
        rating: 4.8,
        studentsCount: 1720,
      ),
    ];

    // -------------------------------------------------------------
    // الفرقة الثالثة (Third Year) - FEATURED PRIMARY LEVEL
    // -------------------------------------------------------------
    final year3Subjects = [
      Subject(
        id: 'architectural-discipline', // matches existing course ID for seamless integration
        categoryId: 'lisence',
        levelId: 'year_3',
        levelName: 'الفرقة الثالثة',
        levelNameAr: 'الفرقة الثالثة',
        name: 'Criminal Law: Special Section',
        nameAr: 'القانون الجنائي (القسم الخاص - جرائم الأشخاص والأموال)',
        code: 'LAW-301',
        term: 'الفصل الدراسي الأول',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Deep doctrinal and judicial analysis of crimes against persons (homicide, assault) and crimes against property (theft, fraud, breach of trust) with courtroom procedural defenses.',
        descriptionAr:
            'دراسة تأصيلية وتطبيقية لجرائم الاعتداء على الأشخاص (القتل العمد، الضرب المفضي للموت) وجرائم الاعتداء على الأموال (السرقة، النصب، خيانة الأمانة) والجرائم المضرة بالمصلحة العامة مع تطبيقات النقض والدفوع الجنائية.',
        imagePath: AppConstants.imgFeaturedArchitectural,
        hoursCount: 36,
        rating: 5.0,
        studentsCount: 2450,
        progress: 68,
        isEnrolled: true,
        classes: [
          const Lesson(
            id: 'l1',
            courseId: 'architectural-discipline',
            title: 'Homicide: Actus Reus & Causation Lineage',
            titleAr: 'الحصة ٠١: أركان جريمة القتل العمد ورابطة السببية',
            duration: '24:15',
            lessonNumber: 1,
            isCompleted: true,
            overview:
                'Establishing the material element in homicide, direct and interrupted causation, and pathological contributions under criminal jurisprudence.',
            overviewAr:
                'تأصيل الركن المادي في جريمة القتل العمد، ومعايير رابطة السببية بين الفعل والوفاة، ودور العوامل الشاذة والمتدخلة.',
            maxims: [
              'Causation breaks only when external intervening causes overpower the initial act.',
              'The burden of intent rests irrevocably upon the prosecution dossier.',
            ],
            videoPoster: AppConstants.imgFeaturedArchitectural,
          ),
          const Lesson(
            id: 'l2',
            courseId: 'architectural-discipline',
            title: 'Premeditation & Ambush: Judicial Criteria',
            titleAr: 'الحصة ٠٢: ظرف سبق الإصرار والترصد في قضاء محكمة النقض',
            duration: '28:40',
            lessonNumber: 2,
            isCompleted: true,
            overview:
                'Distinguishing the psychological composure required for premeditation from immediate rage.',
            overviewAr:
                'التمييز الجوهري بين التروي والهدوء النفسي المكون لسبق الإصرار وبين ثورة الغضب الآنية وفق أحكام النقض.',
            maxims: [
              'Premeditation is a state of psychological stillness, not merely a lapse of time.',
            ],
            videoPoster: AppConstants.imgCourseStrategic,
          ),
          const Lesson(
            id: 'l3',
            courseId: 'architectural-discipline',
            title: 'Property Offenses: The Element of Seizure in Theft',
            titleAr: 'الحصة ٠٣: الركن المادي في جريمة السرقة ومفهوم الاختلاس',
            duration: '22:10',
            lessonNumber: 3,
            isCompleted: false,
            isCurrent: true,
            overview:
                'The legal mechanics of involuntary property transfer, constructive possession, and consent defects.',
            overviewAr:
                'الآلية الدقيقة لاختلاس المنقول المملوك للغير، ونظرية الحيازة الناقصة والكاملة في جرائم الأموال.',
            maxims: [
              'Constructive delivery negates the element of felonious seizure.',
            ],
            videoPoster: AppConstants.imgCatalogComposure,
          ),
          const Lesson(
            id: 'l4',
            courseId: 'architectural-discipline',
            title: 'Fraud & False Representation Schemes',
            titleAr: 'الحصة ٠٤: جريمة النصب وطرق التدليس والصفات الكاذبة',
            duration: '26:30',
            lessonNumber: 4,
            isCompleted: false,
            overview:
                'Fraudulent schemes, exploitation of false qualities, and the demarcation between mere civil breach and penal fraud.',
            overviewAr:
                'الطرق الاحتيالية واتخاذ صفة غير صحيحة، والحد الفاصل بين الإخلال المدني بالعقد وجريمة النصب الجنائية.',
          ),
        ],
        videos: [
          const SubjectVideo(
            id: 'v1',
            subjectId: 'architectural-discipline',
            title: 'Courtroom Advocacy: Dissecting the Autopsy Report',
            titleAr:
                'المحاضرة المرئية ٠١: تفكيك تقرير الطب الشرعي ودحض السببية',
            duration: '34:20',
            thumbnailUrl: AppConstants.imgFeaturedArchitectural,
            viewsCount: 3120,
            description:
                'Practical clinical dissection of autopsy timelines and bullet trajectory rebuttal.',
            descriptionAr:
                'شرح تطبيقي لطرق مناقشة الطبيب الشرعي ودحض أدلة الإدانة أمام محكمة الجنايات.',
          ),
          const SubjectVideo(
            id: 'v2',
            subjectId: 'architectural-discipline',
            title: 'Criminal Defenses Masterclass: Procedural Nullity',
            titleAr:
                'المحاضرة المرئية ٠٢: الدفوع الجنائية الجوهرية وبطلان التلبس',
            duration: '42:50',
            thumbnailUrl: AppConstants.imgCourseStrategic,
            viewsCount: 2840,
            description:
                'Tactical formulation of constitutional arrest nullity and search warrant defects.',
            descriptionAr:
                'الصياغة الاستراتيجية لدفع بطلان القبض والتفتيش وما يترتب عليه من استبعاد الأدلة.',
          ),
          const SubjectVideo(
            id: 'v3',
            subjectId: 'architectural-discipline',
            title: 'White-Collar Defense: Breach of Trust & Accounting Audits',
            titleAr:
                'المحاضرة المرئية ٠٣: جريمة خيانة الأمانة وعقود الأمانة الخمسة',
            duration: '31:15',
            thumbnailUrl: AppConstants.imgCatalogRhetoric,
            viewsCount: 2410,
          ),
        ],
        books: [
          const AcademicMaterial(
            id: 'b-crim-1',
            subjectId: 'architectural-discipline',
            subjectName: 'القانون الجنائي (القسم الخاص)',
            levelName: 'الفرقة الثالثة',
            title: 'Criminal Law Special Section: The Master Textbook',
            titleAr:
                'الوجيز في القانون الجنائي (القسم الخاص) - الطبعة الأكاديمية المعتمدة',
            type: AcademicMaterialType.book,
            fileSize: '28.4 MB',
            pageCount: 420,
            author: 'Dean Wael El Metr',
            authorAr: 'المستشار د. وائل المتر',
            coverImage: AppConstants.imgFeaturedArchitectural,
            description:
                'The definitive accredited treatise on crimes against persons and property with complete Court of Cassation indexation.',
            descriptionAr:
                'المرجع الأكاديمي المعتمد الشامل لجرائم الاعتداء على الأشخاص والأموال والمفاهيم الفقهية وأحدث مبادئ محكمة النقض.',
          ),
        ],
        notes: [
          const AcademicMaterial(
            id: 'n-crim-1',
            subjectId: 'architectural-discipline',
            subjectName: 'القانون الجنائي (القسم الخاص)',
            levelName: 'الفرقة الثالثة',
            title: 'Special Criminal Dossier: Exam Bank & Cassation Precedents',
            titleAr: 'مذكرة المراجعة النهائية وبنك تطبيقات محكمة النقض',
            type: AcademicMaterialType.handout,
            fileSize: '12.8 MB',
            pageCount: 94,
            author: 'Dean Wael El Metr',
            authorAr: 'المستشار د. وائل المتر',
            coverImage: AppConstants.imgCardFront,
            description:
                'Comprehensive exam briefs, model answers, and essential case study breakdowns.',
            descriptionAr:
                'ملخص شامل لجميع موضوعات الامتحان والأسئلة المقالية المتوقعة مع صيغ الدفوع القانونية النموذجية.',
          ),
          const AcademicMaterial(
            id: 'n-crim-2',
            subjectId: 'architectural-discipline',
            subjectName: 'القانون الجنائي (القسم الخاص)',
            levelName: 'الفرقة الثالثة',
            title: 'Summary Tables of Penal Offenses Elements',
            titleAr: 'جداول الفروق الجوهرية ومقارنات أركان الجرائم والعقوبات',
            type: AcademicMaterialType.summary,
            fileSize: '5.2 MB',
            pageCount: 38,
            author: 'Dean Wael El Metr',
            authorAr: 'المستشار د. وائل المتر',
            coverImage: AppConstants.imgCatalogComposure,
          ),
        ],
      ),
      Subject(
        id: 'law-302',
        categoryId: 'lisence',
        levelId: 'year_3',
        levelName: 'الفرقة الثالثة',
        levelNameAr: 'الفرقة الثالثة',
        name: 'Civil & Commercial Procedures Law',
        nameAr: 'قانون المرافعات المدنية والتجارية',
        code: 'LAW-302',
        term: 'ممتد على مدار العام',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Judicial jurisdiction, litigation mechanics, pleadings, nullity of procedures, appeals, and judgment execution.',
        descriptionAr:
            'الاختصاص القضائي النوعي والقيمي، ونظرية الدعوى والخصومة القضائية، وإجراءات المرافعة، وبطلان الإعلانات، وطرق الطعن في الأحكام.',
        imagePath: AppConstants.imgCourseStrategic,
        hoursCount: 38,
        rating: 4.9,
        studentsCount: 2200,
        progress: 30,
        isEnrolled: true,
        classes: [
          const Lesson(
            id: 'l-plead-1',
            courseId: 'law-302',
            title: 'Rules of Judicial Jurisdiction & Exceptions',
            titleAr: 'قواعد الاختصاص القضائي والدفع بعدم الاختصاص',
            duration: '26:00',
            lessonNumber: 1,
            isCompleted: true,
          ),
          const Lesson(
            id: 'l-plead-2',
            courseId: 'law-302',
            title: 'Summons Nullity & Process Defects',
            titleAr: 'بطلان صحف الدعاوى وإعلانات الأوراق القضائية',
            duration: '29:15',
            lessonNumber: 2,
            isCompleted: false,
          ),
        ],
        videos: [
          const SubjectVideo(
            id: 'v-plead-1',
            subjectId: 'law-302',
            title: 'Mastering Courtroom Pleadings & In limine litis Defenses',
            titleAr:
                'المحاضرة المرئية: الدفوع الشكلية وترتيب إبدائها قبل التكلم في الموضوع',
            duration: '36:40',
            thumbnailUrl: AppConstants.imgCourseStrategic,
          ),
        ],
        books: [
          const AcademicMaterial(
            id: 'b-plead-1',
            subjectId: 'law-302',
            subjectName: 'قانون المرافعات',
            title: 'The Procedures Sovereign Codex',
            titleAr: 'أصول قانون المرافعات المدنية والتجارية - د. وائل المتر',
            type: AcademicMaterialType.book,
            fileSize: '24.1 MB',
            pageCount: 360,
            author: 'Dean Wael El Metr',
            authorAr: 'المستشار د. وائل المتر',
            coverImage: AppConstants.imgCourseStrategic,
          ),
        ],
        notes: [
          const AcademicMaterial(
            id: 'n-plead-1',
            subjectId: 'law-302',
            subjectName: 'قانون المرافعات',
            title: 'Procedures Comprehensive Handout & Question Bank',
            titleAr:
                'مذكرة المرافعات الذهبية: الخصومة والدعوى والطعن في الأحكام',
            type: AcademicMaterialType.handout,
            fileSize: '9.5 MB',
            pageCount: 78,
            author: 'Dean Wael El Metr',
            authorAr: 'المستشار د. وائل المتر',
            coverImage: AppConstants.imgCardBack,
          ),
        ],
      ),
      Subject(
        id: 'law-303',
        categoryId: 'lisence',
        levelId: 'year_3',
        levelName: 'الفرقة الثالثة',
        levelNameAr: 'الفرقة الثالثة',
        name: 'Civil Law: Nominate Contracts',
        nameAr: 'القانون المدني (العقود المسماة - البيع والإيجار والتأمين)',
        code: 'LAW-303',
        term: 'ممتد على مدار العام',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Contract of sale, obligations of buyer and seller, lease agreements, tenancy protections, and insurance contracts.',
        descriptionAr:
            'أركان عقد البيع وآثاره والتزامات البائع والمشتري، وضمان العيوب الخفية، وعقد الإيجار وحماية المستأجر، وعقد التأمين.',
        imagePath: AppConstants.imgCourseExecutive,
        hoursCount: 34,
        rating: 4.8,
        studentsCount: 2050,
        progress: 0,
        classes: [
          const Lesson(
            id: 'l-civil-1',
            courseId: 'law-303',
            title: 'Contract of Sale: Essential Conditions & Hidden Defects',
            titleAr: 'عقد البيع: التزام البائع بضمان العيوب الخفية والاستحقاق',
            duration: '24:50',
            lessonNumber: 1,
            isCompleted: false,
          ),
        ],
        videos: [
          const SubjectVideo(
            id: 'v-civil-1',
            subjectId: 'law-303',
            title: 'Tenancy Disputes & Contract Drafting in Civil Law',
            titleAr:
                'المحاضرة المرئية: المنازعات الإيجارية وصياغة عقود البيع الرصينة',
            duration: '32:10',
            thumbnailUrl: AppConstants.imgCourseExecutive,
          ),
        ],
        books: [
          const AcademicMaterial(
            id: 'b-civil-1',
            subjectId: 'law-303',
            subjectName: 'القانون المدني (العقود المسماة)',
            title: 'Nominate Contracts Sovereign Treatise',
            titleAr: 'شرح العقود المسماة: البيع والإيجار - د. وائل المتر',
            type: AcademicMaterialType.book,
            fileSize: '26.8 MB',
            pageCount: 395,
            author: 'Dean Wael El Metr',
            authorAr: 'المستشار د. وائل المتر',
            coverImage: AppConstants.imgCourseExecutive,
          ),
        ],
        notes: [
          const AcademicMaterial(
            id: 'n-civil-1',
            subjectId: 'law-303',
            subjectName: 'القانون المدني',
            title: 'Civil Contracts Summary Dossier',
            titleAr: 'المذكرة الشاملة في العقود المسماة وضمانات المشتري',
            type: AcademicMaterialType.handout,
            fileSize: '8.4 MB',
            pageCount: 72,
            author: 'Dean Wael El Metr',
            authorAr: 'المستشار د. وائل المتر',
            coverImage: AppConstants.imgCatalogProtocol,
          ),
        ],
      ),
      Subject(
        id: 'law-304',
        categoryId: 'lisence',
        levelId: 'year_3',
        levelName: 'الفرقة الثالثة',
        levelNameAr: 'الفرقة الثالثة',
        name: 'Labor Law & Social Insurance',
        nameAr: 'قانون العمل والتأمينات الاجتماعية',
        code: 'LAW-304',
        term: 'الفصل الدراسي الثاني',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Individual and collective labor contracts, wrongful termination, workers rights, and social insurance systems.',
        descriptionAr:
            'عقد العمل الفردي والمشترك، والفصل التعسفي والتعويضات، وحقوق العمال والتزامات أصحاب الأعمال، ونظام التأمينات الاجتماعية.',
        imagePath: AppConstants.imgCatalogProtocol,
        hoursCount: 26,
        rating: 4.7,
        studentsCount: 1850,
      ),
    ];

    final year4Subjects = [
      Subject(
        id: 'law-401',
        categoryId: 'lisence',
        levelId: 'year_4',
        levelName: 'الفرقة الرابعة',
        name: 'Criminal Procedure Code',
        nameAr: 'قانون الإجراءات الجنائية',
        code: 'LAW-401',
        term: 'ممتد على مدار العام',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Initiation of public prosecution, preliminary investigation, trial court proceedings, cassation appeals, and execution.',
        descriptionAr:
            'تحريك الدعوى الجنائية، والتحقيق الابتدائي وسلطات النيابة العامة، وإجراءات المحاكمة وطرق الطعن بالنقض وإعادة النظر.',
        imagePath: AppConstants.imgFeaturedArchitectural,
        hoursCount: 44,
        rating: 5.0,
        studentsCount: 2600,
        progress: 0,
      ),
      Subject(
        id: 'law-402',
        categoryId: 'lisence',
        levelId: 'year_4',
        levelName: 'الفرقة الرابعة',
        name: 'Commercial Law: Banking Operations & Bankruptcy',
        nameAr: 'القانون التجاري (العمليات المصرفية والإفلاس)',
        code: 'LAW-402',
        term: 'الفصل الدراسي الأول',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Banking contracts, letters of credit, promissory notes, bankruptcy proceedings, and corporate insolvency.',
        descriptionAr:
            'عقود العمليات المصرفية، والاعتمادات المستندية، والأوراق التجارية، ونظام الإفلاس والصلح الواقي والتسوية القضائية.',
        imagePath: AppConstants.imgCatalogRhetoric,
        hoursCount: 36,
        rating: 4.8,
        studentsCount: 2150,
      ),
      Subject(
        id: 'law-403',
        categoryId: 'lisence',
        levelId: 'year_4',
        levelName: 'الفرقة الرابعة',
        name: 'Private International Law',
        nameAr: 'القانون الدولي الخاص (الجنسية وتنازع القوانين)',
        code: 'LAW-403',
        term: 'ممتد على مدار العام',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Nationality laws, domicile, legal status of aliens, conflict of laws, and international jurisdiction.',
        descriptionAr:
            'قواعد الجنسية واكتسابها وفقدها، ومركز الأجانب، وقواعد الإسناد وحل تنازع القوانين والاختصاص القضائي الدولي.',
        imagePath: AppConstants.imgCourseStrategic,
        hoursCount: 38,
        rating: 4.9,
        studentsCount: 2300,
      ),
    ];

    // -------------------------------------------------------------
    // 2. دبلومة الدراسات العليا (Postgraduate Diplomas)
    // -------------------------------------------------------------
    final diplomaSubjects = [
      Subject(
        id: 'dip-crim-1',
        categoryId: 'diploma',
        levelId: 'dip_criminal',
        levelName: 'دبلوم العلوم الجنائية',
        name: 'Advanced Forensic Jurisprudence',
        nameAr: 'الجرائم الاقتصادية والسيبرانية في التشريع المقارن',
        code: 'DIP-CRIM-501',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Postgraduate comparative study of financial crimes, digital forensic evidence, and anti-money laundering frameworks.',
        descriptionAr:
            'دراسة فقهية مقارنة في جرائم غسل الأموال، والفساد المالي، والجرائم الإلكترونية، والتحقيق الجنائي الرقمي.',
        imagePath: AppConstants.imgFeaturedArchitectural,
        hoursCount: 40,
        rating: 5.0,
        studentsCount: 680,
      ),
      Subject(
        id: 'dip-public-1',
        categoryId: 'diploma',
        levelId: 'dip_public',
        levelName: 'دبلوم القانون العام',
        name: 'Administrative Contracts & State Litigation',
        nameAr: 'المنازعات الإدارية وعقود الدولة الاستثمارية',
        code: 'DIP-PUB-502',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Advisory insights on State Council jurisdiction, BOT concession agreements, and public procurement disputes.',
        descriptionAr:
            'قضاء مجلس الدولة، ومنازعات عقود الـ BOT، وإلغاء القرارات الإدارية، ودعاوى التعويض عن أعمال الإدارة.',
        imagePath: AppConstants.imgCatalogProtocol,
        hoursCount: 36,
        rating: 4.9,
        studentsCount: 520,
      ),
    ];

    // -------------------------------------------------------------
    // 3. تدريب مهني قانوني (Vocational Practical Legal Training)
    // -------------------------------------------------------------
    final vocationalSubjects = [
      Subject(
        id: 'voc-adv-1',
        categoryId: 'vocational',
        levelId: 'voc_advocacy',
        levelName: 'المحاماة وصياغة العقود',
        name: 'Elite Courtroom Advocacy & Strategic Defenses',
        nameAr:
            'صناعة المحامي المحترف وفن الترافع أمام محاكم الجنايات والاستئناف',
        code: 'VOC-ADV-601',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Applied laboratory in drafting statement of claims, oral pleadings, cross-examining expert witnesses, and cassation petitions.',
        descriptionAr:
            'ورشة تطبيقية في صياغة صحف الدعاوى والمذكرات القضائية، وفن الارتجال والمرافعة الشفوية، وكتابة طعون النقض.',
        imagePath: AppConstants.imgCatalogRhetoric,
        hoursCount: 48,
        rating: 5.0,
        studentsCount: 1450,
      ),
      Subject(
        id: 'voc-arb-1',
        categoryId: 'vocational',
        levelId: 'voc_arbitration',
        levelName: 'التحكيم التجاري الدولي',
        name: 'International Commercial Arbitration & FIDIC',
        nameAr: 'التحكيم التجاري الدولي ومنازعات عقود الفيديك (FIDIC)',
        code: 'VOC-ARB-602',
        instructor: 'Dean Wael El Metr',
        instructorAr: 'المستشار د. وائل المتر',
        description:
            'Drafting arbitration clauses, selecting tribunals, handling ICC/CRCICA proceedings, and enforcement of arbitral awards.',
        descriptionAr:
            'صياغة اتفاق التحكيم، وإجراءات التحكيم المؤسسي (CRCICA / ICC)، وصياغة أحكام التحكيم وإجراءات تنفيذها وبطلانها.',
        imagePath: AppConstants.imgCourseStrategic,
        hoursCount: 40,
        rating: 4.9,
        studentsCount: 920,
      ),
    ];

    return [
      EducationCategory(
        id: 'lisence',
        name: 'LL.B. (Bachelor)',
        nameAr: 'ليسانس الحقوق',
        description:
            'Four-year comprehensive university legal education from foundations to executive bar readiness.',
        descriptionAr:
            'المرحلة الجامعية الأساسية مقسمة إلى الفرق الأربع لإعداد رجل القانون المتمكن فقهياً وعملياً.',
        icon: Icons.school_outlined,
        levels: [
          AcademicLevel(
            id: 'year_1',
            categoryId: 'lisence',
            name: 'First Year',
            nameAr: 'الفرقة الأولى',
            subtitle: 'Foundations of Law & Constitutional Systems',
            subtitleAr: 'المدخل للعلوم القانونية والأنظمة الدستورية',
            order: 1,
            subjects: year1Subjects,
          ),
          AcademicLevel(
            id: 'year_2',
            categoryId: 'lisence',
            name: 'Second Year',
            nameAr: 'الفرقة الثانية',
            subtitle: 'Civil Obligations & General Penal Theory',
            subtitleAr: 'أحكام الالتزام والقانون الجنائي العام والإداري',
            order: 2,
            subjects: year2Subjects,
          ),
          AcademicLevel(
            id: 'year_3',
            categoryId: 'lisence',
            name: 'Third Year',
            nameAr: 'الفرقة الثالثة',
            subtitle: 'Special Criminal Law, Civil Contracts & Procedures',
            subtitleAr: 'الجنائي الخاص، والمرافعات، والعقود المدنية المسماة',
            order: 3,
            subjects: year3Subjects,
          ),
          AcademicLevel(
            id: 'year_4',
            categoryId: 'lisence',
            name: 'Fourth Year',
            nameAr: 'الفرقة الرابعة',
            subtitle:
                'Criminal Procedure, Commercial Law & Private International',
            subtitleAr: 'الإجراءات الجنائية، والقانون التجاري، والدولي الخاص',
            order: 4,
            subjects: year4Subjects,
          ),
        ],
      ),
      EducationCategory(
        id: 'diploma',
        name: 'Postgraduate Diplomas',
        nameAr: 'دبلومات الدراسات العليا',
        description:
            'Specialized advanced legal masterclasses in criminal, public, and private legal sciences.',
        descriptionAr:
            'برامج تمهيدي الماجستير والدراسات العليا المتخصصة في الفقه القانوني المتقدم.',
        icon: Icons.workspace_premium_outlined,
        levels: [
          AcademicLevel(
            id: 'dip_criminal',
            categoryId: 'diploma',
            name: 'Criminal Sciences Diploma',
            nameAr: 'دبلوم العلوم الجنائية',
            subtitle: 'Economic & Cyber Crimes Comparative Frameworks',
            subtitleAr: 'الجرائم الاقتصادية والسيبرانية والأدلة الرقمية',
            order: 1,
            subjects: [diplomaSubjects[0]],
          ),
          AcademicLevel(
            id: 'dip_public',
            categoryId: 'diploma',
            name: 'Public Law Diploma',
            nameAr: 'دبلوم القانون العام',
            subtitle: 'State Contracts & Administrative Jurisdiction',
            subtitleAr: 'المنازعات الإدارية وعقود الدولة الاستثمارية',
            order: 2,
            subjects: [diplomaSubjects[1]],
          ),
        ],
      ),
      EducationCategory(
        id: 'vocational',
        name: 'Vocational Legal Training',
        nameAr: 'التدريب المهني القانوني',
        description:
            'Applied professional simulation laboratories for courtroom pleading, contract drafting, and arbitration.',
        descriptionAr:
            'برامج عملية متقدمة لإعداد المحامي الممارس والمحكم التجاري وصياغة العقود.',
        icon: Icons.gavel_outlined,
        levels: [
          AcademicLevel(
            id: 'voc_advocacy',
            categoryId: 'vocational',
            name: 'Advocacy & Pleadings',
            nameAr: 'المحاماة وصياغة العقود',
            subtitle: 'Courtroom Simulation & Oral Pleading Excellence',
            subtitleAr: 'فنون الترافع العملي وصياغة الدفوع أمام المحاكم',
            order: 1,
            subjects: [vocationalSubjects[0]],
          ),
          AcademicLevel(
            id: 'voc_arbitration',
            categoryId: 'vocational',
            name: 'Commercial Arbitration',
            nameAr: 'التحكيم التجاري الدولي',
            subtitle: 'FIDIC Contracts & Institutional Arbitration',
            subtitleAr: 'إدارة جلسات التحكيم ومنازعات عقود الفيديك',
            order: 2,
            subjects: [vocationalSubjects[1]],
          ),
        ],
      ),
    ];
  }

  // Static legacy courses kept for reference
  static final List<Course> _legacyCourses = [
    Course(
      id: 'architectural-discipline',
      title: 'Criminal Law: Special Section',
      titleAr: 'القانون الجنائي (القسم الخاص)',
      instructor: 'Dean Wael El Metr',
      instructorAr: 'المستشار د. وائل المتر',
      category: 'lisence',
      categoryAr: 'الفرقة الثالثة',
      lessonsCount: 18,
      hoursCount: 24,
      rating: 5.0,
      studentsCount: 2450,
      progress: 68,
      isEnrolled: true,
      imagePath: AppConstants.imgFeaturedArchitectural,
      description:
          'An uncompromising curriculum in penal special section jurisprudence.',
      descriptionAr:
          'دراسة تأصيلية وتطبيقية لجرائم الاعتداء على الأشخاص والأموال.',
      level: 'الفرقة الثالثة',
      tag: 'LAW-301',
      priceEgp: 1800,
    ),
  ];
}
