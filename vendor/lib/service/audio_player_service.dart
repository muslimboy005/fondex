import 'dart:async';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:vendor/utils/preferences.dart';

class AudioPlayerService {
  static const Duration _opTimeout = Duration(seconds: 12);
  static AudioPlayer? _audioPlayer;

  /// Race condition guard: playSound(true) async ravishda setSource() ni
  /// yuklayotgan paytda playSound(false) chaqirilsa, ovoz to'xtamasdan davom
  /// etardi (state hali "playing" emas edi). Bu flaglar orqali tartibga solinadi.
  static bool _ringtoneShouldPlay = false;
  static bool _ringtoneOperationInProgress = false;

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

  /// Idempotent: faqat birinchi chaqiruvda yangi AudioPlayer yaratadi.
  /// Lifecycle resume da har safar chaqirilsa ham mavjud player saqlanadi —
  /// aks holda eski instance ning state ma'lumotlari yo'qolib, ovoz to'xtatish
  /// noaniq holatga kelardi.
  static Future<void> initAudio() async {
    _audioPlayer ??= AudioPlayer(playerId: "playerId");
  }

  /// Lazy initialization — har bir foydalanishdan oldin null bo'lmasligini ta'minlaydi.
  static AudioPlayer get _ringtonePlayer {
    _audioPlayer ??= AudioPlayer(playerId: "playerId");
    return _audioPlayer!;
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
            final ring = Preferences.getString(Preferences.orderRingtone);
            if (ring.isEmpty) {
              return;
            }
            log("PlaySound :: 11 :: $target :: ${_ringtoneLogPreview(ring)}");
            final player = _ringtonePlayer;
            if (player.state != PlayerState.playing) {
              await player.setSource(UrlSource(ring)).timeout(_opTimeout);
              await player.setReleaseMode(ReleaseMode.loop).timeout(_opTimeout);
              await player.resume().timeout(_opTimeout);
            }
          } else {
            // state ni tekshirmaymiz — har holatda stop() chaqiramiz (paused,
            // playing, completed). setSource davom etayotgan bo'lsa ham, target
            // bayrog'i false bo'lgani uchun keyingi iteratsiyada stop ishlaydi.
            log("PlaySound :: 22 :: $target :: ${_ringtoneLogPreview(Preferences.getString(Preferences.orderRingtone))}");
            await _ringtonePlayer
                .stop()
                .timeout(_opTimeout)
                .catchError((_) {});
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

  /// Barcha audio resurslarni darhol to'xtatish (accept/reject paytida ishonchli to'xtatish uchun).
  static Future<void> stopAll() async {
    _ringtoneShouldPlay = false;
    try {
      await _ringtonePlayer.stop().timeout(_opTimeout).catchError((_) {});
    } catch (_) {}
  }
}
