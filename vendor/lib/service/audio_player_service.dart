import 'dart:async';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:vendor/utils/preferences.dart';

class AudioPlayerService {
  static late AudioPlayer _audioPlayer;

  static String _ringtoneLogPreview(String ring) {
    if (ring.isEmpty) return '(empty)';
    if (ring.startsWith('data:')) {
      return 'data:... (${ring.length} chars)';
    }
    if (ring.length > 80) {
      return '${ring.substring(0, 80)}... (${ring.length} chars)';
    }
    return ring;
  }

  static Future<void> initAudio() async {
    _audioPlayer = AudioPlayer(playerId: "playerId");
  }

  static Future<void> playSound(bool isPlay) async {
    try {
      if (isPlay) {
        if (_audioPlayer.state != PlayerState.playing) {
          final ring = Preferences.getString(Preferences.orderRingtone);
          log("PlaySound :: 11 :: $isPlay :: ${_ringtoneLogPreview(ring)}");
          await _audioPlayer.setSource(UrlSource(ring)).timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('setSource timed out'),
          );
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.resume();
        }
      } else {
        if (_audioPlayer.state != PlayerState.stopped) {
          log("PlaySound :: 22 :: $isPlay :: ${_ringtoneLogPreview(Preferences.getString(Preferences.orderRingtone))}");
          await _audioPlayer.stop();
        }
      }
    } catch (e) {
      print("Error in playSound: $e");
    }
  }
}
