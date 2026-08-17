import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../models/client_message.dart';
import 'system_sounds.dart';

/// Quel son accompagne un message — ou aucun.
enum EffetSonore { aucun, reception, envoi, frappe }

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
  AudioPlayer? _frappe;

  /// Décide du son d'un message. **C'est ici que vivent les quatre interdits.**
  ///
  /// Pure et testable sans audio : c'est la seule partie qui peut casser
  /// l'effet du chapitre, elle ne doit pas dépendre d'un lecteur.
  static EffetSonore pour(ClientMessage m) {
    // Un séparateur ou un changement de présence n'est pas un message. C'est
    // ce qui garantit le **silence du N19** : « Léna est hors ligne » ne bipe
    // pas, et les 90 s qui suivent ne contiennent aucune livraison.
    if (m.contentType == ContentType.separator ||
        m.contentType == ContentType.system ||
        // Une carte d'enregistrement accompagne le message où elle se nomme :
        // elle sonnerait une deuxième fois pour la même prise de parole.
        m.contentType == ContentType.contactCard) {
      return EffetSonore.aucun;
    }
    // Un message décoratif ne part jamais. Le faire sonner mentirait au joueur
    // sur ce qui vient de se passer.
    if (m.isLocalDecorative) return EffetSonore.aucun;

    return m.sender == MessageSender.player ? EffetSonore.envoi : EffetSonore.reception;
  }

  /// Précharge les deux effets. Un son de messagerie qui arrive en retard n'est
  /// plus un son de messagerie.
  Future<void> precharger({String? reception, String? envoi, String? frappe}) async {
    _reception = await _preparer(reception);
    _envoi = await _preparer(envoi);
    _frappe = await _preparer(frappe);
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

  /// Joue l'effet correspondant. Ne bloque jamais l'appelant : le fil ne doit
  /// pas attendre après un bip.
  ///
  /// Trois étages, dans cet ordre : le fichier fourni par le contenu, puis le
  /// son court du système, puis rien. **Renvoie `false` quand rien n'a sonné**
  /// — c'est ce que l'appelant utilise pour vibrer à la place, sans avoir à
  /// interroger le mode silencieux de l'appareil.
  bool jouer(EffetSonore effet) {
    if (effet == EffetSonore.aucun) return false;

    final lecteur = switch (effet) {
      EffetSonore.reception => _reception,
      EffetSonore.envoi => _envoi,
      EffetSonore.frappe => _frappe,
      EffetSonore.aucun => null,
    };
    if (lecteur != null) {
      unawaited(lecteur.seek(Duration.zero).then((_) => lecteur.play()).catchError((_) {}));
      return true;
    }

    // Repli système. Écrit depuis le début, jamais branché jusqu'ici : la
    // classe existait, le pont natif était enregistré, et personne ne l'appelait.
    if (SystemSounds.disponible) {
      final id = switch (effet) {
        EffetSonore.reception => SystemSounds.reception,
        EffetSonore.envoi => SystemSounds.envoi,
        EffetSonore.frappe => SystemSounds.frappe,
        EffetSonore.aucun => null,
      };
      if (id != null) {
        unawaited(SystemSounds.jouer(id));
        return true;
      }
    }
    return false;
  }

  void dispose() {
    _reception?.dispose();
    _envoi?.dispose();
    _frappe?.dispose();
  }
}
