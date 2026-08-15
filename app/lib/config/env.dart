import 'dart:io' show Platform;

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

  /// URL de l'API Supabase.
  ///
  /// En développement local, l'émulateur Android n'atteint pas `127.0.0.1` :
  /// cette adresse désigne l'émulateur lui-même. `10.0.2.2` est l'alias de la
  /// machine hôte. Le simulateur iOS, lui, partage la boucle locale du Mac.
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
    if (estLocal && Platform.isAndroid) {
      return url.replaceAll('127.0.0.1', '10.0.2.2').replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }

  /// Outils de développement (bouton skip du déroulé). Retirés en release :
  /// `kReleaseMode` de Flutter met la constante à false et l'arbre est élagué.
  static const bool outilsDebug = bool.fromEnvironment('DEBUG_TOOLS', defaultValue: true);

  static const Duration timeoutRequete = Duration(seconds: 20);
}
