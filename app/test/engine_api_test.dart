import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:numero_inconnu/models/client_message.dart';
import 'package:numero_inconnu/models/game_state.dart';
import 'package:numero_inconnu/services/engine_api.dart';
import 'package:numero_inconnu/services/engine_exception.dart';

/// Payloads réels capturés en Phase 0 contre le moteur local.
/// Ils font office de contrat exécutable : si le serveur change de forme,
/// ces tests tombent.
const _getStateN1 = {
  'story': {'slug': 'numero-inconnu', 'title': 'Numéro Inconnu'},
  'conversations': [
    {
      'contact_id': 'c-1',
      'display_name': 'Numéro inconnu',
      'avatar_url': null,
      'revealed': false,
    }
  ],
  'history': [
    {
      'seq': 122,
      'contact_id': 'c-1',
      'sender': 'contact',
      'content_type': 'separator',
      'body': 'jeudi — 22h47',
      'media_url': null,
      'delay_seconds': 0,
      'typing_seconds': 0,
      'push_notification': false,
      'push_text': null,
    }
  ],
  'node': {
    'code': 'N1',
    'kind': 'scripted',
    'choices': [
      {'id': 'ch-1', 'position': 0, 'label': 'Je crois que vous vous trompez', 'kind': 'reply'},
      {'id': 'ch-2', 'position': 2, 'label': 'Ignorer', 'kind': 'ignore'},
    ],
    'awaiting_interaction': false,
    'can_continue': false,
  },
  'chapter_end': null,
  'ai_moment_pending': false,
};

const _advanceN16 = {
  'new_messages': [
    {
      'seq': 209,
      'contact_id': 'c-1',
      'sender': 'contact',
      'content_type': 'image',
      'body': null,
      'media_url': 'placeholder://photo-N16-plaque',
      'delay_seconds': 60,
      'typing_seconds': 3,
      'push_notification': false,
      'push_text': null,
    }
  ],
  'node': {
    'code': 'N16',
    'kind': 'scripted',
    'choices': [
      {'id': 'ch-9', 'position': 0, 'label': "Zoomer sur l'autocollant", 'kind': 'interaction', 'declencheur': 'geste'},
    ],
    'awaiting_interaction': true,
    'can_continue': true,
  },
  'conversations': [
    {'contact_id': 'c-1', 'display_name': 'Léna', 'avatar_url': null, 'revealed': true}
  ],
  'chapter_end': null,
  'ai_moment_pending': false,
  'idempotent_replay': false,
};

/// Réponse encodée en octets UTF-8, comme le fait le vrai serveur.
http.Response _reponse(Object corps, [int statut = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(corps)), statut);

EngineApi _api(MockClient client) => EngineApi(
      jetonAcces: () => 'jeton-de-test',
      httpClient: client,
      baseUrl: 'http://test.local',
      apiKey: 'cle-test',
    );

