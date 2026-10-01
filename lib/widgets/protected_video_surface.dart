import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../player/player_engine.dart';
import 'moving_watermark.dart';
import 'player_controls.dart';
import 'themed_loading_indicator.dart';

/// The video and everything that protects and controls it, stacked in this
/// order (bottom to top):
///
/// 1. the embedded [video] (touch-less),
/// 2. masks over the places YouTube draws its own overlays: the title bar
///    while not playing, and the logo corner (both can only be hidden, not
///    removed, because they live inside YouTube's cross-origin iframe),
/// 3. a gesture layer that swallows every touch (so nothing reaches the
///    embed) and toggles the controls on tap,
/// 4. an opaque "ended" cover with a replay button, so YouTube's end-screen
///    suggestions never show (above the gesture layer so replay is tappable),
/// 5. the app's own [PlayerControls],
/// 6. the [MovingWatermark], last, so nothing can cover it.
///
/// It is the same widget in portrait and full screen: the watermark and the
/// masks are never left out.
class ProtectedVideoSurface extends StatelessWidget {
  const ProtectedVideoSurface({
    super.key,
    required this.video,
    required this.snapshot,
    required this.watermarkText,
    required this.controlsVisible,
    required this.isFullscreen,
    required this.onTap,
    required this.onPlayPause,
    required this.onSeek,
    required this.onToggleFullscreen,
    required this.onReplay,
    this.watermarkInterval = const Duration(seconds: 20),
  });

  final Widget video;
  final PlayerSnapshot snapshot;
  final String watermarkText;
  final bool controlsVisible;
  final bool isFullscreen;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onReplay;
  final Duration watermarkInterval;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ended = snapshot.phase == PlayerPhase.ended;
    final loading =
        snapshot.phase == PlayerPhase.buffering ||
        snapshot.phase == PlayerPhase.idle;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.scrimBlack),
        video,
        // YouTube's title bar appears when the video is not playing.
        if (!snapshot.isPlaying)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            height: 56,
            child: ColoredBox(
              color: AppColors.scrimBlack.withValues(alpha: 0.92),
            ),
          ),
        // YouTube's logo sits in the bottom-right corner of the embed, which
        // is the physical right edge in every locale.
        Positioned(
          right: 0,
          bottom: 0,
          width: 76,
          height: 28,
          child: const ColoredBox(color: AppColors.scrimBlack),
        ),
        // Swallows every touch and long-press so none reaches the embed.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onLongPress: () {},
          ),
        ),
        if (ended)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.scrimBlack,
              child: Center(
                child: IconButton(
                  tooltip: l10n.replayLabel,
                  iconSize: 56,
                  icon: const Icon(Icons.replay),
                  color: AppColors.textPrimary,
                  onPressed: onReplay,
                ),
              ),
            ),
          ),
        if (loading && !ended)
          const Positioned.fill(
            child: IgnorePointer(child: ThemedLoadingIndicator()),
          ),
        if (controlsVisible && !ended)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: PlayerControls(
              snapshot: snapshot,
              isFullscreen: isFullscreen,
              onPlayPause: onPlayPause,
              onSeek: onSeek,
              onToggleFullscreen: onToggleFullscreen,
            ),
          ),
        MovingWatermark(text: watermarkText, interval: watermarkInterval),
      ],
    );
  }
}
