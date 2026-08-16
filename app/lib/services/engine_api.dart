import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/game_state.dart';
import 'engine_exception.dart';

/// Seul point de contact avec le moteur.
///
/// Le client ne lit JAMAIS les tables de contenu et n'écrit JAMAIS dans
/// `player_progress` / `player_messages` : tout passe par ces deux appels.
/// Voir docs/LOGIQUE.md § Contraintes client.
class EngineApi {
  EngineApi({
    required String? Function() jetonAcces,
    http.Client? httpClient,
    String? baseUrl,
    String? apiKey,
  })  : _jetonAcces = jetonAcces,
        _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl,
        _apiKey = apiKey;

  /// Injecté plutôt que dérivé d'un SupabaseClient : le service reste testable
  /// sans initialiser toute la pile Supabase.
  final String? Function() _jetonAcces;
  final http.Client _http;
  final String? _baseUrl;
  final String? _apiKey;

  String get _url => _baseUrl ?? Env.supabaseUrl;
  String get _cle => _apiKey ?? Env.supabasePublishableKey;

  /// Garde anti-double-appel. Un double-tap sur un choix, ou deux gestes de
  /// continuation qui se chevauchent, ne doivent pas produire deux avancées.
  Future<AdvanceResult>? _enCours;

  /// Efface la partie du joueur : il repart du nœud d'entrée, variables
  /// remises à zéro, et l'intronisation se rejoue.
  ///
  /// Outil de développement pour l'instant ; c'est aussi la base du bouton
  /// « réinitialiser l'histoire » exigé par le RGPD (bible §9).
  Future<void> resetProgress() async {
    await _appeler('reset-progress', const {}, rejouable: false);
  }

  /// Le joueur enregistre un contact.
  ///
  /// **Ce n'est pas un choix narratif** : aucun nœud ne bouge, aucune variable
  /// de jeu n'est touchée. C'est un geste, et le serveur le traite comme tel.
  /// Rejouable sans risque — révéler deux fois revient à révéler une fois.
  Future<List<Conversation>> revealContact(String contactCode) async {
    final json = await _appeler(
      'reveal-contact', {'contact_code': contactCode}, rejouable: true);
    return (json['conversations'] as List<dynamic>? ?? const [])
        .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<GameState> getState() async {
    final json = await _appeler('get-state', const {}, rejouable: true);
    return GameState.fromJson(json);
  }

  /// Applique un choix.
  ///
  /// Rejouable sans risque : le serveur est idempotent sur `choice_id`
  /// (`player_progress.last_choice_id`). Une retransmission renvoie les mêmes
  /// messages avec `idempotent_replay: true` au lieu d'appliquer deux fois.
  Future<AdvanceResult> advanceChoice(String choiceId) =>
      _avancerUneSeuleFois({'choice_id': choiceId}, rejouable: true);

  /// Franchit une transition automatique (nœud en pause sur interaction, ou
  /// moment IA traversé par son fallback).
  ///
  /// ⚠️ **Non rejouable.** Le serveur n'a pas de clé d'idempotence pour
  /// `continue` : une seconde tentative après une réponse perdue avancerait une
  /// seconde fois. En cas d'échec réseau, on ne retente pas — on resynchronise
  /// sur `get-state`, qui fait foi.
  Future<AdvanceResult> advanceContinue() =>
      _avancerUneSeuleFois(const {'continue': true}, rejouable: false);

  Future<AdvanceResult> _avancerUneSeuleFois(
    Map<String, dynamic> corps, {
    required bool rejouable,
  }) {
    final enCours = _enCours;
    if (enCours != null) return enCours;

    final futur = _appeler('advance', corps, rejouable: rejouable)
        .then(AdvanceResult.fromJson)
        .whenComplete(() => _enCours = null);
    _enCours = futur;
    return futur;
  }

  // -------------------------------------------------------------------------

  static const int _tentativesMax = 3;

  Future<Map<String, dynamic>> _appeler(
    String fonction,
    Map<String, dynamic> corps, {
    required bool rejouable,
  }) async {
    final plafond = rejouable ? _tentativesMax : 1;
    EngineException? derniere;

    for (var tentative = 1; tentative <= plafond; tentative++) {
      try {
        return await _requete(fonction, corps);
      } on EngineException catch (e) {
        derniere = e;
        // On ne retente que ce qui peut réussir sans rien changer d'autre :
        // panne réseau ou 500. Un 4xx est un refus définitif.
        if (!e.estTransitoire || tentative == plafond) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 300 * tentative));
      }
    }
    throw derniere ?? const EngineException(EngineErrorCode.inconnu, 'échec');
  }

  Future<Map<String, dynamic>> _requete(
    String fonction,
    Map<String, dynamic> corps,
  ) async {
    final jeton = _jetonAcces();
    if (jeton == null) {
      throw const EngineException(
          EngineErrorCode.nonAuthentifie, 'Aucune session', statut: 401);
    }

    final http.Response reponse;
    try {
      reponse = await _http
          .post(
            Uri.parse('$_url/functions/v1/$fonction'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jeton',
              'apikey': _cle,
            },
            body: jsonEncode(corps),
          )
          .timeout(Env.timeoutRequete);
    } on TimeoutException {
      throw const EngineException(EngineErrorCode.reseau, 'Délai dépassé');
    } catch (e) {
      throw EngineException(EngineErrorCode.reseau, e.toString());
    }

    Map<String, dynamic> json;
    try {
      // ⚠️ `reponse.body` décode en latin1 quand l'en-tête ne précise pas de
      // charset : « Léna » deviendrait « LÃ©na ». Tout le contenu est en
      // français, donc on décode les octets nous-mêmes.
      json = jsonDecode(utf8.decode(reponse.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw EngineException(
        reponse.statusCode >= 500 ? EngineErrorCode.erreurInterne : EngineErrorCode.inconnu,
        'Réponse illisible',
        statut: reponse.statusCode,
      );
    }

    if (reponse.statusCode >= 400) {
      final erreur = json['error'] as Map<String, dynamic>? ?? const {};
      throw EngineException(
        EngineErrorCode.depuisCode(erreur['code'] as String?),
        erreur['message'] as String? ?? 'Erreur ${reponse.statusCode}',
        statut: reponse.statusCode,
      );
    }
    return json;
  }

  void dispose() => _http.close();
}
