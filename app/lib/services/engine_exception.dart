/// Les codes d'erreur du moteur, tels que documentés dans
/// docs/LOGIQUE.md § Contrat des Edge Functions § Erreurs.
enum EngineErrorCode {
  /// 400 — ni `choice_id` ni `continue` dans la requête.
  requeteInvalide,

  /// 401 — jeton absent ou invalide.
  nonAuthentifie,

  /// 403 — le choix n'appartient pas au nœud courant.
  /// Même code si le choix n'existe pas du tout : le serveur ne révèle rien
  /// de la structure du graphe.
  choixInvalide,

  /// 403 — conditions non remplies (interaction déjà consommée, typiquement).
  choixVerrouille,

  /// 409 — `continue` sur un nœud qui attend une réponse.
  choixAttendu,

  /// 409 — `continue` sur un nœud sans transition automatique.
  sansSuite,

  /// 409 — aucun nœud courant.
  progressionCorrompue,

  /// 500 — le détail reste dans les logs serveur.
  erreurInterne,

  /// Panne réseau, timeout, réponse illisible.
  reseau,

  /// Code inconnu (serveur plus récent que le client).
  inconnu;

  static EngineErrorCode depuisCode(String? code) => switch (code) {
        'requete_invalide' => requeteInvalide,
        'non_authentifie' => nonAuthentifie,
        'choix_invalide' => choixInvalide,
        'choix_verrouille' => choixVerrouille,
        'choix_attendu' => choixAttendu,
        'sans_suite' => sansSuite,
        'progression_corrompue' => progressionCorrompue,
        'erreur_interne' => erreurInterne,
        _ => inconnu,
      };
}

class EngineException implements Exception {
  const EngineException(this.code, this.message, {this.statut});

  final EngineErrorCode code;
  final String message;
  final int? statut;

  /// Une erreur que l'état local ne peut pas résoudre : la seule sortie propre
  /// est de resynchroniser sur `get-state`, qui fait toujours foi.
  bool get exigeResynchronisation => switch (code) {
        EngineErrorCode.choixInvalide ||
        EngineErrorCode.choixVerrouille ||
        EngineErrorCode.choixAttendu ||
        EngineErrorCode.sansSuite ||
        EngineErrorCode.progressionCorrompue =>
          true,
        _ => false,
      };

  /// Une nouvelle tentative a une chance d'aboutir sans rien casser.
  /// ⚠️ Ne dit rien de la sûreté du rejeu : voir EngineApi.advance.
  bool get estTransitoire =>
      code == EngineErrorCode.reseau || code == EngineErrorCode.erreurInterne;

  @override
  String toString() => 'EngineException(${code.name}, $statut): $message';
}
