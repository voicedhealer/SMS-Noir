import 'package:audio_session/audio_session.dart';

/// Deux usages du son, deux politiques.
///
/// Elles ne sont pas interchangeables : une note vocale et une musique
/// d'ambiance n'ont pas les mêmes droits sur le téléphone du joueur.
class AudioSessionConfig {
  const AudioSessionConfig._();

  /// **Musique d'intronisation** — catégorie `ambient`.
  ///
  /// Respecte le mode silencieux, et **ne coupe pas** la musique que le joueur
  /// écoutait déjà. C'est une ambiance : si le téléphone est en silencieux,
  /// c'est que son propriétaire a dit non.
  static Future<void> ambiance() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidWillPauseWhenDucked: false,
    ));
  }

  /// **Note vocale de Léna** — catégorie `playback`.
  ///
  /// Se joue même en mode silencieux, et interrompt le reste. C'est le
  /// comportement de toutes les messageries : une note vocale qu'on tape
  /// explicitement doit s'entendre. Et ici elle porte un indice — un vocal muet
  /// rendrait l'incohérence du fond sonore (bible §7 n°3) inatteignable.
  static Future<void> notevocale() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ));
    await session.setActive(true);
  }
}
