import 'package:flutter/widgets.dart';

import '../services/secure_screen.dart';

/// Coarse playback phase reported by an embedded player.
enum PlayerPhase { idle, buffering, playing, paused, ended, error }

/// What the screen needs to know about playback right now.
class PlayerSnapshot {
  const PlayerSnapshot({
    this.phase = PlayerPhase.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final PlayerPhase phase;
  final Duration position;
  final Duration duration;

  bool get isPlaying => phase == PlayerPhase.playing;

  PlayerSnapshot copyWith({
    PlayerPhase? phase,
    Duration? position,
    Duration? duration,
  }) => PlayerSnapshot(
    phase: phase ?? this.phase,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );
}

/// An embedded video player the protected player screen drives.
///
/// The YouTube video id passed to [load] is the only place it enters an
/// engine; implementations must keep it in memory only and never log or
/// persist it.
abstract class PlayerEngine {
  Stream<PlayerSnapshot> get snapshots;

  /// The surface that shows the video. It receives no touches: the screen
  /// puts its own gesture layer and controls above it.
  Widget buildView();

  /// Loads [youtubeVideoId] and starts playing.
  Future<void> load(String youtubeVideoId);

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);

  /// Stops playback and releases the player.
  Future<void> dispose();
}

typedef PlayerEngineFactory = PlayerEngine Function();

/// What the player screen needs from the outside, provided once near the app
/// root so tests can replace the real player and the Android channel.
class PlayerDependencies {
  PlayerDependencies({required this.engineFactory, SecureScreen? secureScreen})
    : secureScreen = secureScreen ?? SecureScreen();

  final PlayerEngineFactory engineFactory;
  final SecureScreen secureScreen;
}
