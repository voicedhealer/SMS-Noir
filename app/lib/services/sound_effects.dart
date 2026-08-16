import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../models/client_message.dart';

/// Quel son accompagne un message — ou aucun.
enum EffetSonore { aucun, reception, envoi }

/// Sons de message.
///
/// Deux effets très courts, discrets, de type messagerie. **Jamais ludiques** :
/// on n'est pas dans un jeu, et un son qui « récompense » casserait l'illusion
/// aussi sûrement qu'un score à l'écran.
///
/// Catégorie **ambient**, comme la musique d'intronisation : respecte le mode
/// silencieux et n'interrompt pas ce que l'utilisateur écoute. Un bip de
/// messagerie n'a aucune raison de passer outre.
class SoundEffects {
  SoundEffects();

  AudioPlayer? _reception;
  AudioPlayer? _envoi;

  /// Décide du son d'un message. **C'est ici que vivent les quatre interdits.**
  ///
  /// Pure et testable sans audio : c'est la seule partie qui peut casser
  /// l'effet du chapitre, elle ne doit pas dépendre d'un lecteur.
  static EffetSonore pour(ClientMessage m) {
    // Un séparateur ou un changement de présence n'est pas un message. C'est
    // ce qui garantit le **silence du N19** : « Léna est hors ligne » ne bipe
    // pas, et les 90 s qui suivent ne contiennent aucune livraison.
    if (m.contentType == ContentType.separator || m.contentType == ContentType.system) {
      return EffetSonore.aucun;
    }
    // Un message décoratif ne part jamais. Le faire sonner mentirait au joueur
    // sur ce qui vient de se passer.
    if (m.isLocalDecorative) return EffetSonore.aucun;

    return m.sender == MessageSender.player ? EffetSonore.envoi : EffetSonore.reception;
  }

  /// Précharge les deux effets. Un son de messagerie qui arrive en retard n'est
  /// plus un son de messagerie.
  Future<void> precharger({String? reception, String? envoi}) async {
    _reception = await _preparer(reception);
    _envoi = await _preparer(envoi);
  }

  Future<AudioPlayer?> _preparer(String? url) async {
    if (url == null) return null;
    try {
      final lecteur = AudioPlayer();
      await lecteur.setUrl(url);
      await lecteur.setVolume(0.5);
      return lecteur;
    } catch (_) {
      // Un son absent ou illisible ne bloque jamais rien : on joue en silence.
      return null;
    }
  }

  /// Joue l'effet correspondant, s'il y en a un. Ne bloque jamais l'appelant :
  /// le fil ne doit pas attendre après un bip.
  void jouer(EffetSonore effet) {
    final lecteur = switch (effet) {
      EffetSonore.reception => _reception,
      EffetSonore.envoi => _envoi,
      EffetSonore.aucun => null,
    };
    if (lecteur == null) return;
    unawaited(lecteur.seek(Duration.zero).then((_) => lecteur.play()).catchError((_) {}));
  }

  void dispose() {
    _reception?.dispose();
    _envoi?.dispose();
  }
}
