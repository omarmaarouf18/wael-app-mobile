import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../services/notification_stream.dart';
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

    return Scaffold(
      backgroundColor: AppColors.voidCanvas,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(AppSpacing.headerHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xF2090909),
            border: Border(
              bottom: BorderSide(color: Color(0x14FFFFFF), width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Brand Wordmark
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: AppTypography.headlineSm().copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              l10n.appSubtitle,
                              style: AppTypography.academyEyebrow().copyWith(
                                fontSize: 9,
                                letterSpacing: 2.8,
                              ),
                            ),
                          ),
                          Container(
                            width: 12,
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Actions: Notifications with crimson pip + Profile avatar
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        key: const ValueKey('top_bar_notifications_button'),
                        onTap: () {
                          Navigator.of(context).pushNamed('/notifications');
                        },
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLayer1,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.subtleHairline,
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.notifications_none,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                              Positioned(
                                top: 7,
                                right: 7,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: AppColors.crimson,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.voidCanvas,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.spaceSm),
                      InkWell(
                        onTap: () => _onTabSelected(3),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLayer1,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.subtleHairline,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        height: AppSpacing.navBarHeight,
        decoration: const BoxDecoration(
          color: Color(0xF20B0B0B),
          border: Border(top: BorderSide(color: Color(0x14FFFFFF), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x99000000),
              offset: Offset(0, -4),
              blurRadius: 24,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(index: 0, icon: Icons.home, label: l10n.navHome),
              _buildNavItem(
                index: 1,
                icon: Icons.school_outlined,
                label: l10n.navCourses,
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.edit_note,
                label: l10n.navNotes,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.tune,
                label: l10n.navSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTabSelected(index),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                label.toUpperCase(),
                style: AppTypography.labelSm().copyWith(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 1.2,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              // Distinct 2px x 8px crimson ruby indicator pin
              AnimatedContainer(
                duration: AppMotion.durationFast,
                width: isSelected ? 8 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.crimson : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: isSelected ? AppElevation.crimsonGlow : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
