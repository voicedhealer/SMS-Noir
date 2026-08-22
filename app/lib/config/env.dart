import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;

/// Configuration d'environnement.
///
/// ⚠️ Aucune clé n'est écrite en dur. Tout vient de `--dart-define`, fourni par
/// `tool/run_local.sh` qui les lit de `supabase status`. Seule la clé
/// **publishable** entre dans l'app : elle est publique par construction, c'est
/// la RLS qui protège les données. La clé de service ne quitte jamais le serveur.
class Env {
  const Env._();

  static const String _urlDefini = String.fromEnvironment('SUPABASE_URL');
  static const String _cleDefinie = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// `true` pour un appareil Android réel relié en USB avec `adb reverse
  /// tcp:54321 tcp:54321` déjà posé — sur ce chemin, `127.0.0.1` désigne déjà
  /// la machine hôte via le tunnel adb, contrairement à l'émulateur.
  static const bool _adbReverse = bool.fromEnvironment('ADB_REVERSE');

  /// URL de l'API Supabase.
  ///
  /// En développement local, l'émulateur Android n'atteint pas `127.0.0.1` :
  /// cette adresse désigne l'émulateur lui-même. `10.0.2.2` est l'alias de la
  /// machine hôte. Le simulateur iOS, lui, partage la boucle locale du Mac.
  /// Un appareil Android réel n'a ni l'un ni l'autre : voir `_adbReverse`.
  static String get supabaseUrl {
    if (_urlDefini.isNotEmpty) return _adapterHote(_urlDefini);
    throw StateError(
      'SUPABASE_URL absent. Lancer via tool/run_local.sh, ou passer '
      '--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…',
    );
  }

  static String get supabasePublishableKey {
    if (_cleDefinie.isNotEmpty) return _cleDefinie;
    throw StateError('SUPABASE_PUBLISHABLE_KEY absent. Voir tool/run_local.sh.');
  }

  static String _adapterHote(String url) {
    final estLocal = url.contains('127.0.0.1') || url.contains('localhost');
    if (estLocal && Platform.isAndroid && !_adbReverse) {
      return url.replaceAll('127.0.0.1', '10.0.2.2').replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }

  /// Outils de développement : skip du déroulé, skip de l'intro, bouton de
  /// réinitialisation.
  ///
  /// ⚠️ **`kReleaseMode` est dans la constante elle-même**, et pas seulement sur
  /// les points d'appel. Un oubli de garde en aval livrerait l'outil en
  /// production — c'était le cas du skip de l'intro, qu'un simple tap
  /// escamotait. Une seule source de vérité, et l'arbre est élagué à la
  /// compilation puisque tout est `const`.
  static const bool outilsDebug =
      !kReleaseMode && bool.fromEnvironment('DEBUG_TOOLS', defaultValue: true);

  static const Duration timeoutRequete = Duration(seconds: 20);

  /// Politique de confidentialité, affichée sur l'écran de consentement.
  ///
  /// ⚠️ **Obligatoire avant toute mise en production** : le RGPD impose de
  /// pouvoir consulter le traitement auquel on consent. Tant qu'elle est vide,
  /// le lien n'est simplement pas affiché — mieux vaut rien qu'une URL morte,
  /// mais l'app ne peut pas sortir dans cet état. Voir TODO.
  static const String? politiqueConfidentialite =
      bool.hasEnvironment('PRIVACY_URL') ? String.fromEnvironment('PRIVACY_URL') : null;
}
