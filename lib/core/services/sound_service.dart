import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChessSound { move, capture, check, win, lose }

/// Playback-rate multiplier per sound pack.
/// Since tournament/minimal don't have dedicated audio files yet, we
/// differentiate them by pitch/speed so each pack genuinely sounds different.
///
/// Classic    1.00 — original warm wooden clack
/// Tournament 1.30 — faster + higher pitch → crisp digital tick feel
/// Minimal    0.72 — slower + lower pitch  → muted, subtle tap feel
const _kPackRate = {
  'classic':    1.00,
  'tournament': 1.30,
  'minimal':    0.72,
};

class SoundService {
  static const _muteKey    = 'pref_sound';      // same key as CacheService
  static const _packKey    = 'pref_sound_pack';  // same key as CacheService

  final _players = <ChessSound, AudioPlayer>{};
  bool   _muted  = false;
  double _volume = 0.75;
  String _packId = 'classic';

  bool   get isMuted => _muted;
  double get volume  => _volume;
  String get packId  => _packId;

  SoundService() {
    for (final s in ChessSound.values) {
      _players[s] = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    }
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _muted  = !(prefs.getBool(_muteKey) ?? true);
    _packId =  prefs.getString(_packKey) ?? 'classic';
  }

  void setEnabled(bool enabled) {
    _muted = !enabled;
  }

  /// Updates the active sound pack without restarting the service.
  void setPackId(String packId) {
    _packId = packId;
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    for (final player in _players.values) {
      await player.setVolume(_volume);
    }
  }

  Future<void> play(ChessSound sound) async {
    if (_muted) return;
    final player = _players[sound]!;
    final rate   = _kPackRate[_packId] ?? 1.0;
    // Apply pack-specific playback rate (changes pitch + speed).
    try { await player.setPlaybackRate(rate); } catch (_) {}

    final path = _assetPath(sound, _packId);
    try {
      await player.play(AssetSource(path));
    } catch (_) {
      // Pack-specific file not found → fall back to classic at same rate.
      if (_packId != 'classic') {
        try {
          await player.play(AssetSource(_assetPath(sound, 'classic')));
        } catch (_) {}
      }
    }
  }

  /// Returns the asset path for [sound] in [packId].
  /// Pack folder convention: `sounds/<packId>/<file>`.
  /// Classic (default) pack lives directly in `sounds/`.
  String _assetPath(ChessSound sound, String packId) {
    final file = switch (sound) {
      ChessSound.move    => 'move.mp3',
      ChessSound.capture => 'capture.mp3',
      ChessSound.check   => 'check.mp3',
      ChessSound.win     => 'win.mp3',
      ChessSound.lose    => 'lose.mp3',
    };
    return packId == 'classic' ? 'sounds/$file' : 'sounds/$packId/$file';
  }

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
  }
}

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  ref.onDispose(service.dispose);
  return service;
});
