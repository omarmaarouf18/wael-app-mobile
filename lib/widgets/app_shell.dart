import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Screen shell: a [Scaffold] with an [AppBar] built from design tokens.
///
/// Everything is directional. The leading slot (back button) sits at the
/// start edge and [actions] at the end edge, so the shell mirrors in Arabic
/// without any per-screen handling. Screens use this instead of declaring
/// their own `Scaffold(` / `AppBar(`.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.body,
    this.title,
    this.showHeader = true,
    this.showBack = false,
    this.onBack,
    this.actions = const [],
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;

  /// Header title. Omit for a header with only back button and actions.
  final String? title;

  /// When false there is no app bar and the body is padded by the top inset.
  final bool showHeader;

  final bool showBack;

  /// Back button handler. Defaults to [Navigator.maybePop].
  final VoidCallback? onBack;

  /// Header actions, laid out from the end edge.
  final List<Widget> actions;

  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      appBar: showHeader
          ? AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: AppSpacing.headerHeight,
              backgroundColor: AppColors.headerGlass,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              actionsPadding: const EdgeInsetsDirectional.only(
                end: AppSpacing.spaceSm,
              ),
              leading: showBack
                  ? IconButton(
                      tooltip: l10n.back,
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: AppIconSize.md,
                      ),
                      color: AppColors.textSecondary,
                      onPressed: onBack ?? () => Navigator.maybePop(context),
                    )
                  : null,
              title: title == null
                  ? null
                  : Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineSm(isArabic: l10n.isArabic),
                    ),
              actions: actions,
              flexibleSpace: const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: double.infinity,
                  height: 1,
                  child: ColoredBox(color: AppColors.glassHairline),
                ),
              ),
            )
          : null,
      body: SafeArea(top: !showHeader, bottom: false, child: body),
    );
  }
}
