import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wael_app/player/player_engine.dart';
import 'package:wael_app/services/secure_screen.dart';

/// Stands in for the YouTube WebView. Records what the screen asks of it and
/// lets a test push playback snapshots. Its view shows no text, so a YouTube
/// id passed to [load] can never appear in the widget tree through it.
class FakePlayerEngine implements PlayerEngine {
  FakePlayerEngine({this.failOnLoad = false});

  final bool failOnLoad;
  final List<String> loadedIds = [];
  final List<String> calls = [];
  final StreamController<PlayerSnapshot> _controller =
      StreamController<PlayerSnapshot>.broadcast();
  bool disposed = false;

  void emit(PlayerSnapshot snapshot) => _controller.add(snapshot);

  @override
  Stream<PlayerSnapshot> get snapshots => _controller.stream;

  @override
  Widget buildView() => const SizedBox.expand(key: Key('fake-video'));

  @override
  Future<void> load(String youtubeVideoId) async {
    if (failOnLoad) throw StateError('no webview');
    loadedIds.add(youtubeVideoId);
    calls.add('load');
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seekTo(Duration position) async =>
      calls.add('seek:${position.inSeconds}');

  @override
  Future<void> dispose() async {
    disposed = true;
    calls.add('dispose');
    await _controller.close();
  }
}

/// [SecureScreen] that records calls instead of using the Android channel.
class FakeSecureScreen extends SecureScreen {
  FakeSecureScreen({this.enableError = false})
    : super(platform: TargetPlatform.android);

  final bool enableError;
  final List<String> log = [];
  bool enabled = false;

  @override
  Future<void> enable() async {
    log.add('enable');
    if (enableError) throw SecureScreenException('boom');
    enabled = true;
  }

  @override
  Future<void> disable() async {
    log.add('disable');
    enabled = false;
  }

  @override
  Future<bool> isEnabled() async => enabled;
}
