import 'package:flutter/foundation.dart';

/// Registre à instance unique : sait si un son **narratif** joue en ce
/// moment, tous types confondus (musique d'ambiance des écrans noirs, note
/// vocale) — jamais les bips de message ni le typing, déjà attendus dans une
/// messagerie. Voir docs/DESIGN.md § Le système sonore.
///
/// Générique par construction : chaque source s'enregistre avec son propre
/// arrêt, pas seulement `MusiqueNarrative`. Un futur chapitre qui ajoute une
/// nouvelle source sonore narrative n'a rien à toucher ici.
class IndicateurSonore {
  IndicateurSonore._();
  static final IndicateurSonore instance = IndicateurSonore._();

  final _actifs = <VoidCallback>{};

  /// `true` tant qu'au moins une source est enregistrée. Un `ValueNotifier`
  /// et non un `Stream` : l'indicateur n'a besoin que de la valeur courante,
  /// jamais de l'historique des changements.
  final ValueNotifier<bool> enCours = ValueNotifier(false);

  /// Signale qu'une source démarre. `arreter` doit couper net (pas mettre en
  /// pause) — c'est lui qu'appellera [couperTout] si le joueur tape sur
  /// l'indicateur. Renvoie la fonction à appeler quand la source s'arrête
  /// d'elle-même, pour se désinscrire proprement.
  ///
  /// Idempotente côté appelant : rappeler la fonction renvoyée plusieurs fois
  /// ne fait rien de plus après la première.
  VoidCallback signaler(VoidCallback arreter) {
    _actifs.add(arreter);
    enCours.value = true;
    var desinscrit = false;
    return () {
      if (desinscrit) return;
      desinscrit = true;
      _actifs.remove(arreter);
      enCours.value = _actifs.isNotEmpty;
    };
  }

  /// Coupe tout ce qui joue actuellement — l'action du tap sur l'indicateur.
  ///
  /// Vide le registre **avant** d'appeler les arrêts, plutôt que de compter
  /// sur chaque source pour se désinscrire en retour (voir [signaler]) : une
  /// source dont l'arrêt est asynchrone ne se désinscrirait qu'après coup,
  /// et l'indicateur resterait affiché un instant après avoir tout coupé.
  void couperTout() {
    final aArreter = _actifs.toList();
    _actifs.clear();
    enCours.value = false;
    for (final arreter in aArreter) {
      arreter();
    }
  }
}
