import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/otp_pin_input.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import '../widgets/themed_empty_state.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_loading_indicator.dart';
import '../widgets/themed_panel.dart';
import '../widgets/themed_section_header.dart';

/// Visual catalogue of the shared widget layer, with a language toggle to
/// check Arabic (RTL) and English side by side.
///
/// Reachable only in debug builds: the `/components` route is registered
/// only when `kDebugMode` is true (see `buildAppRoutes` in `main.dart`) and
/// the only link to it is on the diagnostics screen, which is debug-only too.
class ComponentLibraryScreen extends StatefulWidget {
  const ComponentLibraryScreen({super.key});

  @override
  State<ComponentLibraryScreen> createState() => _ComponentLibraryScreenState();
}

class _ComponentLibraryScreenState extends State<ComponentLibraryScreen> {
  int _retries = 0;
  String _otp = '';
  bool _otpError = false;
  String _lastDialogResult = '-';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppShell(
      title: 'Component library',
      showBack: true,
      actions: [
        TextButton(
          onPressed: () => context.read<LocaleProvider>().toggleLocale(),
          child: Text(
            l10n.isArabic ? 'EN' : 'AR',
            style: AppTypography.labelMd().copyWith(color: AppColors.crimson),
          ),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
        children: [
          const ThemedSectionHeader(title: 'Buttons'),
          PrimaryButton(text: l10n.verify, onPressed: () {}),
          const SizedBox(height: AppSpacing.spaceSm),
          SecondaryButton(text: l10n.cancel, onPressed: () {}),
          const SizedBox(height: AppSpacing.spaceSm),
          SecondaryButton(text: l10n.loading, onPressed: null, isLoading: true),
          const SizedBox(height: AppSpacing.spaceXl),
          const ThemedSectionHeader(title: 'Panel tones'),
          for (final tone in PanelTone.values) ...[
            ThemedPanel(
              tone: tone,
              child: Text(
                tone.name,
                style: AppTypography.bodyMd(isArabic: l10n.isArabic),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
          ],
          const SizedBox(height: AppSpacing.spaceLg),
          ThemedSectionHeader(
            title: 'Error banner',
            action: Text(
              '$_retries',
              style: AppTypography.labelSm(isArabic: l10n.isArabic),
            ),
          ),
          ThemedErrorBanner(
            message: l10n.errorLoading,
            onRetry: () => setState(() => _retries++),
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          const ThemedSectionHeader(title: 'Empty state'),
          ThemedPanel(
            child: ThemedEmptyState(
              title: l10n.navNotes,
              message: l10n.noNotifications,
              action: SecondaryButton(text: l10n.retry, onPressed: () {}),
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          const ThemedSectionHeader(title: 'Loading'),
          const ThemedPanel(child: ThemedLoadingIndicator()),
          const SizedBox(height: AppSpacing.spaceXl),
          const ThemedSectionHeader(title: 'Confirm dialog'),
          SecondaryButton(
            text: l10n.confirm,
            onPressed: () async {
              final ok = await ConfirmActionDialog.show(
                context,
                title: l10n.signOut,
                message: l10n.errorLoading,
              );
              if (mounted) setState(() => _lastDialogResult = ok.toString());
            },
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          Text(
            'result: $_lastDialogResult',
            style: AppTypography.bodySm(isArabic: l10n.isArabic),
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          const ThemedSectionHeader(title: 'OTP input'),
          OtpPinInput(
            hasError: _otpError,
            onChanged: (v) => setState(() {
              _otp = v;
              _otpError = false;
            }),
            onCompleted: (v) => setState(() => _otpError = v == '000000'),
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          Text(
            'value: $_otp (000000 shows the error state)',
            style: AppTypography.bodySm(isArabic: l10n.isArabic),
          ),
        ],
      ),
    );
  }
}
