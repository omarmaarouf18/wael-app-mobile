import 'dart:async';

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
/// 2. a mask over the top of the embed, where YouTube draws its title,
///    channel and "copy link" (it lives inside YouTube's cross-origin iframe,
///    so it can only be hidden, not removed). It is shown while the video is
///    not playing and for [titleMaskHold] after every change to playing
///    (start, resume, replay, next lesson) and after every seek made with the
///    app's controls, because YouTube keeps the title up for a few seconds
///    then. Its height scales with the player height (the title bar is larger
///    in full screen). It covers the title area only: never the centre of the
///    video and never the bottom-right corner, so the YouTube logo stays
///    visible (owner decision 2026-10-05; the logo is inert, see below),
/// 3. a gesture layer that swallows every touch (so nothing reaches the
///    embed) and toggles the controls on tap,
/// 4. an opaque "ended" cover with a replay button, so YouTube's end-screen
///    suggestions never show (above the gesture layer so replay is tappable),
/// 5. the app's own [PlayerControls],
/// 6. the [MovingWatermark], last, so nothing can cover it.
///
/// It is the same widget in portrait and full screen: the watermark and the
/// title mask are never left out.
class ProtectedVideoSurface extends StatefulWidget {
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
    this.titleMaskHold = const Duration(seconds: 4),
    this.playbackRate = 1.0,
    this.onSelectRate,
  });

  /// The title mask is this fraction of the player height (about 56 logical
  /// pixels on a 16:9 phone in portrait), never below [titleMaskMinHeight]
  /// and never above [titleMaskMaxFraction] of the height, so it stays a bar
  /// over the title area and never reaches the centre of the video.
  static const double titleMaskFraction = 0.26;
  static const double titleMaskMinHeight = 56;
  static const double titleMaskMaxFraction = 0.30;

  /// Identifies the title mask in tests.
  @visibleForTesting
  static const Key titleMaskKey = Key('player-title-mask');

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

  /// The speed the controls show; the menu fires [onSelectRate]. Null hides
  /// the menu (the embed's own settings stay hidden regardless).
  final double playbackRate;
  final ValueChanged<double>? onSelectRate;

  /// How long the title mask stays up after the video starts playing.
  final Duration titleMaskHold;

  @override
  State<ProtectedVideoSurface> createState() => _ProtectedVideoSurfaceState();
}

class _ProtectedVideoSurfaceState extends State<ProtectedVideoSurface> {
  Timer? _holdTimer;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    if (widget.snapshot.isPlaying) _startHold();
  }

  @override
  void didUpdateWidget(ProtectedVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Not playing -> playing: start, resume, replay, next lesson, and the end
    // of the buffering that follows a seek.
    if (!oldWidget.snapshot.isPlaying && widget.snapshot.isPlaying) {
      _startHold();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  /// (Re)starts the hold. Called without setState from [initState] and
  /// [didUpdateWidget], where the build that follows reads [_holding].
  void _startHold() {
    _holdTimer?.cancel();
    _holding = true;
    _holdTimer = Timer(widget.titleMaskHold, () {
      if (!mounted) return;
      setState(() => _holding = false);
    });
  }

  void _seek(Duration position) {
    // A seek while playing may never leave the playing phase, so the app's
    // own seek restarts the hold too.
    setState(_startHold);
    widget.onSeek(position);
  }

  double _titleMaskHeight(double playerHeight) {
    const min = ProtectedVideoSurface.titleMaskMinHeight;
    final max = playerHeight * ProtectedVideoSurface.titleMaskMaxFraction;
    final wanted = playerHeight * ProtectedVideoSurface.titleMaskFraction;
    // On a surface so short that the cap is below the floor, the cap is
    // ignored: the bar is still only the top edge.
    return wanted.clamp(min, max < min ? min : max);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = widget.snapshot;
    final ended = snapshot.phase == PlayerPhase.ended;
    final loading =
        snapshot.phase == PlayerPhase.buffering ||
        snapshot.phase == PlayerPhase.idle;
    final showTitleMask = !snapshot.isPlaying || _holding;

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.scrimBlack),
          widget.video,
          // YouTube draws its title, channel and "copy link" along the top
          // while the video is not playing and for a few seconds after it
          // starts. Only the top is masked: the logo corner stays visible.
          if (showTitleMask)
            PositionedDirectional(
              key: ProtectedVideoSurface.titleMaskKey,
              top: 0,
              start: 0,
              end: 0,
              height: _titleMaskHeight(constraints.maxHeight),
              child: ColoredBox(
                color: AppColors.scrimBlack.withValues(alpha: 0.92),
              ),
            ),
          // Swallows every touch and long-press so none reaches the embed.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
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
                    onPressed: widget.onReplay,
                  ),
                ),
              ),
            ),
          if (loading && !ended)
            const Positioned.fill(
              child: IgnorePointer(child: ThemedLoadingIndicator()),
            ),
          if (widget.controlsVisible && !ended)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: PlayerControls(
                snapshot: snapshot,
                isFullscreen: widget.isFullscreen,
                onPlayPause: widget.onPlayPause,
                onSeek: _seek,
                onToggleFullscreen: widget.onToggleFullscreen,
                playbackRate: widget.playbackRate,
                onSelectRate: widget.onSelectRate,
              ),
            ),
          MovingWatermark(
            text: widget.watermarkText,
            interval: widget.watermarkInterval,
          ),
        ],
      ),
    );
  }
}
