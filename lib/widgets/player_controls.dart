import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../player/player_engine.dart';

String formatPlayerTime(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// The player's own control bar (the embedded one is hidden): play or pause,
/// 10-second jumps, a seek slider with times, playback speed and full screen.
/// The time row is always left to right, like every media player.
///
/// The speed menu lives here, in the app's own bar, never inside the embed:
/// [playbackRate] is the current choice, [onSelectRate] fires for a new one.
class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.snapshot,
    required this.isFullscreen,
    required this.onPlayPause,
    required this.onSeek,
    required this.onToggleFullscreen,
    this.playbackRate = 1.0,
    this.onSelectRate,
  });

  final PlayerSnapshot snapshot;
  final bool isFullscreen;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onToggleFullscreen;
  final double playbackRate;
  final ValueChanged<double>? onSelectRate;

  Duration _clamp(Duration d) {
    if (d < Duration.zero) return Duration.zero;
    if (snapshot.duration > Duration.zero && d > snapshot.duration) {
      return snapshot.duration;
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = snapshot.duration;
    final position = snapshot.position > total && total > Duration.zero
        ? total
        : snapshot.position;
    final max = total.inMilliseconds.toDouble();
    final playing =
        snapshot.isPlaying || snapshot.phase == PlayerPhase.buffering;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.spaceSm,
        vertical: AppSpacing.spaceXs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.scrimBlack.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  formatPlayerTime(position),
                  style: AppTypography.labelSm(),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: AppColors.crimson,
                      inactiveTrackColor: AppColors.textPrimary.withValues(
                        alpha: 0.25,
                      ),
                      thumbColor: AppColors.crimson,
                      overlayColor: AppColors.crimson.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: max <= 0
                          ? 0
                          : position.inMilliseconds.toDouble().clamp(0, max),
                      max: max <= 0 ? 1 : max,
                      onChanged: max <= 0
                          ? null
                          : (v) => onSeek(Duration(milliseconds: v.round())),
                    ),
                  ),
                ),
                Text(formatPlayerTime(total), style: AppTypography.labelSm()),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 48dp like the full-screen button on the other end, so the
                // middle cluster stays centred.
                SizedBox(
                  width: 48,
                  child: onSelectRate == null
                      ? const SizedBox.shrink()
                      : PopupMenuButton<double>(
                          tooltip: l10n.playbackSpeed,
                          initialValue: playbackRate,
                          onSelected: onSelectRate,
                          itemBuilder: (context) => [
                            for (final rate in kPlaybackRates)
                              PopupMenuItem<double>(
                                value: rate,
                                child: Row(
                                  children: [
                                    if (rate == playbackRate)
                                      const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: AppColors.textPrimary,
                                      )
                                    else
                                      const SizedBox(width: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      playbackRateLabel(rate),
                                      style: AppTypography.labelMd().copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: rate == playbackRate
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                playbackRateLabel(playbackRate),
                                style: AppTypography.labelSm().copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.rewind10,
                      icon: const Icon(Icons.replay_10),
                      color: AppColors.textPrimary,
                      onPressed: () => onSeek(
                        _clamp(position - const Duration(seconds: 10)),
                      ),
                    ),
                    IconButton(
                      tooltip: playing ? l10n.pauseLabel : l10n.playLabel,
                      iconSize: 36,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      color: AppColors.textPrimary,
                      onPressed: onPlayPause,
                    ),
                    IconButton(
                      tooltip: l10n.forward10,
                      icon: const Icon(Icons.forward_10),
                      color: AppColors.textPrimary,
                      onPressed: () => onSeek(
                        _clamp(position + const Duration(seconds: 10)),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: isFullscreen
                      ? l10n.exitFullscreen
                      : l10n.enterFullscreen,
                  icon: Icon(
                    isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                  color: AppColors.textPrimary,
                  onPressed: onToggleFullscreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
