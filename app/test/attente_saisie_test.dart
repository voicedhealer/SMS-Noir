import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:numero_inconnu/models/game_state.dart';
import 'package:numero_inconnu/providers/conversation_controller.dart';
import 'package:numero_inconnu/providers/session_providers.dart';
import 'package:numero_inconnu/services/engine_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> noeud({bool attendSaisie = false, String? aparte}) => {
      'code': 'N16',
      'kind': 'scripted',
      'choices': [
        {'id': 'zoom', 'position': 50, 'label': "Zoomer sur l'autocollant", 'kind': 'interaction', 'declencheur': 'geste'},
      ],
      'awaiting_interaction': true,
      'can_continue': true,
      'attend_saisie': attendSaisie,
      'aparte': aparte,
    };

Map<String, dynamic> etat(Map<String, dynamic> n) => {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [
        {'contact_id': 'c-1', 'code': 'lena', 'display_name': 'Léna', 'unread': 0},
      ],
      'history': const [],
      'new_messages': const [],
      'node': n,
      'chapter_end': null,
      'ai_moment_pending': false,
      'ai_consent_decided': true,
    };

void main() {
  // `ConversationController` monte un `AppLifecycleListener` : sans binding
  // initialisé, sa construction échoue avant même d'atteindre l'assertion.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le contrat expose attend_saisie, et vaut false par défaut', () {
    expect(StoryNode.fromJson(noeud()).attendSaisie, isFalse);
    expect(StoryNode.fromJson(noeud(attendSaisie: true)).attendSaisie, isTrue);
    // Un serveur antérieur ne renvoie pas le champ : on ne doit pas planter,
    // et surtout ne pas supposer une attente qui n'existe pas.
    final ancien = Map<String, dynamic>.from(noeud())..remove('attend_saisie');
    expect(StoryNode.fromJson(ancien).attendSaisie, isFalse);
  });

  test('écrire déclenche l\'interaction au lieu de faire avancer le nœud',
      () async {
    // LE bug de la phase 4. Au N16, `replies` est vide et `can_continue` vrai :
    // le champ était donc en mode `continuation`, et y écrire appelait
    // `advance {continue}` — le joueur sautait au N19 en croyant avoir répondu,
    // et perdait AUTOCOLLANT sans jamais le savoir. Ce test fige la bascule.
    final envoyes = <Map<String, dynamic>>[];
    SharedPreferences.setMockInitialValues({});
    final api = EngineApi(
      jetonAcces: () => 'jeton',
      baseUrl: 'http://test.local',
      apiKey: 'k',
      httpClient: MockClient((requete) async {
        if (requete.url.path.endsWith('advance')) {
          envoyes.add(jsonDecode(requete.body) as Map<String, dynamic>);
          return http.Response.bytes(
              utf8.encode(jsonEncode({
                'new_messages': const [],
                'node': noeud(),
                'conversations': [
                  {'contact_id': 'c-1', 'code': 'lena', 'display_name': 'Léna', 'unread': 0},
                ],
                'chapter_end': null,
                'ai_moment_pending': false,
              })),
              200);
        }
        return http.Response.bytes(
            utf8.encode(jsonEncode(etat(noeud(attendSaisie: true)))), 200);
      }),
    );
    final conteneur = ProviderContainer(overrides: [
      authPreteProvider.overrideWith((ref) async => 'joueur-test'),
      engineApiProvider.overrideWithValue(api),
    ]);
    addTearDown(conteneur.dispose);

    await conteneur.read(conversationProvider.future);
    await conteneur.read(conversationProvider.notifier).envoyerTexte('Sentinel Pro');

    expect(envoyes, hasLength(1));
    expect(envoyes.first.containsKey('saisie'), isTrue,
        reason: 'écrire doit répondre, pas franchir');
    expect(envoyes.first['saisie'], 'Sentinel Pro');
    expect(envoyes.first.containsKey('continue'), isFalse,
        reason: 'un franchissement ferait sauter le nœud et perdre l\'indice');
  });

  test('sans attente, écrire garde le comportement décoratif d\'avant', () async {
    final envoyes = <Map<String, dynamic>>[];
    SharedPreferences.setMockInitialValues({});
    final api = EngineApi(
      jetonAcces: () => 'jeton',
      baseUrl: 'http://test.local',
      apiKey: 'k',
      httpClient: MockClient((requete) async {
        if (requete.url.path.endsWith('advance')) {
          envoyes.add(jsonDecode(requete.body) as Map<String, dynamic>);
          return http.Response.bytes(
              utf8.encode(jsonEncode({
                'new_messages': const [],
                'node': noeud(),
                'conversations': [
                  {'contact_id': 'c-1', 'code': 'lena', 'display_name': 'Léna', 'unread': 0},
                ],
                'chapter_end': null,
                'ai_moment_pending': false,
              })),
              200);
        }
        return http.Response.bytes(utf8.encode(jsonEncode(etat(noeud()))), 200);
      }),
    );
    final conteneur = ProviderContainer(overrides: [
      authPreteProvider.overrideWith((ref) async => 'joueur-test'),
      engineApiProvider.overrideWithValue(api),
    ]);
    addTearDown(conteneur.dispose);

    await conteneur.read(conversationProvider.future);
    await conteneur.read(conversationProvider.notifier).envoyerTexte('bla');

    expect(envoyes.single.containsKey('continue'), isTrue,
        reason: 'hors attente, le mode continuation reste la règle');
  });

  test('l\'aparté disparaît dès que le joueur écrit — tous apartés confondus',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = EngineApi(
      jetonAcces: () => 'jeton',
      baseUrl: 'http://test.local',
      apiKey: 'k',
      httpClient: MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode(
              etat(noeud(attendSaisie: true, aparte: 'Léna attend...')))),
          200)),
    );
    final conteneur = ProviderContainer(overrides: [
      authPreteProvider.overrideWith((ref) async => 'joueur-test'),
      engineApiProvider.overrideWithValue(api),
    ]);
    addTearDown(conteneur.dispose);

    await conteneur.read(conversationProvider.future);
    final ctrl = conteneur.read(conversationProvider.notifier);

    expect(conteneur.read(conversationProvider).value!.aparteEnCours, 'Léna attend...');
    ctrl.signalerSaisie(true);
    expect(conteneur.read(conversationProvider).value!.aparteEnCours, isNull,
        reason: 'l\'invite a fait son travail, elle ne reste pas sur la réponse');
    ctrl.signalerSaisie(false);
    expect(conteneur.read(conversationProvider).value!.aparteEnCours, 'Léna attend...',
        reason: 'champ vidé : l\'invite revient');
  });
}
