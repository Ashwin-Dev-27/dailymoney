import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Lightweight, subtle UI sound + haptics helper.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool enabled = true;
  double volume = 0.35;
  bool hapticsEnabled = true;

  AudioPlayer? _player;
  AudioPlayer? get _safePlayer {
    if (_player != null) return _player;
    try {
      _player = AudioPlayer();
      return _player;
    } catch (_) {
      return null;
    }
  }

  Future<void> _play(String asset) async {
    if (!enabled) return;
    final player = _safePlayer;
    if (player == null) return;
    try {
      await player.stop();
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.play(AssetSource('sounds/$asset'));
    } catch (_) {
      // Never let audio break the UI.
    }
  }

  void _haptic(Future<void> Function() fn) {
    if (!hapticsEnabled) return;
    try {
      fn().catchError((_) {});
    } catch (_) {
      // Ignore platform channel errors in tests.
    }
  }

  Future<void> click() async {
    _haptic(HapticFeedback.selectionClick);
    await _play('click.wav');
  }

  Future<void> pop() async {
    _haptic(HapticFeedback.lightImpact);
    await _play('pop.wav');
  }

  Future<void> success() async {
    _haptic(HapticFeedback.mediumImpact);
    await _play('chime_success.wav');
  }

  Future<void> tick() async {
    _haptic(HapticFeedback.selectionClick);
    await _play('tick.wav');
  }

  Future<void> nav() async {
    await _play('nav.wav');
  }

  Future<void> budgetConfirm() async {
    _haptic(HapticFeedback.mediumImpact);
    await _play('budget_confirm.wav');
  }

  Future<void> goalCelebration() async {
    _haptic(HapticFeedback.heavyImpact);
    await _play('goal_celebration.wav');
  }

  Future<void> error() async {
    _haptic(HapticFeedback.vibrate);
    await _play('error.wav');
  }

  Future<void> delete() async {
    _haptic(HapticFeedback.lightImpact);
    await _play('delete.wav');
  }

  Future<void> preview(String asset) async {
    final prev = enabled;
    enabled = true;
    await _play(asset);
    enabled = prev;
  }

  void dispose() {
    _player?.dispose();
  }
}
