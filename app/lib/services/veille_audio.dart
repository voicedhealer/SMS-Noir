import 'package:flutter/widgets.dart';

import 'indicateur_sonore.dart';

/// Le son se tait quand l'app quitte l'avant-plan.
///
/// **Le défaut corrigé.** Rien, dans Flutter, ne coupe un lecteur audio quand
/// l'app passe en arrière-plan : `just_audio` et `video_player` continuent de
/// jouer, et l'`AndroidAudioUsage.media` que nous demandons les y autorise
/// explicitement. Le `dispose()` d'un écran n'y change rien — il se déclenche
/// au démontage de l'écran, pas quand le joueur quitte l'app : l'écran de fin
/// restait monté, sa musique jouait toujours, téléphone rangé, et seul un
/// processus tué la faisait taire. Constaté là ; le même défaut existait
/// partout ailleurs, il ne s'était juste pas encore fait remarquer.
///
/// **Un seul observateur, et pas un par lecteur.** [IndicateurSonore] sait
/// déjà qui joue et comment le couper : chaque source narrative s'y enregistre
/// avec son propre arrêt. La mise en veille n'a donc aucun lecteur à
/// connaître — elle appelle `couperTout()`, et chaque source reçoit exactement
/// l'arrêt qu'elle a choisi : coupure nette pour une musique, pause pour un
/// vocal ou une vidéo. Une future source narrative sera couverte du seul fait
/// qu'elle s'enregistre, comme elle l'est déjà pour le tap sur l'indicateur.
///
/// **Au retour, rien ne repart tout seul.** C'est une décision, pas un oubli —
/// voir docs/DESIGN.md § Le son s'arrête avec l'app.
///
/// Ne couvre pas `SoundEffects` : ses trois bips durent moins de 200 ms et ne
/// s'enregistrent nulle part, par la même règle qui les exclut de
/// l'indicateur. Un bip qui finirait de sonner pendant que l'écran s'éteint ne
/// se distingue pas d'un bip normal.
class VeilleAudio {
  VeilleAudio._();
  static final VeilleAudio instance = VeilleAudio._();

  AppLifecycleListener? _ecoute;

  bool _avantPlan = true;

  /// Faux dès que l'app n'est plus visible.
  ///
  /// Lu par les lecteurs avant de démarrer : `demarrer()` est asynchrone (le
  /// fichier se charge par le réseau), et une musique lancée juste avant un
  /// passage en arrière-plan commencerait à jouer **après** la coupure, sans
  /// avoir été enregistrée au moment où `couperTout()` est passé. Le seul
  /// observateur ne peut pas couper ce qui n'existe pas encore : c'est aux
  /// démarrages de ne pas naître dans le vide.
  bool get avantPlan => _avantPlan;

  /// Idempotent — appelé une seule fois, depuis `main()`.
  ///
  /// `AppLifecycleListener` plutôt qu'un `WidgetsBindingObserver` nu : même
  /// mécanisme, mais c'est déjà l'API utilisée par `ConversationController`
  /// pour geler le déroulé, et elle se démonte proprement.
  void installer() {
    _ecoute ??= AppLifecycleListener(onStateChange: _changement);
  }

  void _changement(AppLifecycleState etat) {
    final avantPlan = switch (etat) {
      AppLifecycleState.resumed => true,
      // `inactive` est TRANSITOIRE et ne veut pas dire « parti » : une
      // bannière de notification, le centre de contrôle, un appel entrant le
      // déclenchent sans que le joueur ait quitté quoi que ce soit — et sur
      // iOS, l'aperçu du sélecteur d'apps y passe puis revient. Y couper la
      // musique ferait de chaque notification reçue une coupure de mise en
      // scène. Le vrai départ, c'est `hidden` puis `paused` ; Flutter émet
      // toujours les deux sur mobile, et l'app n'est déjà plus visible au
      // premier.
      AppLifecycleState.inactive => _avantPlan,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => false,
    };
    // Deux états annoncent le même départ : on ne coupe qu'au franchissement.
    if (avantPlan == _avantPlan) return;
    _avantPlan = avantPlan;
    if (!avantPlan) IndicateurSonore.instance.couperTout();
  }

  /// Pour les tests seulement : l'app, elle, n'éteint jamais sa veille.
  @visibleForTesting
  void desinstaller() {
    _ecoute?.dispose();
    _ecoute = null;
    _avantPlan = true;
  }
}
