class NotificationModel {
  final String id;
  final String title;
  final String? titleAr;
  final String body;
  final String? bodyAr;
  final String timestamp;
  final String? timestampAr;
  final bool isRead;
  final String type; // 'payment', 'course', 'event', 'system'
  final String? targetRoute;
  final Map<String, dynamic>? arguments;

  const NotificationModel({
    required this.id,
    required this.title,
    this.titleAr,
    required this.body,
    this.bodyAr,
    required this.timestamp,
    this.timestampAr,
    this.isRead = false,
    required this.type,
    this.targetRoute,
    this.arguments,
  });

  String localizedTitle(bool isArabic) =>
      (isArabic && titleAr != null && titleAr!.isNotEmpty) ? titleAr! : title;

  String localizedBody(bool isArabic) =>
      (isArabic && bodyAr != null && bodyAr!.isNotEmpty) ? bodyAr! : body;

  String localizedTimestamp(bool isArabic) =>
      (isArabic && timestampAr != null && timestampAr!.isNotEmpty)
      ? timestampAr!
      : timestamp;

  /// Academy subject this notification refers to (request approved/rejected,
  /// access granted/revoked), when the payload carries one. The backend does
  /// not send it today (see Backend follow-ups); the screen then stays on
  /// the notifications list instead of deep-linking.
  String? get subjectId {
    final args = arguments;
    if (args == null) return null;
    final id = args['subject_id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? titleAr,
    String? body,
    String? bodyAr,
    String? timestamp,
    String? timestampAr,
    bool? isRead,
    String? type,
    String? targetRoute,
    Map<String, dynamic>? arguments,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      titleAr: titleAr ?? this.titleAr,
      body: body ?? this.body,
      bodyAr: bodyAr ?? this.bodyAr,
      timestamp: timestamp ?? this.timestamp,
      timestampAr: timestampAr ?? this.timestampAr,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      targetRoute: targetRoute ?? this.targetRoute,
      arguments: arguments ?? this.arguments,
    );
  }
}
