import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:numero_inconnu/providers/session_providers.dart';
import 'package:numero_inconnu/screens/conversation_screen.dart';
import 'package:numero_inconnu/services/engine_api.dart';
import 'package:numero_inconnu/theme/app_theme.dart';
import 'package:numero_inconnu/widgets/composer.dart';
import 'package:numero_inconnu/widgets/message_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> message({
  required int seq,
  String? body = 'x',
  String type = 'text',
  String sender = 'contact',
  int delay = 0,
  int typing = 0,
  String? media,
}) =>
    {
      'seq': seq,
      'contact_id': 'c-1',
      'sender': sender,
      'content_type': type,
      'body': body,
      'media_url': media,
      'delay_seconds': delay,
      'typing_seconds': typing,
      'push_notification': false,
      'push_text': null,
      'phantom_typing_at': null,
      'haptic_at': null,
    };

Map<String, dynamic> noeud({
  String code = 'N1',
  String kind = 'scripted',
  List<Map<String, dynamic>> choix = const [],
  bool attenteInteraction = false,
  bool peutContinuer = false,
}) =>
    {
      'code': code,
      'kind': kind,
      'choices': choix,
      'awaiting_interaction': attenteInteraction,
      'can_continue': peutContinuer,
    };

Map<String, dynamic> conversation({String nom = 'Numéro inconnu', bool revele = false}) =>
    {'contact_id': 'c-1', 'display_name': nom, 'avatar_url': null, 'revealed': revele};

