import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_session_config.dart';
import 'indicateur_sonore.dart';

/// Son d'ambiance **en boucle**, superposé au fil de la conversation.
///
/// Volontairement générique, et nommé comme tel : le battement de cœur du N19
/// est son premier usage, pas sa raison d'être. Les chapitres suivants auront
/// d'autres nappes à poser sous une scène (une pluie, un moteur, une salle
/// d'attente) — elles passeront par ici sans qu'on écrive une classe par effet.
///
/// **Distinct de `MusiqueNarrative`, et pas par accident.** Celle-ci coupe
/// systématiquement ce qui jouait avant, parce qu'elle sert des écrans pleins
/// où un seul morceau a du sens. Une ambiance, elle, se superpose : la faire
/// passer par le même lecteur ferait s'entretuer les deux sons. Deux rôles,
/// deux lecteurs.
///
/// Les deux s'enregistrent en revanche auprès du **même** [IndicateurSonore] :
/// un tap sur l'indicateur coupe tout ce qui joue, sans avoir à savoir qui
/// joue. C'est déjà ce que ce registre sait faire — rien à y ajouter.
///
/// **Aucune méthode ne lève jamais** : une ambiance absente ou illisible ne
/// doit pas empêcher la scène de se jouer. Mais jamais silencieuse pour
/// autant — chaque échec est loggué avant d'être absorbé, même principe que
/// `NotificationsLocales` et `MusiqueNarrative`.
class SonAmbiance {
  SonAmbiance._();
  static final SonAmbiance instance = SonAmbiance._();

  AudioPlayer? _lecteur;

  /// L'URL en cours. Redemander la même ne relance pas la boucle depuis le
  /// début : les messages suivants du N19 arrivent pendant que le cœur bat,
  /// et un redémarrage à chaque bulle s'entendrait comme un hoquet.
  String? _url;

  VoidCallback? _desinscrireSonore;

  /// En fond, sous les sons de message : l'ambiance ne doit jamais couvrir le
  /// bip d'un message reçu ni gêner la lecture.
  static const double _volume = 0.30;

  bool get joue => _lecteur?.playing ?? false;

  /// Démarre la boucle, ou ne fait rien si c'est déjà celle qui tourne.
  Future<void> demarrer(String url) async {
    if (_url == url && joue) return;
    await arreter();
    _url = url;
    try {
      // Même politique que la musique narrative : `ambient` respecte le mode
      // silencieux et ne coupe pas ce que le joueur écoutait déjà.
      await AudioSessionConfig.ambiance();
      final lecteur = AudioPlayer();
      _lecteur = lecteur;
      await lecteur.setUrl(url);
      // `LoopMode.one` plutôt qu'un réamorçage manuel en fin de piste : le
      // raccord est géré par le lecteur, sans le blanc qu'un `onComplete`
      // suivi d'un `seek(0)` laisserait entendre à chaque tour.
      await lecteur.setLoopMode(LoopMode.one);
      await lecteur.setVolume(_volume);
      _desinscrireSonore =
          IndicateurSonore.instance.signaler(() => unawaited(arreter()));
      unawaited(lecteur.play());
    } catch (e) {
      debugPrint('[SonAmbiance] démarrage impossible ($url) : $e');
      await arreter();
    }
  }

  /// Coupure nette, sans fondu — cohérent avec le reste du système sonore.
  Future<void> arreter() async {
    final lecteur = _lecteur;
    _lecteur = null;
    _url = null;
    _desinscrireSonore?.call();
    _desinscrireSonore = null;
    if (lecteur == null) return;
    try {
      await lecteur.stop();
      await lecteur.dispose();
    } catch (e) {
      debugPrint('[SonAmbiance] arrêt impossible : $e');
    }
  }
}