void main() {
  group('Désérialisation du contrat', () {
    test('get-state : le nœud d\'entrée et la conversation anonyme', () async {
      final api = _api(MockClient((_) async => _reponse(_getStateN1)));
      final etat = await api.getState();

      expect(etat.storyTitle, 'Numéro Inconnu');
      expect(etat.conversations.single.displayName, 'Numéro inconnu');
      expect(etat.conversations.single.revealed, isFalse);
      expect(etat.node!.code, 'N1');
      expect(etat.history.single.contentType, ContentType.separator);
      expect(etat.history.single.body, 'jeudi — 22h47');
    });

    test('l\'historique se rejoue d\'un bloc : aucun délai', () async {
      final api = _api(MockClient((_) async => _reponse(_getStateN1)));
      final etat = await api.getState();
      expect(etat.history.every((m) => m.delaySeconds == 0 && m.typingSeconds == 0), isTrue);
    });

    test('advance : image en placeholder et arrêt sur interaction', () async {
      final api = _api(MockClient((_) async => _reponse(_advanceN16)));
      final r = await api.advanceChoice('ch-x');

      final image = r.newMessages.single;
      expect(image.contentType, ContentType.image);
      expect(image.isPlaceholderMedia, isTrue,
          reason: 'les médias réels n\'existent pas encore : repli d\'affichage requis');
      expect(image.delaySeconds, 60);
      expect(r.node!.awaitingInteraction, isTrue);
      expect(r.node!.canContinue, isTrue);
    });

    test('la bascule d\'identité remonte dans les conversations', () async {
      final api = _api(MockClient((_) async => _reponse(_advanceN16)));
      final r = await api.advanceChoice('ch-x');
      expect(r.conversations.single.displayName, 'Léna');
      expect(r.conversations.single.revealed, isTrue);
    });
  });

  group('Séparation réponses / interactions — protection de mécanique', () {
    test('une interaction ne figure jamais parmi les réponses', () async {
      final api = _api(MockClient((_) async => _reponse(_advanceN16)));
      final noeud = (await api.advanceChoice('ch-x')).node!;

      expect(noeud.replies, isEmpty);
      expect(noeud.interactions, hasLength(1));
      // Au N17 ce label vaut « C'est quoi ce bruit derrière vous ? » : l'afficher
      // comme un bouton donnerait l'indice. Le filtrage n'est pas cosmétique.
      expect(noeud.interactions.single.kind, ChoiceKind.interaction);
    });

    test('reply et ignore sont tous deux des réponses', () async {
      final api = _api(MockClient((_) async => _reponse(_getStateN1)));
      final noeud = (await api.getState()).node!;
      expect(noeud.replies.map((c) => c.kind),
          containsAll([ChoiceKind.reply, ChoiceKind.ignore]));
      expect(noeud.interactions, isEmpty);
    });
  });

  group('Erreurs', () {
    Future<EngineException> capturer(int statut, String code) async {
      final api = _api(MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'error': {'code': code, 'message': 'msg'}
            })),
            statut,
          )));
      try {
        await api.advanceChoice('ch-x');
        fail('aurait dû lever');
      } on EngineException catch (e) {
        return e;
      }
    }

    test('les 8 codes du contrat sont reconnus', () async {
      expect((await capturer(400, 'requete_invalide')).code, EngineErrorCode.requeteInvalide);
      expect((await capturer(401, 'non_authentifie')).code, EngineErrorCode.nonAuthentifie);
      expect((await capturer(403, 'choix_invalide')).code, EngineErrorCode.choixInvalide);
      expect((await capturer(403, 'choix_verrouille')).code, EngineErrorCode.choixVerrouille);
      expect((await capturer(409, 'choix_attendu')).code, EngineErrorCode.choixAttendu);
      expect((await capturer(409, 'sans_suite')).code, EngineErrorCode.sansSuite);
      expect((await capturer(409, 'progression_corrompue')).code,
          EngineErrorCode.progressionCorrompue);
      expect((await capturer(500, 'erreur_interne')).code, EngineErrorCode.erreurInterne);
    });

    test('un code inconnu ne fait pas tomber le client', () async {
      expect((await capturer(418, 'code_du_futur')).code, EngineErrorCode.inconnu);
    });

    test('les refus 4xx exigent une resynchronisation, pas une nouvelle tentative', () async {
      final e = await capturer(403, 'choix_invalide');
      expect(e.exigeResynchronisation, isTrue);
      expect(e.estTransitoire, isFalse);
    });

    test('sans session, on n\'appelle même pas le réseau', () async {
      var appels = 0;
      final api = EngineApi(
        jetonAcces: () => null,
        httpClient: MockClient((_) async {
          appels++;
          return _reponse(const <String, dynamic>{});
        }),
        baseUrl: 'http://test.local',
        apiKey: 'k',
      );
      await expectLater(api.getState(), throwsA(isA<EngineException>()));
      expect(appels, 0);
    });
  });

  group('Politique de rejeu', () {
    test('un choix est retenté : le serveur est idempotent dessus', () async {
      var appels = 0;
      final api = _api(MockClient((_) async {
        appels++;
        if (appels < 3) return http.Response('{"error":{"code":"erreur_interne"}}', 500);
        return _reponse(_advanceN16);
      }));
      await api.advanceChoice('ch-x');
      expect(appels, 3);
    });

    test('continue n\'est JAMAIS retenté : le serveur n\'a pas de clé d\'idempotence',
        () async {
      var appels = 0;
      final api = _api(MockClient((_) async {
        appels++;
        return _reponse({'error': {'code': 'erreur_interne'}}, 500);
      }));
      await expectLater(api.advanceContinue(), throwsA(isA<EngineException>()));
      expect(appels, 1, reason: 'un rejeu ferait avancer le joueur deux fois');
    });
  });

  group('Anti-double-tap', () {
    test('deux appels concurrents ne produisent qu\'une seule avancée', () async {
      var appels = 0;
      final completer = Completer<http.Response>();
      final api = _api(MockClient((_) async {
        appels++;
        return completer.future;
      }));

      final a = api.advanceChoice('ch-x');
      final b = api.advanceChoice('ch-x');
      completer.complete(_reponse(_advanceN16));
      await Future.wait([a, b]);

      expect(appels, 1);
    });

    test('après complétion, un nouvel appel repart normalement', () async {
      var appels = 0;
      final api = _api(MockClient((_) async {
        appels++;
        return _reponse(_advanceN16);
      }));
      await api.advanceChoice('ch-1');
      await api.advanceChoice('ch-2');
      expect(appels, 2);
    });
  });

  group('Convention de contenu : typing intermittent', () {
    ClientMessage avecTyping(int t) => ClientMessage.fromJson({
          'seq': 1,
          'contact_id': 'c',
          'sender': 'contact',
          'content_type': 'text',
          'body': 'x',
          'media_url': null,
          'delay_seconds': t,
          'typing_seconds': t,
          'push_notification': false,
          'push_text': null,
        });

    test('le seuil isole les hésitations volontaires (N2 40s, N13 50s)', () {
      expect(avecTyping(3).hasIntermittentTyping, isFalse);
      expect(avecTyping(14).hasIntermittentTyping, isFalse);
      expect(avecTyping(15).hasIntermittentTyping, isTrue);
      expect(avecTyping(40).hasIntermittentTyping, isTrue); // N2#0
      expect(avecTyping(50).hasIntermittentTyping, isTrue); // N13#0
    });
  });

  group('Messages décoratifs', () {
    test('ancrés au dernier seq serveur pour garder leur place au rechargement', () {
      final m = ClientMessage.decorative(contactId: 'c-1', texte: 'réponds', ancreSeq: 217);
      expect(m.isLocalDecorative, isTrue);
      expect(m.sender, MessageSender.player);
      expect(m.seq, 217);
      expect(m.delaySeconds, 0);
    });
  });
}
