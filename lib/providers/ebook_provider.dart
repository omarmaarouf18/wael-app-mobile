import 'package:flutter/material.dart';
import '../models/academic_material.dart';
import '../models/ebook.dart';
import '../core/constants.dart';

class EBookProvider extends ChangeNotifier {
  String _activeFilter = 'all'; // 'all', 'books', 'materials', 'personal_notes'
  String _searchQuery = '';

  // 1. ACADEMIC MATERIALS (Official Books & Handouts provided by Academy)
  final List<AcademicMaterial> _academicMaterials = [
    const AcademicMaterial(
      id: 'mat-crim-book',
      subjectId: 'architectural-discipline',
      subjectName: 'Criminal Law (Special Section)',
      subjectNameAr: 'القانون الجنائي (القسم الخاص)',
      levelName: 'Third Year • LL.B.',
      levelNameAr: 'الفرقة الثالثة • ليسانس الحقوق',
      title: 'The Sovereign Litigator Manual: Criminal Jurisprudence',
      titleAr: 'مذكرة المتر: الدليل السيادي في المرافعة والجدل الجنائي',
      type: AcademicMaterialType.book,
      fileFormat: 'PDF',
      fileSize: '34.8 MB',
      pageCount: 384,
      author: 'Dean Wael El Metr',
      authorAr: 'المستشار د. وائل المتر',
      coverImage: AppConstants.imgPoster007,
      fileUrl: 'https://elmetr-academy.com/dossiers/criminal_jurisprudence.pdf',
      isDownloaded: true,
      description:
          'Definitive accredited textbook for 3rd Year criminal law special section.',
      descriptionAr:
          'المصنف الأكاديمي المعتمد في جرائم الاعتداء على الأشخاص والأموال وتطبيقات النقض.',
    ),
    const AcademicMaterial(
      id: 'mat-crim-handout',
      subjectId: 'architectural-discipline',
      subjectName: 'Criminal Law (Special Section)',
      subjectNameAr: 'القانون الجنائي (القسم الخاص)',
      levelName: 'Third Year • LL.B.',
      levelNameAr: 'الفرقة الثالثة • ليسانس الحقوق',
      title: 'Final Revision Dossier: Substantive Defenses & Question Bank',
      titleAr: 'مذكرة المراجعة النهائية وبنك تطبيقات محكمة النقض الجنائية',
      type: AcademicMaterialType.handout,
      fileFormat: 'PDF',
      fileSize: '12.4 MB',
      pageCount: 96,
      author: 'Dean Wael El Metr',
      authorAr: 'المستشار د. وائل المتر',
      coverImage: AppConstants.imgCardFront,
      fileUrl:
          'https://elmetr-academy.com/dossiers/criminal_defenses_revision.pdf',
      isDownloaded: false,
      description: 'Model exam answers and constitutional criminal defenses.',
      descriptionAr:
          'خلاصة المنهج ونماذج الإجابة النموذجية وصيغ الدفوع القانونية المقررة.',
    ),
    const AcademicMaterial(
      id: 'mat-plead-book',
      subjectId: 'law-302',
      subjectName: 'Civil Procedures Law',
      subjectNameAr: 'قانون المرافعات المدنية والتجارية',
      levelName: 'Third Year • LL.B.',
      levelNameAr: 'الفرقة الثالثة • ليسانس الحقوق',
      title: 'Civil & Commercial Procedures: The Systematic Treatise',
      titleAr: 'الوجيز المعتمد في قانون المرافعات المدنية والتجارية',
      type: AcademicMaterialType.book,
      fileFormat: 'PDF',
      fileSize: '26.2 MB',
      pageCount: 320,
      author: 'Dean Wael El Metr',
      authorAr: 'المستشار د. وائل المتر',
      coverImage: AppConstants.imgCourseStrategic,
      fileUrl: 'https://elmetr-academy.com/dossiers/civil_procedures.pdf',
      isDownloaded: false,
    ),
    const AcademicMaterial(
      id: 'mat-plead-handout',
      subjectId: 'law-302',
      subjectName: 'Civil Procedures Law',
      subjectNameAr: 'قانون المرافعات المدنية والتجارية',
      levelName: 'Third Year • LL.B.',
      levelNameAr: 'الفرقة الثالثة • ليسانس الحقوق',
      title: 'Jurisdiction & Nullity of Summons: Practical Summary',
      titleAr: 'مذكرة الاختصاص القضائي والدفع ببطلان صحف الدعاوى',
      type: AcademicMaterialType.summary,
      fileFormat: 'PDF',
      fileSize: '6.8 MB',
      pageCount: 48,
      author: 'Dean Wael El Metr',
      authorAr: 'المستشار د. وائل المتر',
      coverImage: AppConstants.imgCardBack,
      fileUrl: 'https://elmetr-academy.com/dossiers/jurisdiction_nullity.pdf',
      isDownloaded: true,
    ),
    const AcademicMaterial(
      id: 'mat-civil-contracts',
      subjectId: 'law-303',
      subjectName: 'Civil Law: Nominate Contracts',
      subjectNameAr: 'القانون المدني (العقود المسماة)',
      levelName: 'Third Year • LL.B.',
      levelNameAr: 'الفرقة الثالثة • ليسانس الحقوق',
      title: 'Nominate Contracts: Sale, Lease & Tenancy Protections',
      titleAr:
          'المرجع الأكاديمي في العقود المسماة: البيع والإيجار وضمان الاستحقاق',
      type: AcademicMaterialType.book,
      fileFormat: 'PDF',
      fileSize: '29.5 MB',
      pageCount: 360,
      author: 'Dean Wael El Metr',
      authorAr: 'المستشار د. وائل المتر',
      coverImage: AppConstants.imgCourseExecutive,
      fileUrl: 'https://elmetr-academy.com/dossiers/nominate_contracts.pdf',
      isDownloaded: false,
    ),
    const AcademicMaterial(
      id: 'mat-exam-bank',
      subjectId: 'architectural-discipline',
      subjectName: 'Criminal Law & Procedures',
      subjectNameAr: 'القانون الجنائي والمرافعات',
      levelName: 'Third Year • LL.B.',
      levelNameAr: 'الفرقة الثالثة • ليسانس الحقوق',
      title: 'Annual Comprehensive Legal Exam Bank & Model Dossiers',
      titleAr: 'بنك التطبيقات القضائية والامتحانات السابقة الشاملة',
      type: AcademicMaterialType.examDossier,
      fileFormat: 'PDF',
      fileSize: '14.1 MB',
      pageCount: 110,
      author: 'Dean Wael El Metr',
      authorAr: 'المستشار د. وائل المتر',
      coverImage: AppConstants.imgFeaturedArchitectural,
      fileUrl: 'https://elmetr-academy.com/dossiers/exam_bank_3rd_year.pdf',
      isDownloaded: false,
    ),
  ];

