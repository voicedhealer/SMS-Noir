import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Sons courts fournis par le système.
///
/// **iOS seulement.** Android n'a pas d'API publique pour « un son de message
/// court et sobre » : on n'y récupère que le son de notification *choisi par
/// l'utilisateur*, dont on ne maîtrise ni la durée ni le caractère — ça peut
/// être un jingle de trois secondes. La contrainte « 100-200 ms, discret,
/// jamais ludique » y serait invérifiable, donc Android utilise les assets de
/// repli.
///
/// ⚠️ **Jamais le tri-tone SMS** (identifiant 1003) ni le « whoosh » d'envoi
/// (1004). Ce sont les sons que tout le monde reconnaît : dans une histoire qui
/// commence par « vous recevez un SMS d'un inconnu », les jouer ferait quitter
/// l'app au joueur pour vérifier ses vrais messages. On reste sur le registre
/// neutre — clavier, tock — qui sonne natif sans imiter le système.
///
/// Les identifiants ne sont pas documentés par Apple. Ils sont stables depuis
/// des années et très employés, mais ce sont des constantes à ajuster à
/// l'oreille : elles sont isolées ici exprès.
class SystemSounds {
  const SystemSounds._();

  static const _canal = MethodChannel('numero_inconnu/system_sounds');

  /// Un « tink » mat. Ni le tri-tone, ni une alerte.
  static const int reception = 1057;

  /// Un tock sec — un départ, pas une arrivée.
  static const int envoi = 1306;

  /// Le tock du clavier : c'est littéralement le son de quelqu'un qui tape.
  static const int frappe = 1104;

  /// Vrai seulement là où le système offre des sons courts exploitables.
  static bool get disponible => Platform.isIOS;

  static Future<void> jouer(int identifiant) async {
    if (!disponible) return;
    try {
      await _canal.invokeMethod<void>('play', {'id': identifiant});
    } catch (_) {
      // Un son qui ne part pas ne doit jamais interrompre l'histoire.
    }
  }
}
