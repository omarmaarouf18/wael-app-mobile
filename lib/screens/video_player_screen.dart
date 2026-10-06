import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/error_messages.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/academy_catalog.dart';
import '../player/player_engine.dart';
import '../providers/academy_catalog_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/playback_speed_provider.dart';
import '../services/secure_screen.dart';
import '../widgets/app_shell.dart';
import '../widgets/player_next_cards.dart';
import '../widgets/protected_video_surface.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_loading_indicator.dart';
import '../widgets/themed_panel.dart';

/// What the subject screen hands to the player: the academy's own video id,
/// the subject it belongs to (so the player can offer the next lesson from
/// the catalog provider) and text to show. It never carries the YouTube id,
/// and so no route, argument or deep link ever does.
class VideoPlayerArgs {
  const VideoPlayerArgs({
    required this.videoId,
    required this.subjectId,
    required this.title,
    this.description = '',
  });

  final String videoId;

  /// The academy's own subject id, never a YouTube id.
  final String subjectId;
  final String title;
  final String description;
}

/// How the player screen ended.
enum PlayerExit {
  /// The student left.
  closed,

  /// The server answered 404 on open or on resume: the video is not playable
  /// (any more). The caller shows its locked state.
  locked,
}

enum _Stage { starting, playing, failed }

enum _Failure { noIdentity, notSecure, unavailable, verify }