/// Monte l'écran avec un serveur simulé. Le vrai `EngineApi` est utilisé :
/// seul le transport est remplacé, donc le chemin de code testé est le bon.
Future<void> monter(
  WidgetTester tester, {
  required Map<String, dynamic> getState,
  Map<String, dynamic>? advance,
}) async {
  SharedPreferences.setMockInitialValues({});

  final api = EngineApi(
    jetonAcces: () => 'jeton',
    baseUrl: 'http://test.local',
    apiKey: 'k',
    httpClient: MockClient((requete) async {
      final corps = requete.url.path.endsWith('advance') ? advance! : getState;
      return http.Response.bytes(utf8.encode(jsonEncode(corps)), 200);
    }),
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authPreteProvider.overrideWith((ref) async => 'joueur-test'),
      engineApiProvider.overrideWithValue(api),
    ],
    child: MaterialApp(theme: AppTheme.sombre, home: const ConversationScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('le fil rend bulles et séparateur, avec l\'heure de fiction', (tester) async {
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': [
        message(seq: 1, body: 'jeudi — 22h47', type: 'separator'),
        message(seq: 2, body: 'C\'est bon.'),
      ],
      'node': noeud(choix: [
        {'id': 'a', 'position': 0, 'label': 'Réponse A', 'kind': 'reply'},
        {'id': 'b', 'position': 1, 'label': 'Ignorer', 'kind': 'ignore'},
      ]),
      'chapter_end': null,
      'ai_moment_pending': false,
    });

    expect(find.byType(SeparatorPill), findsOneWidget);
    expect(find.text('jeudi — 22h47'), findsOneWidget);
    expect(find.text('C\'est bon.'), findsOneWidget);
    // L'heure vient du séparateur, jamais de l'horloge système.
    expect(find.text('22h47'), findsOneWidget);
  });

  testWidgets('l\'en-tête porte le nom et le statut de présence', (tester) async {
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': const [],
      'node': noeud(),
      'chapter_end': null,
      'ai_moment_pending': false,
    });

    expect(find.text('Numéro inconnu'), findsOneWidget);
    expect(find.text('en ligne'), findsOneWidget);
  });

  testWidgets('un message system ne crée pas de bulle : il change la présence',
      (tester) async {
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': [
        message(seq: 1, body: '23h31', type: 'separator'),
        message(seq: 2, body: 'Léna est hors ligne', type: 'system'),
      ],
      'node': noeud(),
      'chapter_end': null,
      'ai_moment_pending': false,
    });

    // Le texte du system n'apparaît nulle part comme bulle.
    expect(find.byType(MessageBubble), findsNothing);
  });

  testWidgets('« Ignorer » est proposé, mais aucune interaction ne devient un bouton',
      (tester) async {
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': const [],
      'node': noeud(choix: [
        {'id': 'a', 'position': 0, 'label': 'NON. Restez où vous êtes', 'kind': 'reply'},
        {'id': 'b', 'position': 1, 'label': 'Ignorer', 'kind': 'ignore'},
        // Au N17, ce label EST l'indice. L'afficher le donnerait gratuitement.
        {
          'id': 'c',
          'position': 2,
          'label': 'C\'est quoi ce bruit derrière vous ?',
          'kind': 'interaction'
        },
      ]),
      'chapter_end': null,
      'ai_moment_pending': false,
    });

    expect(find.text('NON. Restez où vous êtes'), findsOneWidget);
    expect(find.text('Ignorer'), findsOneWidget);
    expect(find.text('C\'est quoi ce bruit derrière vous ?'), findsNothing,
        reason: 'protection de mécanique : une interaction n\'est JAMAIS un bouton');
  });

  testWidgets('pendant le déroulé, les choix disparaissent puis reviennent', (tester) async {
    await monter(
      tester,
      getState: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': const [],
        'node': noeud(choix: [
          {'id': 'a', 'position': 0, 'label': 'Réponse A', 'kind': 'reply'},
        ]),
        'chapter_end': null,
        'ai_moment_pending': false,
      },
      advance: {
        'new_messages': [
          message(seq: 10, body: 'Attends', delay: 25, typing: 3),
        ],
        'node': noeud(code: 'N3', choix: [
          {'id': 'z', 'position': 0, 'label': 'Réponse suivante', 'kind': 'reply'},
        ]),
        'conversations': [conversation()],
        'chapter_end': null,
        'ai_moment_pending': false,
        'idempotent_replay': false,
      },
    );

    await tester.tap(find.text('Réponse A'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Réponse A'), findsNothing, reason: 'zone de choix masquée pendant le déroulé');
    expect(find.text('Attends'), findsNothing, reason: '25 s d\'attente');

    await tester.pump(const Duration(seconds: 22));
    expect(find.byType(TypingIndicator), findsOneWidget, reason: 'typing sur les 3 dernières s');

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Attends'), findsOneWidget);
    expect(find.text('Réponse suivante'), findsOneWidget, reason: 'les choix reviennent');
  });

  testWidgets('le champ de saisie est toujours présent, quel que soit le mode',
      (tester) async {
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': const [],
      // Nœud en pause sur interaction : aucune réponse à donner.
      'node': noeud(code: 'N16', attenteInteraction: true, peutContinuer: true, choix: [
        {'id': 'i', 'position': 0, 'label': 'Zoomer sur l\'autocollant', 'kind': 'interaction'},
      ]),
      'chapter_end': null,
      'ai_moment_pending': false,
    });

    expect(find.byType(Composer), findsOneWidget);
    expect(find.text('Zoomer sur l\'autocollant'), findsNothing);
    // Aucun bouton « continuer » : sa présence révélerait qu'une interaction existe.
    expect(find.text('Continuer'), findsNothing);
  });

  testWidgets('un texte saisi s\'affiche à droite, non délivré', (tester) async {
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': [message(seq: 1, body: '23h31', type: 'separator')],
      'node': noeud(choix: [
        {'id': 'a', 'position': 0, 'label': 'Réponse A', 'kind': 'reply'},
      ]),
      'chapter_end': null,
      'ai_moment_pending': false,
    });

    await tester.enterText(find.byType(TextField), 'réponds bordel');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('réponds bordel'), findsOneWidget);
    // Une seule coche : envoyé, jamais délivré.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('un média placeholder s\'affiche proprement et reste tapable', (tester) async {
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': [
        message(seq: 1, body: null, type: 'image', media: 'placeholder://photo-N16-plaque'),
      ],
      'node': noeud(),
      'chapter_end': null,
      'ai_moment_pending': false,
    });

    expect(find.byType(MediaPlaceholder), findsOneWidget);
    await tester.tap(find.byType(PhotoBubble));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsOneWidget, reason: 'le zoom est une mécanique de jeu');
  });

  testWidgets('la bascule d\'identité change le nom de l\'en-tête', (tester) async {
    await monter(
      tester,
      getState: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': const [],
        'node': noeud(choix: [
          {'id': 'a', 'position': 0, 'label': 'Réponse A', 'kind': 'reply'},
        ]),
        'chapter_end': null,
        'ai_moment_pending': false,
      },
      advance: {
        'new_messages': [message(seq: 10, body: 'Moi c\'est Léna, au passage.', delay: 0)],
        'node': noeud(code: 'N5'),
        'conversations': [conversation(nom: 'Léna', revele: true)],
        'chapter_end': null,
        'ai_moment_pending': false,
        'idempotent_replay': false,
      },
    );

    expect(find.text('Numéro inconnu'), findsOneWidget);
    await tester.tap(find.text('Réponse A'));
    await tester.pumpAndSettle();
    expect(find.text('Léna'), findsOneWidget);
  });
}