  // 2. PERSONAL NOTES (Written by Student)
  final List<StudyNote> _personalNotes = [
    StudyNote(
      id: 'note-1',
      title: 'Keynote Defense Checklist: Premeditation Rebuttal',
      titleAr: 'قائمة التحقق لمرافعة دحض ظرف سبق الإصرار',
      course: 'Criminal Law (Special Section)',
      courseAr: 'القانون الجنائي (القسم الخاص)',
      date: 'Yesterday • 14:30',
      tags: ['#Criminal', '#Cassation', '#Pleading'],
      content:
          '1. Focus on the psychological disturbance at the moment of altercation.\n2. Request hospital admission log to counter calm reflection.\n3. Argue lack of preparation weapons.',
      contentAr:
          '١. التركيز على الاضطراب النفسي وانعدام التروي لحظة المشاجرة.\n٢. طلب ضم دفتر أحوال المستشفى لنفي الإعداد المسبق.\n٣. الدفع بأن السلاح تصادف وجوده في مسرح الواقعة.',
      isPinned: true,
      checklistItems: [
        ChecklistItem(
          text: 'Review autopsy wound depth trajectory',
          isChecked: true,
        ),
        ChecklistItem(
          text: 'Submit memorandum on sudden rage defense',
          isChecked: true,
        ),
        ChecklistItem(
          text: 'Cite Cassation precedent No. 4820/86 JY',
          isChecked: false,
        ),
        ChecklistItem(
          text: 'Request summoning eyewitness for cross-examination',
          isChecked: false,
        ),
      ],
    ),
    StudyNote(
      id: 'note-2',
      title: 'Framing Asymmetries in Commercial Court Pleadings',
      titleAr: 'اختلالات التأطير في منازعات بطلان عقود البيع',
      course: 'Civil Law: Nominate Contracts',
      courseAr: 'القانون المدني (العقود المسماة)',
      date: '3 days ago',
      tags: ['#Civil', '#Contracts', '#Defenses'],
      content:
          'The distinction between patent defect and latent defect in commercial sales: notice within thirty days is a strict limitation of action.',
      contentAr:
          'الحد الفاصل بين العيب الظاهر والعيب الخفي في عقد البيع: إخطار البائع خلال الميعاد القانوني هو دفع بسقوط الحق وليس تقادماً.',
      isPinned: false,
    ),
  ];

