import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  NotificationStream? _stream;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
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
    _stream?.stop();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
          showPip: true,
          onTap: () => Navigator.of(context).pushNamed('/notifications'),
        ),
        const SizedBox(width: AppSpacing.spaceSm),
        HeaderIconButton(
          icon: Icons.person_outline,
          onTap: () => _onTabSelected(3),
        ),
        const SizedBox(width: AppSpacing.spaceSm),
      ],
      body: IndexedStack(index: _currentIndex, children: screens),
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
