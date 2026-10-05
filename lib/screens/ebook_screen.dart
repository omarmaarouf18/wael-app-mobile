import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_shell.dart';
import '../widgets/themed_empty_state.dart';

/// Study materials and notes tab.
///
/// There is no library API behind this tab yet, so it shows an honest empty
/// state and nothing else. A subject's own books and notes are on the subject
/// screen (`GET /academy/subjects/{id}` files). Pull-to-refresh is wired
/// (a no-op until Phase 5) so the gesture exists everywhere the plan asks.
class EbookScreen extends StatelessWidget {
  const EbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppShell(
      showHeader: false,
      body: RefreshIndicator(
        color: AppColors.crimson,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: SizedBox(
            height:
                MediaQuery.sizeOf(context).height - AppSpacing.headerHeight * 3,
            child: ThemedEmptyState(
              icon: Icons.menu_book_outlined,
              message: l10n.materialsEmpty,
            ),
          ),
        ),
      ),
    );
  }
}