/// Protected video player.
///
/// - On open it makes the screen secure (Android FLAG_SECURE: no screenshots
///   or recording), asks the server to play the video, and only then loads the
///   YouTube id it got into the embed. The id lives in [_youtubeId] for as
///   long as this screen exists and nowhere else: not stored, cached, logged,
///   shown or passed on.
/// - On every resume it asks again; a 404 closes the player with
///   [PlayerExit.locked].
/// - A moving watermark with the student's identity stays over the video, in
///   full screen too. Without an identity it refuses to play.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.args});

  final VideoPlayerArgs args;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  late final PlayerDependencies _deps;
  late final AcademyCatalogProvider _catalog;
  late final PlaybackSpeedProvider _speed;
  late final String? _watermark;

  PlayerEngine? _engine;
  StreamSubscription<PlayerSnapshot>? _subscription;
  String? _youtubeId;
  PlayerSnapshot _snapshot = const PlayerSnapshot();

  /// The lesson on screen now. It starts as [VideoPlayerArgs] and moves to
  /// the next lesson when the student advances; the subject id never changes.
  late String _currentVideoId;
  late String _currentTitle;
  late String _currentDescription;

  /// True while the next lesson is being fetched and loaded. The surface
  /// keeps showing the ended cover (not a spinner) until the new video
  /// reports back, so YouTube's end screen and the new title never show.
  bool _loadingNext = false;

  /// The 5-second auto-advance after a video ends. Cancelling it leaves a
  /// static next-lesson button instead.
  Timer? _countdownTimer;
  int _countdownLeft = 0;
  bool _countdownCancelled = false;

  bool get _countdownActive => _countdownTimer?.isActive ?? false;

  _Stage _stage = _Stage.starting;
  _Failure? _failure;
  Object? _failureCause;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  bool _released = false;
  bool _busy = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _deps = context.read<PlayerDependencies>();
    _catalog = context.read<AcademyCatalogProvider>();
    _speed = context.read<PlaybackSpeedProvider>();
    _watermark = context.read<AuthProvider>().watermarkText;
    _currentVideoId = widget.args.videoId;
    _currentTitle = widget.args.title;
    _currentDescription = widget.args.description;
    // The subject screen has usually loaded its detail already; when it has
    // not (or it changed meanwhile), load it so the next-lesson button can
    // resolve the ordered lesson list. Its notification rebuilds this
    // screen (the build watches the catalog). Deferred a frame: loading
    // notifies at once, which is illegal during the first build.
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_catalog.detailOf(widget.args.subjectId).detail == null) {
        _catalog.loadDetail(widget.args.subjectId);
      }
      _start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  // ---- lifecycle -----------------------------------------------------------

  Future<void> _start() async {
    if (_released) return;
    setState(() {
      _stage = _Stage.starting;
      _failure = null;
      _failureCause = null;
    });
    if (_watermark == null) return _fail(_Failure.noIdentity);
    try {
      await _deps.secureScreen.enable();
    } on SecureScreenException {
      return _fail(_Failure.notSecure);
    }
    if (!mounted || _released) return;

    final VideoPlayback playback;
    try {
      playback = await _catalog.requestPlayback(_currentVideoId);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return _closeLocked();
      return _fail(_Failure.verify, e);
    } catch (e) {
      return _fail(_Failure.verify, e);
    }
    if (!mounted || _released) return;

    if (!await _swapEngine(playback.youtubeVideoId)) {
      // The platform has no embedded player (or it failed to start).
      return _fail(_Failure.unavailable);
    }
    if (!mounted || _released) return;
    setState(() => _stage = _Stage.playing);
    _scheduleHideControls();
  }

  /// Loads [youtubeVideoId] into a fresh engine and swaps it in, disposing
  /// the old one. Snapshots (and so the ended cover and the title mask) are
  /// untouched until the new engine reports; false when the load failed and
  /// the old surface, if any, is still in place.
  ///
  /// Cancellations and disposals are fire-and-forget on purpose: the old
  /// release path did the same, and awaiting a broadcast cancel stalls the
  /// UI (and hangs widget tests under FakeAsync) while buying nothing, since
  /// the disposed engine's stream closes anyway.
  Future<bool> _swapEngine(String youtubeVideoId) async {
    final engine = _deps.engineFactory();
    final sub = engine.snapshots.listen(_onSnapshot);
    try {
      await engine.load(youtubeVideoId);
      await engine.setPlaybackRate(_speed.rate);
    } catch (_) {
      unawaited(sub.cancel());
      unawaited(engine.dispose().catchError((Object _) {}));
      return false;
    }
    if (!mounted || _released) {
      unawaited(sub.cancel());
      unawaited(engine.dispose().catchError((Object _) {}));
      return false;
    }
    final oldSub = _subscription;
    if (oldSub != null) unawaited(oldSub.cancel());
    _subscription = sub;
    final old = _engine;
    _engine = engine;
    _youtubeId = youtubeVideoId;
    if (old != null) {
      unawaited(old.dispose().catchError((Object _) {}));
    }
    return true;
  }

  /// Drops the engine the surface shows, keeping FLAG_SECURE and the system
  /// UI alone (next-lesson loads swap engines without leaving the screen).
  /// Synchronous like the old release path: disposal is invoked at once so
  /// leaving the screen never waits on a stream cancel.
  void _disposeEngine() {
    _hideTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    final engine = _engine;
    _engine = null;
    _youtubeId = null;
    if (engine != null) {
      unawaited(engine.dispose().catchError((Object _) {}));
    }
  }

  /// Asks the server again (resume). 404 closes; other failures pause.
  Future<void> _revalidate() async {
    if (_released || _stage != _Stage.playing || _busy) return;
    _busy = true;
    try {
      await _deps.secureScreen.enable();
      final playback = await _catalog.requestPlayback(_currentVideoId);
      if (!mounted || _released) return;
      if (playback.youtubeVideoId != _youtubeId) {
        // The academy replaced the video: load the new one.
        _youtubeId = playback.youtubeVideoId;
        await _engine?.load(_youtubeId!);
      }
      if (_failure != null) setState(() => _failure = null);
    } on SecureScreenException {
      await _engine?.pause();
      if (mounted) _fail(_Failure.notSecure);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        _closeLocked();
      } else {
        await _engine?.pause();
        if (mounted) _failVerifyWhilePlaying(e);
      }
    } catch (e) {
      await _engine?.pause();
      if (mounted) _failVerifyWhilePlaying(e);
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_released) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _engine?.pause();
      case AppLifecycleState.resumed:
        _revalidate();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _fail(_Failure failure, [Object? cause]) {
    if (!mounted) return;
    _engine?.pause();
    setState(() {
      _stage = _Stage.failed;
      _failure = failure;
      _failureCause = cause;
    });
  }

  /// A failed re-check while the player is open: keep the player, pause it,
  /// and show the banner under it (leaving full screen so it is visible).
  void _failVerifyWhilePlaying(Object cause) {
    _setFullscreen(false);
    setState(() {
      _failure = _Failure.verify;
      _failureCause = cause;
    });
  }

  void _closeLocked() {
    if (!mounted) return;
    _release();
    Navigator.of(context).pop(PlayerExit.locked);
  }

  /// Drops everything this screen holds. Safe to call more than once.
  void _release() {
    if (_released) return;
    _released = true;
    _cancelCountdown();
    _disposeEngine();
    unawaited(_deps.secureScreen.disable());
    _applyFullscreenToSystem(false);
  }

  // ---- next lesson ----------------------------------------------------------

  /// The ordered lesson list comes from the catalog provider (cached subject
  /// detail); route arguments never carry it, and never YouTube ids.
  AcademyVideo? _nextVideo() => _catalog.nextPlayableVideo(
    subjectId: widget.args.subjectId,
    videoId: _currentVideoId,
  );

  /// Starts the countdown after a video ends, when a playable next lesson
  /// exists and the student did not cancel it.
  void _maybeStartCountdown() {
    if (_released || _loadingNext || _countdownActive || _countdownCancelled) {
      return;
    }
    if (_nextVideo() == null) return;
    _countdownLeft = 5;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _released) return;
      if (_countdownLeft <= 1) {
        _startNext();
      } else {
        setState(() => _countdownLeft--);
      }
    });
    if (mounted) setState(() {});
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _cancelCountdownFromCard() {
    _cancelCountdown();
    _countdownCancelled = true;
    if (mounted) setState(() {});
  }

  /// Advances to the next playable lesson. The ended cover stays up and the
  /// title mask re-holds for 4 s once the new video plays (see
  /// [_surfaceSnapshot]); a 404 closes through the existing locked path.
  Future<void> _startNext() async {
    if (_released || _loadingNext) return;
    final next = _nextVideo();
    if (next == null) return;
    _cancelCountdown();
    final isArabic = AppLocalizations.of(context).isArabic;
    _busy = true;
    _loadingNext = true;
    _countdownCancelled = false;
    _currentVideoId = next.id;
    _currentTitle = next.title.resolve(isArabic);
    _currentDescription = next.description.resolve(isArabic);
    if (mounted) setState(() {});
    try {
      final playback = await _catalog.requestPlayback(_currentVideoId);
      if (!mounted || _released) return;
      if (!await _swapEngine(playback.youtubeVideoId)) {
        _loadingNext = false;
        await _engine?.pause();
        if (mounted) _failVerifyWhilePlaying(StateError('engine swap'));
        return;
      }
      if (!mounted || _released) return;
      if (mounted) setState(() => _stage = _Stage.playing);
      _scheduleHideControls();
    } on ApiException catch (e) {
      if (!mounted || _released) return;
      _loadingNext = false;
      if (e.statusCode == 404) {
        _closeLocked();
      } else {
        await _engine?.pause();
        if (mounted) _failVerifyWhilePlaying(e);
      }
    } catch (e) {
      if (!mounted || _released) return;
      _loadingNext = false;
      await _engine?.pause();
      if (mounted) _failVerifyWhilePlaying(e);
    } finally {
      _busy = false;
    }
  }

  // ---- playback and controls ----------------------------------------------

  void _onSnapshot(PlayerSnapshot snapshot) {
    if (!mounted || _released) return;
    final startedPlaying = snapshot.isPlaying && !_snapshot.isPlaying;
    // The next video answered: the loading cover hands over to the live
    // surface (whose title mask re-holds for 4 s on this transition).
    if (_loadingNext &&
        snapshot.phase != PlayerPhase.ended &&
        snapshot.phase != PlayerPhase.buffering &&
        snapshot.phase != PlayerPhase.idle) {
      _loadingNext = false;
      _busy = false;
    }
    setState(() => _snapshot = snapshot);
    if (snapshot.phase == PlayerPhase.ended) {
      _hideTimer?.cancel();
      _maybeStartCountdown();
    } else if (startedPlaying) {
      if (_countdownActive) _cancelCountdown();
      // Playback just began: let the controls fade after a moment.
      _scheduleHideControls();
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _snapshot.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHideControls();
  }

  void _playPause() {
    final engine = _engine;
    if (engine == null) return;
    if (_snapshot.isPlaying || _snapshot.phase == PlayerPhase.buffering) {
      engine.pause();
      _hideTimer?.cancel();
    } else {
      engine.play();
      _scheduleHideControls();
    }
  }

  void _seek(Duration position) => _engine?.seekTo(position);

  /// The speed menu chose [rate]: the embed applies it now and the choice is
  /// saved as the one app preference (not per video).
  void _selectRate(double rate) {
    _speed.setRate(rate);
    unawaited(_engine?.setPlaybackRate(rate));
    // The controls read the provider, so they show the new rate at once.
    setState(() {});
  }

  Future<void> _replay() async {
    final engine = _engine;
    if (engine == null || _loadingNext) return;
    // A fresh watch restarts the end-of-video countdown on the next end.
    _cancelCountdown();
    _countdownCancelled = false;
    await engine.seekTo(Duration.zero);
    await engine.play();
  }

  void _setFullscreen(bool value) {
    if (_fullscreen == value) return;
    setState(() => _fullscreen = value);
    _applyFullscreenToSystem(value);
  }

  void _applyFullscreenToSystem(bool fullscreen) {
    if (fullscreen) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations(const []);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // ---- UI ------------------------------------------------------------------

  /// What the surface shows. While the next lesson loads, the last reported
  /// snapshot (ended) is kept, so the ended cover stays up and YouTube's
  /// end screen and the new title never show; the first playing snapshot
  /// ends the hold and restarts the surface's 4 s title-mask hold.
  PlayerSnapshot get _surfaceSnapshot =>
      _loadingNext ? _snapshot.copyWith(phase: PlayerPhase.ended) : _snapshot;

  String _failureMessage(AppLocalizations l10n) => switch (_failure!) {
    _Failure.noIdentity => l10n.playerNoIdentity,
    _Failure.notSecure => l10n.playerNotSecure,
    _Failure.unavailable => l10n.playerUnavailable,
    _Failure.verify => ErrorMessages.forCatalog(
      _failureCause ?? ApiException(statusCode: -1, message: ''),
      isArabic: l10n.isArabic,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The ordered lesson list may arrive after the detail loads.
    context.watch<AcademyCatalogProvider>();

    final Widget body;
    switch (_stage) {
      case _Stage.starting:
        body = ThemedLoadingIndicator(label: l10n.playerStarting);
      case _Stage.failed:
        body = Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.marginMobile),
            child: ThemedErrorBanner(
              message: _failureMessage(l10n),
              // Only a failed check is worth retrying; the others are fixed
              // by the account or the device.
              onRetry: _failure == _Failure.verify ? _start : null,
            ),
          ),
        );
      case _Stage.playing:
        body = _playerLayout(l10n);
    }

    return AppShell(
      showHeader: !_fullscreen,
      showBack: true,
      titleWidget: Text(
        _currentTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.headlineSm(isArabic: l10n.isArabic),
      ),
      body: body,
    );
  }

  Widget _playerLayout(AppLocalizations l10n) {
    final engine = _engine;
    final watermark = _watermark;
    if (engine == null || watermark == null) return const SizedBox.shrink();
    final snapshot = _surfaceSnapshot;
    final ended = snapshot.phase == PlayerPhase.ended;

    // Ended-cover footer: the auto-advance countdown while it runs, a
    // static next-lesson button once cancelled, or the last-lesson end
    // card. Nothing extra while the next video loads: the cover stays.
    final next = _nextVideo();
    final Widget? endedFooter;
    if (!ended || _loadingNext) {
      endedFooter = null;
    } else if (_countdownActive && next != null) {
      endedFooter = NextCountdownCard(
        title: next.title.resolve(l10n.isArabic),
        secondsLeft: _countdownLeft,
        onCancel: _cancelCountdownFromCard,
      );
    } else if (next != null) {
      endedFooter = NextLessonButton(
        title: next.title.resolve(l10n.isArabic),
        onTap: _startNext,
      );
    } else if (_catalog.isLastVideo(
      subjectId: widget.args.subjectId,
      videoId: _currentVideoId,
    )) {
      endedFooter = SubjectEndCard(onBack: () => Navigator.of(context).pop());
    } else {
      endedFooter = null;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The surface is the first child in both layouts, so entering and
        // leaving full screen keeps the same element (the WebView is not
        // rebuilt); only its aspect ratio changes.
        final ratio = _fullscreen
            ? constraints.maxWidth / constraints.maxHeight
            : 16 / 9;
        return Column(
          children: [
            AspectRatio(
              aspectRatio: ratio,
              child: ProtectedVideoSurface(
                video: engine.buildView(),
                snapshot: snapshot,
                watermarkText: watermark,
                controlsVisible: _controlsVisible || !snapshot.isPlaying,
                isFullscreen: _fullscreen,
                onTap: _toggleControls,
                onPlayPause: _playPause,
                onSeek: _seek,
                onToggleFullscreen: () => _setFullscreen(!_fullscreen),
                onReplay: _replay,
                playbackRate: _speed.rate,
                onSelectRate: _selectRate,
                endedFooter: endedFooter,
              ),
            ),
            if (!_fullscreen)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.all(
                    AppSpacing.marginMobile,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_failure == _Failure.verify) ...[
                        ThemedErrorBanner(
                          message: _failureMessage(l10n),
                          onRetry: _revalidate,
                        ),
                        const SizedBox(height: AppSpacing.spaceMd),
                      ],
                      // The next lesson, while this one still plays. At the
                      // end the cover footer takes over.
                      if (next != null && !ended && !_loadingNext) ...[
                        NextLessonButton(
                          title: next.title.resolve(l10n.isArabic),
                          onTap: _startNext,
                        ),
                        const SizedBox(height: AppSpacing.spaceMd),
                      ],
                      ThemedPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentTitle,
                              style: AppTypography.headlineSm(
                                isArabic: l10n.isArabic,
                              ),
                            ),
                            if (_currentDescription.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.spaceSm),
                              Text(
                                _currentDescription,
                                style: AppTypography.bodyMd(
                                  isArabic: l10n.isArabic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
