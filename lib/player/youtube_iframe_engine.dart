import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:youtube_player_iframe/webview.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'player_engine.dart';
import 'player_hardening.dart';

/// [PlayerEngine] over `youtube_player_iframe`.
///
/// The package's own `YoutubePlayer` widget is not used: on mobile it hosts
/// the WebView in an app-wide overlay above everything, which would hide the
/// watermark and the app's controls. Instead the controller is initialised
/// directly and its WebView is placed in the screen's own widget tree.
///
/// Android is the supported target. On a platform without a WebView
/// implementation (desktop development) creating the engine throws, and the
/// player screen shows its error state.
class YoutubeIframeEngine implements PlayerEngine {
  YoutubeIframeEngine() {
    final controller = YoutubePlayerController(params: protectedPlayerParams());
    _controller = controller;
    // Replace the package's navigation policy (it opens some links in the
    // browser and loads other video ids) with "never navigate".
    controller.webViewController.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: decidePlayerNavigation,
        onPageFinished: (_) {
          controller.webViewController.runJavaScript(playerHardeningScript);
        },
      ),
    );
    _subscriptions
      ..add(controller.stream.listen(_onValue))
      ..add(controller.videoStateStream.listen(_onVideoState));
  }

  late final YoutubePlayerController _controller;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final StreamController<PlayerSnapshot> _snapshots =
      StreamController<PlayerSnapshot>.broadcast();
  PlayerSnapshot _snapshot = const PlayerSnapshot();
  Future<void>? _initialised;
  bool _disposed = false;

  /// The rate the app chose (1 until the speed menu says otherwise).
  /// Re-applied after every load: the embed resets to 1 on loadVideoById.
  double _rate = 1.0;

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  Widget buildView() =>
      WebViewWidget(controller: _controller.webViewController);

  void _emit(PlayerSnapshot next) {
    _snapshot = next;
    if (!_snapshots.isClosed) _snapshots.add(next);
  }

  void _onValue(YoutubePlayerValue value) {
    final phase = value.hasError
        ? PlayerPhase.error
        : switch (value.playerState) {
            PlayerState.playing => PlayerPhase.playing,
            PlayerState.paused => PlayerPhase.paused,
            PlayerState.ended => PlayerPhase.ended,
            PlayerState.buffering => PlayerPhase.buffering,
            _ => PlayerPhase.idle,
          };
    _emit(
      _snapshot.copyWith(
        phase: phase,
        duration: value.metaData.duration > Duration.zero
            ? value.metaData.duration
            : _snapshot.duration,
      ),
    );
  }

  void _onVideoState(YoutubeVideoState state) =>
      _emit(_snapshot.copyWith(position: state.position));

  @override
  Future<void> load(String youtubeVideoId) async {
    // Load the player page once, then load each id into it.
    _initialised ??= _controller.initWithParams(
      params: protectedPlayerParams(),
    );
    await _initialised;
    if (_disposed) return;
    await _controller.loadVideoById(videoId: youtubeVideoId);
    if (_disposed) return;
    if (_rate != 1.0) await _controller.setPlaybackRate(_rate);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    _rate = rate;
    await _controller.setPlaybackRate(rate);
  }

  @override
  Future<void> play() => _controller.playVideo();

  @override
  Future<void> pause() => _controller.pauseVideo();

  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(
    seconds: position.inMilliseconds / 1000,
    allowSeekAhead: true,
  );

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _controller.close();
    await _snapshots.close();
  }
}
