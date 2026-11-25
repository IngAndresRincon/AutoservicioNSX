import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'service.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _audioContextConfigured = false;

  /// Evita que estos audios de notificación le quiten el foco de audio al
  /// video de publicidad de fondo (que lo pausaría). Se reproducen mezclados
  /// en vez de interrumpir lo que ya está sonando.
  static Future<void> _ensureAudioContext() async {
    if (_audioContextConfigured) return;
    _audioContextConfigured = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error configurando AudioContext: $e");
    }
  }

  static Future<void> playTransition(String fileName) async {
    try {
      await _ensureAudioContext();
      final audioUrl = await ResourceService.getAudioUrl(fileName);
      debugPrint("🎵 Reproduciendo audio: $audioUrl");

      await _player.play(UrlSource(audioUrl));
    } catch (e) {
      debugPrint("❌ Error al reproducir audio: $e");
    }
  }

  // Por si necesitas detenerlo bruscamente
  static Future<void> stop() async => await _player.stop();
}