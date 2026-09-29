import 'package:flutter/material.dart';
import '../models/payment_request.dart';
import '../models/course.dart';

class PaymentTier {
  final String id;
  final String name;
  final String? nameAr;
  final int priceEgp;
  final String description;
  final String? descriptionAr;
  final List<String> features;

  const PaymentTier({
    required this.id,
    required this.name,
    this.nameAr,
    required this.priceEgp,
    required this.description,
    this.descriptionAr,
    required this.features,
  });

  String localizedName(bool isArabic) =>
      (isArabic && nameAr != null) ? nameAr! : name;
}

class PaymentProvider extends ChangeNotifier {
  String _selectedTierId = 'tier-standard';
  String _selectedPaymentMethod = 'vodafone_cash';
  bool _isSubmitting = false;
  PaymentRequest? _lastRequest;

  final List<PaymentTier> tiers = const [
    PaymentTier(
      id: 'tier-standard',
      name: 'Standard Scholar Access',
      nameAr: 'الاشتراك الدراسي القياسي',
      priceEgp: 1800,
      description:
          'Complete video lectures, downloadable dossiers, and examination rights.',
      descriptionAr:
          'كافة المحاضرات المرئية، والملفات والمذكرات القابلة للتحميل، وحق التقدم للاختبار النهائي.',
      features: [
        'Full HD Lecture Access',
        'Offline PDF Dossiers',
        'Academy Certificate of Completion',
      ],
    ),
    PaymentTier(
      id: 'tier-executive',
      name: 'Executive Masterclass Tier',
      nameAr: 'باقة الماستر كلاس التنفيذية',
      priceEgp: 2800,
      description:
          'Direct review by Dean El Metr plus live courtroom simulation access.',
      descriptionAr:
          'مراجعة وتقييم شخصي من المستشار وائل المتر مع حضور جلسات المحاكاة القضائية الحية.',
      features: [
        'Everything in Standard',
        'Direct Argument Review by Dean El Metr',
        'Live Crisis Simulation Participation',
        'Printed Leather Dossier via Courier',
      ],
    ),
  ];

  final List<PaymentRequest> _requestsHistory = [
    PaymentRequest(
      id: 'REQ-2024-101',
      courseId: 'architectural-discipline',
      courseTitle: 'Architectural Discipline & Executive Poise',
      userId: 'user-007',
      userName: 'Alexander Vane',
      userPhone: '+20 122 27 007 27',
      tierName: 'Executive Masterclass Tier',
      amountEgp: 2800,
      paymentMethod: 'vodafone_cash',
      transactionReference: 'VOD-88492019',
      status: PaymentStatus.approved,
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      adminNote: 'Enrolment authorized by Dean Office.',
    ),
  ];

  String get selectedTierId => _selectedTierId;
  String get selectedPaymentMethod => _selectedPaymentMethod;
  bool get isSubmitting => _isSubmitting;
  PaymentRequest? get lastRequest => _lastRequest;
  List<PaymentRequest> get requestsHistory => _requestsHistory;

  PaymentTier get selectedTier {
    return tiers.firstWhere(
      (t) => t.id == _selectedTierId,
      orElse: () => tiers.first,
    );
  }

  void selectTier(String tierId) {
    _selectedTierId = tierId;
    notifyListeners();
  }

  void selectPaymentMethod(String method) {
    _selectedPaymentMethod = method;
    notifyListeners();
  }

  Future<PaymentRequest> submitPaymentRequest({
    required Course course,
    required String userName,
    required String userPhone,
    required String transactionReference,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 900));

    final newRequest = PaymentRequest(
      id: 'REQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      courseId: course.id,
      courseTitle: course.title,
      userId: 'user-007',
      userName: userName,
      userPhone: userPhone,
      tierName: selectedTier.name,
      amountEgp: selectedTier.priceEgp,
      paymentMethod: _selectedPaymentMethod,
      transactionReference: transactionReference,
      status: PaymentStatus.pending,
      createdAt: DateTime.now(),
    );

    _lastRequest = newRequest;
    _requestsHistory.insert(0, newRequest);
    _isSubmitting = false;
    notifyListeners();
    return newRequest;
  }

  // Interactive mock helper to cycle state for UI evaluation
  void cycleMockStatus(String requestId) {
    final idx = _requestsHistory.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final current = _requestsHistory[idx];
      PaymentStatus nextStatus;
      if (current.status == PaymentStatus.pending) {
        nextStatus = PaymentStatus.approved;
      } else if (current.status == PaymentStatus.approved) {
        nextStatus = PaymentStatus.rejected;
      } else {
        nextStatus = PaymentStatus.pending;
      }

      _requestsHistory[idx] = current.copyWith(status: nextStatus);
      if (_lastRequest?.id == requestId) {
        _lastRequest = _requestsHistory[idx];
      }
      notifyListeners();
    }
  }
}
