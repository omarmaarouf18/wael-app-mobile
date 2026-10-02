/// Status of the old mock payment request. The request model and the payment
/// flow that used it are gone (access requests are real now, see
/// `AccessRequest` in `academy_catalog.dart`); only this enum stays, because
/// `lib/widgets/status_badge.dart` still takes it and has no other caller.
enum PaymentStatus { pending, approved, rejected }
