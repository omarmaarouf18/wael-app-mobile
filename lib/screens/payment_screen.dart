import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/course.dart';
import '../models/payment_request.dart';
import '../providers/payment_provider.dart';
import '../providers/courses_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';
import '../widgets/themed_card.dart';
import '../widgets/themed_text_field.dart';
import '../widgets/status_badge.dart';

class PaymentScreen extends StatefulWidget {
  final Course course;

  const PaymentScreen({super.key, required this.course});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _txRefController = TextEditingController();
  bool _receiptAttached = false;
  PaymentRequest? _activeRequest;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.currentUser.fullName;
    _phoneController.text = auth.currentUser.phone;
    _txRefController.text = 'VOD-88492026';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _txRefController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final l10n = AppLocalizations.of(context);
    final payment = Provider.of<PaymentProvider>(context, listen: false);
    final req = await payment.submitPaymentRequest(
      course: widget.course,
      userName: _nameController.text,
      userPhone: _phoneController.text,
      transactionReference: _txRefController.text.isNotEmpty
          ? _txRefController.text
          : 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );

    setState(() {
      _activeRequest = req;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            l10n.isArabic
                ? 'تم إرسال طلب التحقق من الدفع بنجاح. وهو الآن قيد المراجعة الإدارية.'
                : 'Payment verification request submitted for review.',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final payment = Provider.of<PaymentProvider>(context);
    final coursesProvider = Provider.of<CoursesProvider>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.textSecondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.paymentTitle.toUpperCase(),
          style: AppTypography.labelSm().copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: AppSpacing.spaceMd,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. COURSE SUMMARY CARD
              ThemedCard(
                padding: const EdgeInsets.all(AppSpacing.spaceMd),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: Image.asset(
                          widget.course.imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                AppConstants.imgCharacterArt,
                                fit: BoxFit.cover,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.course.tag.toUpperCase(),
                            style: AppTypography.academyEyebrow().copyWith(
                              color: AppColors.crimson,
                              fontSize: 9,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.course.localizedTitle(l10n.isArabic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMd(isArabic: l10n.isArabic)
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.course.localizedInstructor(l10n.isArabic),
                            style: AppTypography.bodySm(isArabic: l10n.isArabic)
                                .copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.spaceLg),

              // 2. ACTIVE REQUEST STATUS CARD (if submitted or existing)
              if (_activeRequest != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLayer1,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: _activeRequest!.status == PaymentStatus.approved
                          ? AppColors.statusApproved
                          : (_activeRequest!.status == PaymentStatus.rejected
                                ? AppColors.statusRejected
                                : AppColors.statusPending),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _activeRequest!.id,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          StatusBadge(status: _activeRequest!.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.spaceSm),
                      Text(
                        _activeRequest!.status == PaymentStatus.approved
                            ? (l10n.isArabic
                                  ? 'تم اعتماد التحويل وتفعيل الصلاحيات الدراسية كاملة.'
                                  : 'Payment approved! Full course access has been granted.')
                            : (_activeRequest!.status == PaymentStatus.rejected
                                  ? (l10n.isArabic
                                        ? 'تعذر التحقق من الإيصال. يرجى مراجعة رقم العملية.'
                                        : 'Verification failed. Please review transaction reference.')
                                  : (l10n.isArabic
                                        ? 'الطلب قيد المراجعة الإدارية وسوف يتم التفعيل خلال دقائق.'
                                        : 'Awaiting administrative verification. Access will unlock shortly.')),
                        style: AppTypography.bodySm(
                          isArabic: l10n.isArabic,
                        ).copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.spaceMd),

                      // Interactive Simulation Action to cycle state
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              payment.cycleMockStatus(_activeRequest!.id);
                              setState(() {
                                _activeRequest = payment.lastRequest;
                              });
                            },
                            icon: const Icon(
                              Icons.sync,
                              size: 14,
                              color: AppColors.crimson,
                            ),
                            label: Text(
                              l10n.isArabic
                                  ? 'محاكاة تغيير الحالة (تجريبي)'
                                  : 'Cycle Mock Status (Demo)',
                              style: const TextStyle(
                                color: AppColors.crimson,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (_activeRequest!.status == PaymentStatus.approved)
                            ElevatedButton(
                              onPressed: () {
                                coursesProvider.markEnrolled(widget.course.id);
                                Navigator.of(context).pushReplacementNamed(
                                  '/course-details',
                                  arguments: widget.course.id,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.statusApproved,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              child: Text(
                                l10n.isArabic ? 'دخول الدورة' : 'Access Course',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceLg),
              ],

              // 3. SELECT ACCESS TIER
              Text(
                l10n.selectAccessTier.toUpperCase(),
                style: AppTypography.labelSm(
                  isArabic: l10n.isArabic,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
              ),
              const SizedBox(height: AppSpacing.spaceSm),

              ...payment.tiers.map((tier) {
                final isSelected = tier.id == payment.selectedTierId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
                  child: ThemedCard(
                    borderColor: isSelected
                        ? AppColors.crimson
                        : AppColors.subtleHairline,
                    borderWidth: isSelected ? 1.5 : 1.0,
                    backgroundColor: isSelected
                        ? AppColors.crimson.withValues(alpha: 0.08)
                        : AppColors.surfaceLayer1,
                    onTap: () => payment.selectTier(tier.id),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.crimson
                                  : AppColors.prominentBorder,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.crimson,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.spaceSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tier.localizedName(l10n.isArabic),
                                    style:
                                        AppTypography.bodyMd(
                                          isArabic: l10n.isArabic,
                                        ).copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                  ),
                                  Text(
                                    '${tier.priceEgp} EGP',
                                    style: AppTypography.labelMd().copyWith(
                                      color: AppColors.crimson,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSelected
                                    ? (l10n.isArabic &&
                                              tier.descriptionAr != null
                                          ? tier.descriptionAr!
                                          : tier.description)
                                    : (l10n.isArabic &&
                                              tier.descriptionAr != null
                                          ? tier.descriptionAr!
                                          : tier.description),
                                style:
                                    AppTypography.bodySm(
                                      isArabic: l10n.isArabic,
                                    ).copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.spaceLg),

              // 4. PAYMENT METHOD SELECTION
              Text(
                l10n.paymentMethod.toUpperCase(),
                style: AppTypography.labelSm(
                  isArabic: l10n.isArabic,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
              ),
              const SizedBox(height: AppSpacing.spaceSm),

              Row(
                children: [
                  _buildPaymentMethodOption(
                    id: 'vodafone_cash',
                    icon: Icons.phone_android,
                    label: l10n.vodafoneCash,
                    selected: payment.selectedPaymentMethod == 'vodafone_cash',
                    onTap: () => payment.selectPaymentMethod('vodafone_cash'),
                  ),
                  const SizedBox(width: AppSpacing.spaceSm),
                  _buildPaymentMethodOption(
                    id: 'instapay',
                    icon: Icons.flash_on,
                    label: l10n.instaPay,
                    selected: payment.selectedPaymentMethod == 'instapay',
                    onTap: () => payment.selectPaymentMethod('instapay'),
                  ),
                  const SizedBox(width: AppSpacing.spaceSm),
                  _buildPaymentMethodOption(
                    id: 'bank_transfer',
                    icon: Icons.account_balance,
                    label: l10n.bankTransfer,
                    selected: payment.selectedPaymentMethod == 'bank_transfer',
                    onTap: () => payment.selectPaymentMethod('bank_transfer'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.spaceLg),

              // 5. PAYMENT INSTRUCTIONS BOX
              ThemedCard(
                backgroundColor: AppColors.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.crimson,
                        ),
                        const SizedBox(width: AppSpacing.spaceSm),
                        Text(
                          l10n.paymentInstructions,
                          style: AppTypography.labelSm(isArabic: l10n.isArabic)
                              .copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.paymentInstructionBody,
                      style: AppTypography.bodySm(isArabic: l10n.isArabic)
                          .copyWith(
                            color: AppColors.textMuted,
                            height: 1.4,
                            fontSize: 11,
                          ),
                    ),
                    const Divider(color: AppColors.subtleHairline, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          payment.selectedPaymentMethod == 'vodafone_cash'
                              ? 'Vodafone Cash Wallet:'
                              : (payment.selectedPaymentMethod == 'instapay'
                                    ? 'InstaPay GPA IPA:'
                                    : 'NBE Account IBAN:'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          payment.selectedPaymentMethod == 'vodafone_cash'
                              ? AppConstants.vodafoneCashNumber
                              : (payment.selectedPaymentMethod == 'instapay'
                                    ? AppConstants.instapayHandle
                                    : AppConstants.bankAccountIban),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.spaceLg),

              // 6. REQUIRED USER VERIFICATION INPUTS
              Text(
                l10n.isArabic
                    ? 'بيانات التحقق وسند السداد'
                    : 'Verification Credentials',
                style: AppTypography.labelSm(
                  isArabic: l10n.isArabic,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
              ),
              const SizedBox(height: AppSpacing.spaceSm),

              ThemedTextField(
                label: l10n.fullName,
                controller: _nameController,
                prefixIcon: const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceMd),

              ThemedTextField(
                label: l10n.isArabic
                    ? 'رقم الهاتف المحمول'
                    : 'Contact Phone Line',
                controller: _phoneController,
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceMd),

              ThemedTextField(
                label: l10n.transactionRef,
                hintText: 'VOD-88492026',
                controller: _txRefController,
                prefixIcon: const Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceMd),

              // Receipt Attachment Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _receiptAttached = !_receiptAttached;
                    });
                  },
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.spaceMd),
                    decoration: BoxDecoration(
                      color: _receiptAttached
                          ? AppColors.statusApprovedBg
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: _receiptAttached
                            ? AppColors.statusApproved
                            : AppColors.subtleHairline,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _receiptAttached
                              ? Icons.check_circle
                              : Icons.attach_file,
                          size: 16,
                          color: _receiptAttached
                              ? AppColors.statusApproved
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.spaceSm),
                        Text(
                          _receiptAttached
                              ? l10n.receiptAttached
                              : l10n.uploadReceipt,
                          style: AppTypography.labelSm(isArabic: l10n.isArabic)
                              .copyWith(
                                color: _receiptAttached
                                    ? AppColors.statusApproved
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.spaceXl),

              // 7. SUBMIT PAYMENT REQUEST CTA
              PrimaryButton(
                text: l10n.submitPaymentRequest,
                isLoading: payment.isSubmitting,
                onPressed: _handleSubmit,
              ),
              const SizedBox(height: AppSpacing.space3xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodOption({
    required String id,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AnimatedContainer(
            duration: AppMotion.durationFast,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.crimson.withValues(alpha: 0.12)
                  : AppColors.surfaceLayer1,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected ? AppColors.crimson : AppColors.subtleHairline,
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.crimson : AppColors.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
