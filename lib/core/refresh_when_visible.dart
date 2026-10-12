import 'dart:async';

import 'package:flutter/widgets.dart';

/// Tells a screen inside `MainShell`'s `IndexedStack` whether it is the tab
/// on screen. The stack keeps every tab mounted, so `initState` alone runs
/// once per session; [RefreshWhenVisible] uses this to refetch when the
/// student comes back to a tab. A screen outside the shell (a pushed route)
/// has no [TabVisibility] above it and counts as visible.
class TabVisibility extends InheritedWidget {
  const TabVisibility({super.key, required this.visible, required super.child});

  final bool visible;

  /// The nearest tab's visibility, or null outside the shell.
  static bool? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabVisibility>()?.visible;

  @override
  bool updateShouldNotify(TabVisibility oldWidget) =>
      visible != oldWidget.visible;
}

/// The one freshness rule for data screens (stable-release pass
/// 2026-10-12): refresh in the background when the screen becomes visible
/// (its tab is selected) and when the app resumes while it is on screen,
/// at most once per [minInterval]. The screen keeps showing what it has
/// (cached first) and calls [onRefreshWhenVisible], which must not blank
/// the screen; a light indicator is enough.
///
/// The screen still does its own first load (`initState`); that load counts
/// as a refresh for the throttle, as does a pull-to-refresh that calls
/// [markRefreshed].
mixin RefreshWhenVisible<T extends StatefulWidget> on State<T> {
  /// Minimum time between two automatic refreshes of one screen.
  static const minInterval = Duration(seconds: 30);

  /// Time source for the throttle. Tests replace it and restore it.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// The throttle's current time; providers that share the rule use it.
  static DateTime now() => clock();

  AppLifecycleListener? _lifecycle;
  DateTime? _lastRefresh;
  bool? _visible;
  bool _running = false;

  /// Refetches this screen's data in the background.
  Future<void> onRefreshWhenVisible();

  /// A pushed screen whose data lives in a shared provider (loaded
  /// elsewhere) overrides this to refresh once when it opens too.
  bool get refreshOnFirstShow => false;

  /// Restarts the throttle window (after a manual or first load).
  void markRefreshed() => _lastRefresh = clock();

  bool get _onScreen =>
      (_visible ?? true) && (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  void initState() {
    super.initState();
    if (refreshOnFirstShow) {
      _maybeRefresh();
    } else {
      markRefreshed();
    }
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted && _onScreen) _maybeRefresh();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TabVisibility.maybeOf(context) ?? true;
    final became = visible && _visible == false;
    _visible = visible;
    if (became) _maybeRefresh();
  }

  void _maybeRefresh() {
    if (_running) return;
    final last = _lastRefresh;
    if (last != null && clock().difference(last) < minInterval) return;
    markRefreshed();
    _running = true;
    // Never notify providers from inside a build: run after it.
    scheduleMicrotask(() async {
      try {
        if (mounted) await onRefreshWhenVisible();
      } catch (_) {
        // Fail soft: the screen keeps its cached data and its own error UI.
      } finally {
        _running = false;
      }
    });
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }
}
