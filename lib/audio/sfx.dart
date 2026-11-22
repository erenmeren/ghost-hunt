import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Tiny fire-and-forget sound layer. Every call is guarded: a missing audio
/// backend (tests, odd browsers) must never break the game.
class Sfx {
  Sfx();

  static const _names = [
    'waka',
    'power',
    'death',
    'eat_ghost',
    'win',
    'lose',
    'turn',
  ];

  final Map<String, List<AudioPlayer>> _pools = {};
  final Map<String, int> _next = {};
  bool _ready = false;
  bool muted = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    for (final name in _names) {
      final size = name == 'waka' ? 3 : 1;
      final pool = <AudioPlayer>[];
      for (var i = 0; i < size; i++) {
        try {
          final p = AudioPlayer();
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource('sounds/$name.wav'));
          pool.add(p);
        } catch (e) {
          debugPrint('sfx: $name unavailable ($e)');
        }
      }
      _pools[name] = pool;
      _next[name] = 0;
    }
  }

  /// [volume] 0..1, [balance] -1 (left) .. 1 (right).
  void play(String name, {double volume = 1, double balance = 0}) {
    if (muted || volume <= 0.01) return;
    final pool = _pools[name];
    if (pool == null || pool.isEmpty) return;
    final i = _next[name]! % pool.length;
    _next[name] = i + 1;
    final p = pool[i];
    unawaited(() async {
      try {
        await p.stop();
        await p.setVolume(volume.clamp(0.0, 1.0));
        try {
          await p.setBalance(balance.clamp(-1.0, 1.0));
        } catch (_) {
          /* balance unsupported on this platform */
        }
        await p.resume();
      } catch (e) {
        debugPrint('sfx: play $name failed ($e)');
      }
    }());
  }

  void stopAll() {
    for (final pool in _pools.values) {
      for (final p in pool) {
        unawaited(p.stop().catchError((_) {}));
      }
    }
  }

  void dispose() {
    for (final pool in _pools.values) {
      for (final p in pool) {
        unawaited(p.dispose().catchError((_) {}));
      }
    }
    _pools.clear();
  }
}
