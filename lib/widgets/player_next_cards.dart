import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'secondary_button.dart';
import 'themed_panel.dart';

/// Next-lesson UI for the protected player (F-UX3): the button under the
/// player, the 5-second countdown card on the ended cover, and the
/// last-lesson end card. Fixed strings come from [AppLocalizations]; lesson
/// titles are passed in already localised.
class NextLessonButton extends StatelessWidget {
  const NextLessonButton({super.key, required this.title, required this.onTap});

  /// Identifies the button in tests.
  @visibleForTesting
  static const Key buttonKey = Key('next-lesson-button');

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      key: buttonKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SecondaryButton(
          text: l10n.nextLesson,
          trailingIcon: const Icon(
            Icons.skip_next_outlined,
            size: AppIconSize.md,
            color: AppColors.textPrimary,
          ),
          onPressed: onTap,
        ),
        const SizedBox(height: AppSpacing.spaceXs),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySm(
            isArabic: l10n.isArabic,
          ).copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Auto-advance card: shows the coming lesson, the seconds left and a
/// cancel action. Shown on the ended cover; cancelling swaps it for the
/// [NextLessonButton].
class NextCountdownCard extends StatelessWidget {
  const NextCountdownCard({
    super.key,
    required this.title,
    required this.secondsLeft,
    required this.onCancel,
  });

  /// Identifies the card in tests.
  @visibleForTesting
  static const Key countdownKey = Key('next-lesson-countdown');

  final String title;
  final int secondsLeft;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      key: countdownKey,
      constraints: const BoxConstraints(maxWidth: 320),
      child: ThemedPanel(
        tone: PanelTone.raised,
        borderRadius: AppRadius.radiusLg,
        padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.nextLesson,
              textAlign: TextAlign.center,
              style: AppTypography.labelMd(
                isArabic: l10n.isArabic,
              ).copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.spaceXs),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm(
                isArabic: l10n.isArabic,
              ).copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.spaceXs),
            Text(
              l10n.nextLessonStartsIn(secondsLeft),
              textAlign: TextAlign.center,
              style: AppTypography.bodySm(
                isArabic: l10n.isArabic,
              ).copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.spaceXs),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size(48, 48),
              ),
              child: Text(
                l10n.cancel,
                style: AppTypography.labelMd(isArabic: l10n.isArabic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Last lesson: the subject has no more lessons, with a way back.
class SubjectEndCard extends StatelessWidget {
  const SubjectEndCard({super.key, required this.onBack});

  /// Identifies the card in tests.
  @visibleForTesting
  static const Key endKey = Key('subject-end-card');

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      key: endKey,
      constraints: const BoxConstraints(maxWidth: 320),
      child: ThemedPanel(
        tone: PanelTone.raised,
        borderRadius: AppRadius.radiusLg,
        padding: const EdgeInsetsDirectional.all(AppSpacing.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.subjectFinished,
              textAlign: TextAlign.center,
              style: AppTypography.labelMd(
                isArabic: l10n.isArabic,
              ).copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            SecondaryButton(text: l10n.back, onPressed: onBack),
          ],
        ),
      ),
    );
  }
}