  // Legacy E-Books backward compatibility
  final List<EBook> _ebooks = [
    const EBook(
      id: 'book-metr-manual',
      title: 'The Sovereign Litigator Manual',
      titleAr: 'مذكرة المتر: الدليل السيادي في المرافعة والجدل القضائي',
      subtitle: 'Comprehensive Courtroom Strategy & Dialectics',
      subtitleAr: 'الاستراتيجية القضائية الشاملة وفنون الجدل والدحض',
      author: 'Dean Wael El Metr',
      authorAr: 'المستشار د. وائل المتر',
      pagesCount: 384,
      fileSize: '42.8 MB',
      coverImagePath: AppConstants.imgPoster007,
      isOwned: true,
      isLocked: false,
      description:
          'The definitive handbook compiled by Counselor Wael El Saeed.',
      descriptionAr: 'المصنف الشامل المعتمد للمستشار د. وائل المتر.',
      pdfDownloadName: 'El_Metr_Sovereign_Litigator_Manual.pdf',
      chapters: [
        'Chapter I: The Architecture of Courtroom Silence',
        'Chapter II: Framing Asymmetries in Formal Cross-Examination',
      ],
      chaptersAr: [
        'الباب الأول: البنية المعمارية للصمت على منصة الدفاع',
        'الباب الثاني: اختلالات التأطير أثناء الاستجواب المعاكس',
      ],
    ),
  ];

  String get activeFilter => _activeFilter;
  String get searchQuery => _searchQuery;
  List<AcademicMaterial> get academicMaterials => _getFilteredMaterials();
  List<StudyNote> get personalNotes => _personalNotes;
  List<EBook> get ebooks => _ebooks;
  List<EBook> get filteredEbooks => _ebooks;
  List<StudyNote> get filteredNotes => _personalNotes;

  List<AcademicMaterial> _getFilteredMaterials() {
    List<AcademicMaterial> list = _academicMaterials;
    if (_activeFilter == 'books') {
      list = list.where((m) => m.type == AcademicMaterialType.book).toList();
    } else if (_activeFilter == 'handouts' || _activeFilter == 'materials') {
      list = list.where((m) => m.type != AcademicMaterialType.book).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((m) {
        final t = m.title.toLowerCase();
        final ta = m.titleAr?.toLowerCase() ?? '';
        final s = m.subjectName.toLowerCase();
        final sa = m.subjectNameAr?.toLowerCase() ?? '';
        return t.contains(q) ||
            ta.contains(q) ||
            s.contains(q) ||
            sa.contains(q);
      }).toList();
    }
    return list;
  }

  void setFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void toggleMaterialDownload(String id) {
    final idx = _academicMaterials.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final current = _academicMaterials[idx];
      _academicMaterials[idx] = current.copyWith(
        isDownloaded: !current.isDownloaded,
      );
      notifyListeners();
    }
  }

  void addPersonalNote(StudyNote note) {
    _personalNotes.insert(0, note);
    notifyListeners();
  }

  void addNote(StudyNote note) {
    addPersonalNote(note);
  }

  void toggleChecklistItem(int index) {
    if (_personalNotes.isNotEmpty &&
        _personalNotes[0].checklistItems != null &&
        index < _personalNotes[0].checklistItems!.length) {
      final item = _personalNotes[0].checklistItems![index];
      _personalNotes[0].checklistItems![index] = ChecklistItem(
        text: item.text,
        isChecked: !item.isChecked,
      );
      notifyListeners();
    }
  }
}
