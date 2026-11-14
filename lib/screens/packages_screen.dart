import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/store_policy.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/iap_package.dart';
import '../providers/iap_provider.dart';
import '../services/iap_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/owned_subject_tile.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/themed_empty_state.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_panel.dart';
import '../widgets/themed_skeleton.dart';

/// iOS subject packages (issue #58): every published package with its
/// subjects, the StoreKit price (never one from our API), Buy and Restore
/// Purchases. Off iOS the screen renders nothing (no route leads here).
class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key, this.focusPackageId});

  /// Scrolls to and highlights this package (from a locked subject).
  final String? focusPackageId;

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  StreamSubscription<IapPurchaseState>? _sub;
  final GlobalKey _focusKey = GlobalKey();
  bool _focused = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final iap = context.read<IapProvider>();
      if (!iap.enabled) return;
      _sub = iap.purchaseStates.listen(_onPurchaseState);
      unawaited(iap.load());
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _onPurchaseState(IapPurchaseState s) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (s.phase == IapPhase.success) {
      _snack(l10n.iapSuccess);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(IapProvider iap) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _restoring = true);
    await iap.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (iap.purchase.phase == IapPhase.idle) _snack(l10n.iapRestoreNothing);
  }

  void _maybeFocus() {
    if (_focused || widget.focusPackageId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusKey.currentContext;
      if (ctx == null || _focused) return;
      _focused = true;
      Scrollable.ensureVisible(
        ctx,
        duration: AppMotion.durationNormal,
        curve: AppMotion.curveStandard,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final platform = Theme.of(context).platform;
    if (!StorePolicy.iapEnabled(platform)) {
      return AppShell(
        title: l10n.iapPackagesTitle,
        showBack: true,
        body: const SizedBox.shrink(),
      );
    }
    final iap = context.watch<IapProvider>();

    return AppShell(
      title: l10n.iapPackagesTitle,
      showBack: true,
      body: RefreshIndicator(
        color: AppColors.crimson,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: iap.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
          children: [..._body(context, l10n, iap)],
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    AppLocalizations l10n,
    IapProvider iap,
  ) {
    final catalog = iap.catalog;
    if (catalog == null) {
      if (iap.status == IapCatalogStatus.error) {
        return [
          ThemedErrorBanner(message: l10n.iapLoadFailed, onRetry: iap.load),
        ];
      }
      return const [ThemedPanel(child: ThemedSkeletonList())];
    }

    final purchase = iap.purchase;
    final status = _statusLine(l10n, purchase);
    _maybeFocus();

    return [
      if (status != null) ...[
        status,
        const SizedBox(height: AppSpacing.spaceMd),
      ],
      if (catalog.packages.isEmpty)
        ThemedEmptyState(
          icon: Icons.inventory_2_outlined,
          message: l10n.iapNoPackages,
        )
      else
        for (final package in catalog.packages) ...[
          _PackageCard(
            key: package.id == widget.focusPackageId ? _focusKey : null,
            package: package,
            highlighted: package.id == widget.focusPackageId,
            iap: iap,
          ),
          const SizedBox(height: AppSpacing.spaceMd),
        ],
      const SizedBox(height: AppSpacing.spaceSm),
      SecondaryButton(
        text: l10n.iapRestorePurchases,
        height: 48,
        isLoading: _restoring,
        leadingIcon: const Icon(
          Icons.restore,
          size: AppIconSize.sm,
          color: AppColors.textPrimary,
        ),
        onPressed: () => _restore(iap),
      ),
      const SizedBox(height: AppSpacing.space2xl),
    ];
  }

  /// Pending, verifying and failed get a line above the list; success shows
  /// a snackbar; cancelled shows nothing.
  Widget? _statusLine(AppLocalizations l10n, IapPurchaseState s) {
    final isArabic = l10n.isArabic;
    switch (s.phase) {
      case IapPhase.failed:
        return ThemedErrorBanner(message: l10n.iapError(s.errorCode));
      case IapPhase.pending:
      case IapPhase.verifying:
        final text = s.phase == IapPhase.pending
            ? l10n.iapPending
            : l10n.iapVerifying;
        return ThemedPanel(
          tone: PanelTone.raised,
          borderRadius: AppRadius.radiusLg,
          padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
          child: Semantics(
            liveRegion: true,
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.crimson,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceMd),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.bodyMd(
                      isArabic: isArabic,
                    ).copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      case IapPhase.idle:
      case IapPhase.loading:
      case IapPhase.purchasing:
      case IapPhase.success:
      case IapPhase.cancelled:
        return null;
    }
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    super.key,
    required this.package,
    required this.highlighted,
    required this.iap,
  });

  final IapPackage package;
  final bool highlighted;
  final IapProvider iap;

  /// Why Buy is disabled, or null when it is enabled or only busy.
  String? _reason(AppLocalizations l10n) {
    if (package.allOwned) return l10n.iapAllOwned;
    if (!package.onSale) return l10n.iapNotOnSale;
    if (iap.productFor(package) == null) return l10n.iapStoreUnavailable;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final product = iap.productFor(package);
    final until = package.availableUntil;
    final description = package.description.resolve(isArabic);
    final reason = _reason(l10n);

    return ThemedPanel(
      tone: highlighted ? PanelTone.raised : PanelTone.base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    package.title.resolve(isArabic),
                    style: AppTypography.headlineMd(isArabic: isArabic),
                  ),
                ),
              ),
              if (product != null) ...[
                const SizedBox(width: AppSpacing.spaceSm),
                // StoreKit's localized display price, as returned.
                Text(
                  product.price,
                  style: AppTypography.headlineSm(isArabic: isArabic),
                ),
              ],
            ],
          ),
          if (until != null) ...[
            const SizedBox(height: AppSpacing.spaceXs),
            Text(
              l10n.iapAvailableUntil(OwnedSubjectTile.formatDate(until)),
              style: AppTypography.bodySm(isArabic: isArabic),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.spaceSm),
            Text(description, style: AppTypography.bodyMd(isArabic: isArabic)),
          ],
          const SizedBox(height: AppSpacing.spaceMd),
          Text(
            l10n.iapSubjectsHeading,
            style: AppTypography.labelMd(isArabic: isArabic),
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          if (package.subjects.isEmpty)
            Text(
              l10n.iapNoSubjects,
              style: AppTypography.bodySm(isArabic: isArabic),
            )
          else
            for (final subject in package.subjects)
              _SubjectRow(subject: subject, isArabic: isArabic, l10n: l10n),
          const SizedBox(height: AppSpacing.spaceMd),
          PrimaryButton(
            text: l10n.iapBuy,
            height: 48,
            isLoading: iap.isBusyWith(package),
            onPressed: iap.canBuy(package) ? () => iap.buy(package) : null,
          ),
          if (reason != null) ...[
            const SizedBox(height: AppSpacing.spaceSm),
            Text(reason, style: AppTypography.bodySm(isArabic: isArabic)),
          ],
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.isArabic,
    required this.l10n,
  });

  final IapPackageSubject subject;
  final bool isArabic;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: AppSpacing.spaceXs,
      ),
      child: Row(
        children: [
          Icon(
            subject.owned ? Icons.check_circle : Icons.menu_book_outlined,
            size: AppIconSize.sm,
            color: subject.owned ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.spaceSm),
          Expanded(
            child: Text(
              subject.title.resolve(isArabic),
              style: AppTypography.bodyMd(
                isArabic: isArabic,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ),
          if (subject.owned) ...[
            const SizedBox(width: AppSpacing.spaceSm),
            Text(
              l10n.iapOwned,
              style: AppTypography.bodySm(
                isArabic: isArabic,
              ).copyWith(color: AppColors.success),
            ),
          ],
        ],
      ),
    );
  }
}
