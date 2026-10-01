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
import '../services/secure_screen.dart';
import '../widgets/app_shell.dart';
import '../widgets/protected_video_surface.dart';
import '../widgets/themed_error_banner.dart';
import '../widgets/themed_loading_indicator.dart';
import '../widgets/themed_panel.dart';

/// What the subject screen hands to the player: the academy's own video id and
/// text to show. It never carries the YouTube id, and so no route, argument or
/// deep link ever does.
class VideoPlayerArgs {
  const VideoPlayerArgs({
    required this.videoId,
    required this.title,
    this.description = '',
  });

  final String videoId;
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
  late final String? _watermark;

  PlayerEngine? _engine;
  StreamSubscription<PlayerSnapshot>? _subscription;
  String? _youtubeId;
  PlayerSnapshot _snapshot = const PlayerSnapshot();

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
    _watermark = context.read<AuthProvider>().watermarkText;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
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
      playback = await _catalog.requestPlayback(widget.args.videoId);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return _closeLocked();
      return _fail(_Failure.verify, e);
    } catch (e) {
      return _fail(_Failure.verify, e);
    }
    if (!mounted || _released) return;

    try {
      _youtubeId = playback.youtubeVideoId;
      final engine = _deps.engineFactory();
      _engine = engine;
      _subscription = engine.snapshots.listen(_onSnapshot);
      await engine.load(_youtubeId!);
    } catch (_) {
      // The platform has no embedded player (or it failed to start).
      return _fail(_Failure.unavailable);
    }
    if (!mounted || _released) return;
    setState(() => _stage = _Stage.playing);
    _scheduleHideControls();
  }

  /// Asks the server again (resume). 404 closes; other failures pause.
  Future<void> _revalidate() async {
    if (_released || _stage != _Stage.playing || _busy) return;
    _busy = true;
    try {
      await _deps.secureScreen.enable();
      final playback = await _catalog.requestPlayback(widget.args.videoId);
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
    _hideTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    final engine = _engine;
    _engine = null;
    _youtubeId = null;
    if (engine != null) {
      unawaited(engine.dispose().catchError((Object _) {}));
    }
    unawaited(_deps.secureScreen.disable());
    _applyFullscreenToSystem(false);
  }

  // ---- playback and controls ----------------------------------------------

  void _onSnapshot(PlayerSnapshot snapshot) {
    if (!mounted || _released) return;
    final startedPlaying = snapshot.isPlaying && !_snapshot.isPlaying;
    setState(() => _snapshot = snapshot);
    if (snapshot.phase == PlayerPhase.ended) {
      _hideTimer?.cancel();
    } else if (startedPlaying) {
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

  Future<void> _replay() async {
    final engine = _engine;
    if (engine == null) return;
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
        widget.args.title,
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
                snapshot: _snapshot,
                watermarkText: watermark,
                controlsVisible: _controlsVisible || !_snapshot.isPlaying,
                isFullscreen: _fullscreen,
                onTap: _toggleControls,
                onPlayPause: _playPause,
                onSeek: _seek,
                onToggleFullscreen: () => _setFullscreen(!_fullscreen),
                onReplay: _replay,
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
                      ThemedPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.args.title,
                              style: AppTypography.headlineSm(
                                isArabic: l10n.isArabic,
                              ),
                            ),
                            if (widget.args.description.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.spaceSm),
                              Text(
                                widget.args.description,
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
