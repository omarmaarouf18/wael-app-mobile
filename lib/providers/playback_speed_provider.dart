import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../core/secure_store.dart';
import '../player/player_engine.dart';

/// The student's chosen playback speed: one app preference, not per video.
///
/// It starts at 1x, is read from the store before the first frame (like the
/// language), and every change from the player speed menu is saved. Sign-out
/// never resets it.
class PlaybackSpeedProvider extends ChangeNotifier {
  PlaybackSpeedProvider({TokenStore? store})
    // ignore: prefer_initializing_formals, public `store:` maps to `_store`
    : _store = store;

  final TokenStore? _store;
  double _rate = 1.0;

  double get rate => _rate;

  /// Rates the speed menu offers, slowest to fastest.
  static List<double> get rates => kPlaybackRates;

  static bool isSupported(double rate) => kPlaybackRates.contains(rate);

  /// Loads the saved rate, if any. A missing or unknown value means 1x.
  Future<void> load() async {
    final saved = double.tryParse(await _store?.readPlaybackSpeed() ?? '');
    final next = saved != null && isSupported(saved) ? saved : 1.0;
    if (next != _rate) {
      _rate = next;
      notifyListeners();
    }
  }

  /// Chooses [rate] (one of [rates]) and saves it. Anything else is ignored.
  void setRate(double rate) {
    if (!isSupported(rate) || rate == _rate) return;
    _rate = rate;
    unawaited(_store?.writePlaybackSpeed(rate.toString()));
    notifyListeners();
  }
}
