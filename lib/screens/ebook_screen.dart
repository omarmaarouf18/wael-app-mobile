import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/app_shell.dart';
import '../widgets/themed_empty_state.dart';

/// Study materials and notes tab.
///
/// There is no library API behind this tab yet, so it shows an honest empty
/// state and nothing else. A subject's own books and notes are on the subject
/// screen (`GET /academy/subjects/{id}` files).
class EbookScreen extends StatelessWidget {
  const EbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppShell(
      showHeader: false,
      body: ThemedEmptyState(
        icon: Icons.menu_book_outlined,
        message: l10n.materialsEmpty,
      ),
    );
  }
}
