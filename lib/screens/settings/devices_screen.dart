import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/account_provider.dart';
import '../../repositories/account_repository.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/confirm_action_dialog.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/themed_card.dart';
import '../../widgets/themed_empty_state.dart';
import '../../widgets/themed_error_banner.dart';
import '../../widgets/themed_loading_indicator.dart';

/// The student's signed-in devices (F-UX2 A1): label, "this device" and
/// last-used relative time. Other devices sign out after a confirm.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<DeviceSession>? _sessions;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  Future<void> _reload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final sessions = await context.read<AccountProvider>().loadSessions();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (sessions == null) {
        _error = context.read<AccountProvider>().errorMessage;
      } else {
        _sessions = sessions;
      }
    });
  }

  Future<void> _endSession(DeviceSession session) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmActionDialog.show(
      context,
      title: l10n.signOutDeviceTitle,
      message: l10n.signOutDeviceMessage,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final account = context.read<AccountProvider>();
    final ok = await account.endSession(session.sid);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = account.errorMessage;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(l10n.deviceSignedOut),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessions = _sessions;
    Widget body;
    if (sessions == null) {
      body = _error == null
          ? const ThemedLoadingIndicator()
          : Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(
                  AppSpacing.marginMobile,
                ),
                child: ThemedErrorBanner(
                  message: _error ?? '',
                  onRetry: _reload,
                ),
              ),
            );
    } else if (sessions.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
          child: ThemedEmptyState(message: l10n.noOtherDevices),
        ),
      );
    } else {
      body = Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.marginMobile,
                end: AppSpacing.marginMobile,
                top: AppSpacing.spaceSm,
              ),
              child: ThemedErrorBanner(message: _error ?? '', onRetry: _reload),
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.crimson,
              backgroundColor: AppColors.surfaceElevated,
              onRefresh: _reload,
              child: ListView.separated(
                padding: const EdgeInsetsDirectional.all(
                  AppSpacing.marginMobile,
                ),
                itemCount: sessions.length + 1,
                separatorBuilder: (_, i) =>
                    const SizedBox(height: AppSpacing.spaceSm),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: AppSpacing.spaceSm,
                      ),
                      child: Text(
                        l10n.deviceLimitNote,
                        style: AppTypography.bodySm(
                          isArabic: l10n.isArabic,
                        ).copyWith(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  final session = sessions[i - 1];
                  return _DeviceRow(
                    session: session,
                    busy: _busy,
                    onSignOut: () => _endSession(session),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }
    return AppShell(showBack: true, title: l10n.myDevices, body: body);
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.session,
    required this.busy,
    required this.onSignOut,
  });

  final DeviceSession session;
  final bool busy;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = session.deviceLabel.trim().isNotEmpty
        ? session.deviceLabel.trim()
        : l10n.unknownDevice;
    return ThemedCard(
      padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
      child: Row(
        children: [
          IconTile(
            icon: Icons.smartphone_outlined,
            iconColor: AppColors.textSecondary,
            size: 32,
            iconSize: 18,
            borderRadius: AppRadius.radiusSm,
          ),
          const SizedBox(width: AppSpacing.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: AppTypography.bodySm().copyWith(
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (session.current) ...[
                      const SizedBox(width: AppSpacing.spaceXs),
                      _ThisDeviceChip(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  relativeLastUsed(l10n, session.lastUsedAt),
                  style: AppTypography.caption(
                    isArabic: l10n.isArabic,
                  ).copyWith(color: AppColors.textTertiary),
                ),
                if (!session.current) ...[
                  const SizedBox(height: AppSpacing.spaceSm),
                  SecondaryButton(
                    text: l10n.signOutDevice,
                    onPressed: busy ? null : onSignOut,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThisDeviceChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.spaceSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.crimsonTinted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.crimson),
      ),
      child: Text(
        l10n.thisDevice,
        style: AppTypography.labelSm(
          isArabic: l10n.isArabic,
        ).copyWith(color: AppColors.danger),
      ),
    );
  }
}

/// Relative "last used" text for a session timestamp.
@visibleForTesting
String relativeLastUsed(AppLocalizations l10n, DateTime when) {
  final age = DateTime.now().toUtc().difference(when.toUtc());
  if (age.inMinutes < 1) return l10n.justNow;
  if (age.inHours < 1) return l10n.minutesAgo(age.inMinutes);
  if (age.inDays < 1) return l10n.hoursAgo(age.inHours);
  return l10n.daysAgo(age.inDays);
}
