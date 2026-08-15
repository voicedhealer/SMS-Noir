import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game_state.dart';
import '../services/engine_api.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final engineApiProvider = Provider<EngineApi>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final api = EngineApi(jetonAcces: () => supabase.auth.currentSession?.accessToken);
  ref.onDispose(api.dispose);
  return api;
});

/// Session du joueur.
///
/// **Auth anonyme** pour le MVP : aucune friction avant que le joueur soit
/// accroché — un écran d'inscription devant un thriller par SMS ferait perdre
/// la moitié des joueurs avant le premier message de Léna.
///
/// Contrepartie assumée, à lever au chapitre 2 par un rattachement e-mail :
/// une session anonyme perdue (désinstallation, effacement des données) est une
/// progression perdue, sans recours. C'est aussi `auth.users` qui porte la
/// cascade d'effacement RGPD.
final sessionProvider = FutureProvider<Session>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  // Une session persistée n'est pas une session valide. Elle peut avoir expiré,
  // avoir été révoquée, ou — cas vécu en développement — avoir été signée par
  // une paire de clés que le serveur ne reconnaît plus. On la vérifie avant de
  // s'en servir, sinon le joueur tombe sur un écran d'erreur au lancement.
  final existante = supabase.auth.currentSession;
  if (existante != null && await _estUtilisable(supabase, existante)) {
    return existante;
  }

  if (existante != null) {
    // Session morte : on repart proprement plutôt que de la traîner.
    await supabase.auth.signOut().catchError((_) {});
  }
  return _connexionAnonyme(supabase);
});

Future<bool> _estUtilisable(SupabaseClient supabase, Session session) async {
  if (session.isExpired) {
    try {
      final rafraichie = await supabase.auth.refreshSession();
      return rafraichie.session != null;
    } catch (_) {
      return false;
    }
  }
  try {
    await supabase.auth.getUser();
    return true;
  } catch (_) {
    return false;
  }
}

Future<Session> _connexionAnonyme(SupabaseClient supabase) async {
  final reponse = await supabase.auth.signInAnonymously();
  final session = reponse.session;
  if (session == null) {
    throw StateError(
      'Connexion anonyme refusée. Vérifier enable_anonymous_sign_ins '
      'dans supabase/config.toml.',
    );
  }
  return session;
}

/// État de jeu courant. `get-state` fait toujours foi : ce provider est la
/// seule source de vérité de l'app, et rien ne le contourne.
final gameStateProvider = FutureProvider<GameState>((ref) async {
  await ref.watch(sessionProvider.future);
  return ref.watch(engineApiProvider).getState();
});
