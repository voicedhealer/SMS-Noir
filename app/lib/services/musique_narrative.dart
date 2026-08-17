import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'audio_session_config.dart';

/// Musique d'intronisation.
///
/// Service à instance unique, et non un lecteur possédé par l'écran d'intro.
///
/// **Pourquoi** : la coupure nette à la transition est un acte délibéré de mise
/// en scène — le silence brutal fait partie de l'effet. En faire un effet de
/// bord du `dispose()` d'un widget, c'est la confier à l'ordre de destruction
/// de l'arbre. Une reconstruction de l'écran au mauvais moment, et un second
/// lecteur démarre pendant que le premier tourne toujours, sans que personne
/// ne détienne plus la référence pour l'arrêter. C'est exactement ce qui
/// arrivait au bouton de réinitialisation : la musique ne s'arrêtait plus.
///
/// Ici, [demarrer] coupe systématiquement ce qui jouait avant. Il ne peut donc
/// jamais y avoir deux musiques en même temps, quel que soit le cycle de vie
/// des écrans.
class MusiqueNarrative {
  MusiqueNarrative._();
  static final MusiqueNarrative instance = MusiqueNarrative._();

  AudioPlayer? _lecteur;
  int _generation = 0;

  /// Volume cible : c'est une ambiance, pas une bande-son.
  static const double _volume = 0.45;

  /// Montée très courte : la musique doit être là dès le premier mot.
  static const Duration fondu = Duration(milliseconds: 500);

  bool get joue => _lecteur?.playing ?? false;

  /// Démarre la musique en fondu montant. Coupe toujours la précédente.
  Future<void> demarrer(String url) async {
    await arreter();
    final generation = ++_generation;
    try {
      // Catégorie « ambient » : respecte le mode silencieux du téléphone et ne
      // coupe pas la musique que le joueur écoutait déjà.
      await AudioSessionConfig.ambiance();
      final lecteur = AudioPlayer();
      if (generation != _generation) {
        await lecteur.dispose();
        return;
      }
      _lecteur = lecteur;
      await lecteur.setUrl(url);
      await lecteur.setVolume(0);
      await lecteur.setLoopMode(LoopMode.off); // une seule lecture, jamais en boucle
      if (generation != _generation) return;
      unawaited(lecteur.play());
      await _monter(lecteur, generation);
    } catch (_) {
      // Une musique absente ou illisible ne doit jamais empêcher l'histoire de
      // commencer : la séquence se joue en silence.
      await arreter();
    }
  }

  Future<void> _monter(AudioPlayer lecteur, int generation) async {
    const pas = 20;
    for (var i = 1; i <= pas; i++) {
      await Future<void>.delayed(fondu ~/ pas);
      if (generation != _generation) return;
      await lecteur.setVolume(_volume * i / pas);
    }
  }

  /// Coupure **nette** : pas de fondu descendant. Le silence brutal qui suit
  /// fait partie de l'effet, et les 4 secondes de vide doivent être muettes.
  Future<void> arreter() async {
    _generation++;
    final lecteur = _lecteur;
    _lecteur = null;
    if (lecteur == null) return;
    try {
      await lecteur.stop();
      await lecteur.dispose();
    } catch (_) {
      // Rien à faire : on voulait juste que ça se taise.
    }
  }
}
