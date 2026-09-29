enum PaymentStatus { pending, approved, rejected }

class PaymentRequest {
  final String id;
  final String courseId;
  final String courseTitle;
  final String userId;
  final String userName;
  final String userPhone;
  final String tierName;
  final int amountEgp;
  final String paymentMethod; // 'vodafone_cash', 'instapay', 'bank_transfer'
  final String transactionReference;
  final PaymentStatus status;
  final DateTime createdAt;
  final String? adminNote;

  const PaymentRequest({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.tierName,
    required this.amountEgp,
    required this.paymentMethod,
    required this.transactionReference,
    this.status = PaymentStatus.pending,
    required this.createdAt,
    this.adminNote,
  });

  PaymentRequest copyWith({
    String? id,
    String? courseId,
    String? courseTitle,
    String? userId,
    String? userName,
    String? userPhone,
    String? tierName,
    int? amountEgp,
    String? paymentMethod,
    String? transactionReference,
    PaymentStatus? status,
    DateTime? createdAt,
    String? adminNote,
  }) {
    return PaymentRequest(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      tierName: tierName ?? this.tierName,
      amountEgp: amountEgp ?? this.amountEgp,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionReference: transactionReference ?? this.transactionReference,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      adminNote: adminNote ?? this.adminNote,
    );
  }
}
