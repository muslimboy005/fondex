import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:driver/utils/preferences.dart';

class AudioPlayerService {
  static const Duration _opTimeout = Duration(seconds: 3);
  static AudioPlayer? _audioPlayer;
  static AudioPlayer? _cancelPlayer;

  /// Race condition guard: playSound(true) async ravishda setSource() ni
  /// yuklayotgan paytda playSound(false) chaqirilsa, ovoz to'xtamasdan davom
  /// etardi (state hali "playing" emas edi). Bu flaglar orqali tartibga solinadi.
  static bool _ringtoneShouldPlay = false;
  static bool _ringtoneOperationInProgress = false;

  /// Idempotent: faqat birinchi chaqiruvda yangi AudioPlayer yaratadi.
  /// Lifecycle resume da har safar chaqirilsa ham mavjud player saqlanadi —
  /// aks holda eski instance ning state ma'lumotlari yo'qolib, ovoz to'xtatish
  /// noaniq holatga kelardi.
  static Future<void> initAudio() async {
    _audioPlayer ??= AudioPlayer(playerId: "playerId");
    _cancelPlayer ??= AudioPlayer(playerId: "cancelPlayerId");
  }

  /// Lazy initialization — har bir foydalanishdan oldin null bo'lmasligini ta'minlaydi.
  static AudioPlayer get _ringtonePlayer {
    _audioPlayer ??= AudioPlayer(playerId: "playerId");
    return _audioPlayer!;
  }

  static AudioPlayer get _alertPlayer {
    _cancelPlayer ??= AudioPlayer(playerId: "cancelPlayerId");
    return _cancelPlayer!;
  }

  static Future<void> playSound(bool isPlay) async {
    // Avval target holatni o'rnatamiz. Agar playSound(true) async davom etayotgan
    // bo'lsa va orada playSound(false) chaqirilsa, _ringtoneShouldPlay=false
    // bo'ladi va playSound(true) tugagandan keyin darhol stop() chaqiramiz.
    _ringtoneShouldPlay = isPlay;

    if (_ringtoneOperationInProgress) {
      // Boshqa playSound chaqiruvi davom etmoqda. Yangi target qabul qilindi,
      // jarayon tugagandan keyin u qaytadan sinxronlashtiradi.
      return;
    }
    _ringtoneOperationInProgress = true;
    try {
      // Loop: target o'zgarsa qaytadan sinxronlashtirish uchun
      while (true) {
        final target = _ringtoneShouldPlay;
        try {
          if (target) {
            final url = Preferences.getString(Preferences.orderRingtone);
            if (url.isEmpty) {
              return;
            }
            final player = _ringtonePlayer;
            if (player.state != PlayerState.playing) {
              await player.setSource(UrlSource(url)).timeout(_opTimeout);
              await player.setReleaseMode(ReleaseMode.loop).timeout(_opTimeout);
              await player.resume().timeout(_opTimeout);
            }
          } else {
            // state ni tekshirmaymiz — har holatda stop() chaqiramiz (paused,
            // playing, completed). Cancellation player ni ham tozalaymiz.
            await _ringtonePlayer
                .stop()
                .timeout(_opTimeout)
                .catchError((_) {});
            await _alertPlayer.stop().timeout(_opTimeout).catchError((_) {});
          }
        } catch (e) {
          // ignore: avoid_print
          print("Error in playSound op (target=$target): $e");
        }
        // Operatsiya davomida target o'zgarganmi? O'zgargan bo'lsa qayta sinxronlash.
        if (_ringtoneShouldPlay == target) break;
      }
    } finally {
      _ringtoneOperationInProgress = false;
    }
  }

  /// Customer order atkaz qilganda driver uchun qisqa ogohlantirish tovushi.
  /// Ringtone URL dan foydalanadi, lekin loop qilmaydi — faqat bir marta.
  static Future<void> playCancellationSound() async {
    try {
      final url = Preferences.getString(Preferences.orderRingtone);
      if (url.isEmpty) return;
      final player = _alertPlayer;
      await player.stop().timeout(_opTimeout).catchError((_) {});
      await player.setSource(UrlSource(url)).timeout(_opTimeout);
      await player.setReleaseMode(ReleaseMode.release).timeout(_opTimeout);
      await player.resume().timeout(_opTimeout);
    } catch (e) {
      // ignore: avoid_print
      print("Error in playCancellationSound: $e");
    }
  }

  /// Barcha audio resurslarni darhol to'xtatish (accept/reject paytida ishonchli to'xtatish uchun).
  static Future<void> stopAll() async {
    _ringtoneShouldPlay = false;
    try {
      await _ringtonePlayer.stop().timeout(_opTimeout).catchError((_) {});
    } catch (_) {}
    try {
      await _alertPlayer.stop().timeout(_opTimeout).catchError((_) {});
    } catch (_) {}
  }
}
