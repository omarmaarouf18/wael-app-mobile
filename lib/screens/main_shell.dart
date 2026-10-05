import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/error_messages.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_stream.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_shell.dart';
import '../widgets/brand_lockup.dart';
import '../widgets/header_icon_button.dart';
import 'home_screen.dart';
import 'courses_screen.dart';
import 'ebook_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  final int initialTab;

  const MainShell({super.key, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late int _currentIndex;
  NotificationStream? _stream;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLiveStream());
  }

  Future<void> _startLiveStream() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = await auth.authedTokenForStream();
    if (!mounted || token == null) return;
    final notifs = Provider.of<NotificationsProvider>(context, listen: false);
    notifs.attachRemote(HttpNotificationRepository(auth.authedApi));
    await notifs.loadRemote();
    if (!mounted) return;
    _stream = NotificationStream(auth.authedApi);
    await _stream!.connect(token: token, onItem: notifs.addNotification);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stream?.stop();
    super.dispose();
  }

  /// Revalidate the session when the app comes back while offline.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isOffline) auth.retryRestore();
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The bell shows its pip only while something is unread.
    final hasUnread = context.select<NotificationsProvider, bool>(
      (n) => n.unreadCount > 0,
    );
    final offline = context.select<AuthProvider, bool>((a) => a.isOffline);
    final retryAfter = context.select<AuthProvider, int?>(
      (a) => a.retryAfterSeconds,
    );

    final screens = [
      HomeScreen(onExploreCourses: () => _onTabSelected(1)),
      const CoursesScreen(),
      const EbookScreen(),
      const SettingsScreen(),
    ];

    return AppShell(
      titleWidget: const BrandLockup(),
      actions: [
        HeaderIconButton(
          key: const ValueKey('top_bar_notifications_button'),
          icon: Icons.notifications_none,
          showPip: hasUnread,
          onTap: () => Navigator.of(context).pushNamed('/notifications'),
        ),
        const SizedBox(width: AppSpacing.spaceSm),
        HeaderIconButton(
          icon: Icons.person_outline,
          onTap: () => _onTabSelected(3),
        ),
        const SizedBox(width: AppSpacing.spaceSm),
      ],
      body: Column(
        children: [
          if (offline)
            _OfflineBanner(
              onRetry: () => context.read<AuthProvider>().retryRestore(),
              retryAfterSeconds: retryAfter,
            ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        items: [
          AppNavItem(icon: Icons.home, label: l10n.navHome),
          AppNavItem(icon: Icons.school_outlined, label: l10n.navCourses),
          AppNavItem(icon: Icons.edit_note, label: l10n.navNotes),
          AppNavItem(icon: Icons.tune, label: l10n.navSettings),
        ],
      ),
    );
  }
}

/// Offline strip: the session runs on kept tokens because the server could
/// not be reached at restore. Retry revalidates the session. When the
/// restore failed with 429/408 and the server sent `Retry-After`, the
/// banner honours it by showing the wait before the retry action.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry, this.retryAfterSeconds});

  final VoidCallback onRetry;
  final int? retryAfterSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wait = retryAfterSeconds;
    final message = (wait != null && wait > 0)
        ? '${l10n.offlineBanner} ${ErrorMessages.tooManyAttempts(l10n.isArabic, wait)}'
        : l10n.offlineBanner;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: AppColors.warningBg,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: AppSpacing.spaceSm,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 16,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.spaceSm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySm(
                  isArabic: l10n.isArabic,
                ).copyWith(color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.spaceSm),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                l10n.retry,
                style: AppTypography.bodySm(isArabic: l10n.isArabic).copyWith(
                  color: AppColors.crimson,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
