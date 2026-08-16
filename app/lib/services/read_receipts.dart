import '../models/client_message.dart';

/// Marqueur « Vu. » — piloté par la fiction, jamais automatique.
///
/// **Règle** : un message du joueur est vu dès qu'un *vrai* message du contact
/// apparaît après lui dans le fil. Ni un séparateur, ni un changement de
/// présence ne comptent — ce ne sont pas des paroles.
///
/// Elle produit exactement les quatre comportements voulus, sans rien seeder :
///
/// | Situation | Résultat |
/// |---|---|
/// | Le joueur répond, Léna enchaîne | vu |
/// | Silence du N19, elle est hors ligne | **pas vu** — les messages s'empilent |
/// | Elle revient au N20 | **tous vus d'un coup** |
/// | Après la fin du chapitre | jamais vu — elle n'a pas lu |
///
/// Le déclencheur est donc le contenu lui-même : c'est lui qui décide quand
/// elle reparle. Aucune colonne, aucune valeur à oublier au chapitre 3.
class ReadReceipts {
  const ReadReceipts._();

  /// `seq` du dernier message du joueur qui porte le marqueur, ou null.
  ///
  /// Un seul marqueur dans tout le fil, sous le dernier message vu — c'est la
  /// convention des vraies messageries. Le poser sous chaque bulle ferait du
  /// bruit, et l'effet du N20 (tout passe « Vu. » d'un coup) se lit tout aussi
  /// bien : le marqueur descend d'un bloc jusqu'au dernier message écrit
  /// pendant le silence.
  static int? dernierVu(List<ClientMessage> fil) {
    var vuJusqua = -1;
    for (final m in fil) {
      if (m.sender == MessageSender.contact && _estUneParole(m)) {
        vuJusqua = m.seq;
      }
    }
    if (vuJusqua < 0) return null;

    int? dernier;
    for (final m in fil) {
      if (m.sender == MessageSender.player && m.seq <= vuJusqua) dernier = m.seq;
    }
    return dernier;
  }

  static bool _estUneParole(ClientMessage m) =>
      m.contentType == ContentType.text ||
      m.contentType == ContentType.image ||
      m.contentType == ContentType.audio;
}
