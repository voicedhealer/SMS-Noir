import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:numero_inconnu/providers/conversation_controller.dart';
import 'package:numero_inconnu/providers/session_providers.dart';
import 'package:numero_inconnu/screens/carnet_screen.dart';
import 'package:numero_inconnu/screens/chapter_end_screen.dart';
import 'package:numero_inconnu/screens/consent_screen.dart';
import 'package:numero_inconnu/screens/conversation_screen.dart';
import 'package:numero_inconnu/screens/entry_card_screen.dart';
import 'package:numero_inconnu/screens/intro_screen.dart';
import 'package:numero_inconnu/screens/root_screen.dart';
import 'package:numero_inconnu/services/engine_api.dart';
import 'package:numero_inconnu/theme/app_theme.dart';
import 'package:numero_inconnu/theme/tokens.dart';
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

Map<String, dynamic> conversation({String nom = 'Numéro inconnu', bool revele = false}) => {
      'contact_id': 'c-1',
      'code': 'lena',
      'display_name': nom,
      'phone_number': '06 39 98 41 07',
      'avatar_url': null,
      'revealed': revele,
    };

/// Monte l'écran avec un serveur simulé. Le vrai `EngineApi` est utilisé :
/// seul le transport est remplacé, donc le chemin de code testé est le bon.
Future<void> monter(
  WidgetTester tester, {
  required Map<String, dynamic> getState,
  Map<String, dynamic>? advance,
  Map<String, dynamic>? aiChat,
  Map<String, Object> prefs = const {},
  bool racine = false,
  void Function(Map<String, dynamic> corps)? surAiChat,
  void Function(Map<String, dynamic> corps)? surAdvance,
  // `false` quand la carte d'entrée est encore à l'écran (consentement pas
  // décidé) : sa respiration boucle indéfiniment (voir EntryCardScreen),
  // donc `pumpAndSettle` n'y termine jamais.
  bool attendreStabilisation = true,
}) async {
  SharedPreferences.setMockInitialValues(prefs);

  final api = EngineApi(
    jetonAcces: () => 'jeton',
    baseUrl: 'http://test.local',
    apiKey: 'k',
    httpClient: MockClient((requete) async {
      if (requete.url.path.endsWith('ai-chat')) {
        surAiChat?.call(jsonDecode(requete.body) as Map<String, dynamic>);
        return http.Response.bytes(utf8.encode(jsonEncode(aiChat!)), 200);
      }
      final versAdvance = requete.url.path.endsWith('advance');
      if (versAdvance) {
        surAdvance?.call(jsonDecode(requete.body) as Map<String, dynamic>);
      }
      final corps = versAdvance ? advance! : getState;
      return http.Response.bytes(utf8.encode(jsonEncode(corps)), 200);
    }),
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authPreteProvider.overrideWith((ref) async => 'joueur-test'),
      engineApiProvider.overrideWithValue(api),
    ],
    child: MaterialApp(
      theme: AppTheme.sombre,
      home: racine ? const RootScreen() : const ConversationScreen(),
    ),
  ));
  if (attendreStabilisation) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(seconds: 3));
  }
}

void main() {
  group('Carte d\'entrée', () {
    Map<String, dynamic> etatSansConsentement() => {
          'story': {
            'slug': 's', 'title': 'Numéro Inconnu', 'tagline': '22h47. Un SMS...',
            'cover_url': null,
          },
          'intro': {'panels': const [], 'music_url': null},
          'new_messages': const [],
          'conversations': [conversation()],
          'history': const [],
          'node': noeud(),
          'chapter_end': null,
          'ai_moment_pending': false,
          'ai_consent_decided': false,
        };

    Map<String, dynamic> reponseAiChat() => {
          'new_messages': const [],
          'node': noeud(),
          'conversations': [conversation()],
          'chapter_end': null,
          'ai_moment_pending': false,
          'exchanges_left': 0,
        };

    testWidgets('précède tout, avec le titre, l\'accroche et le bouton', (tester) async {
      await monter(tester,
          getState: etatSansConsentement(), racine: true, attendreStabilisation: false);
      expect(find.byType(EntryCardScreen), findsOneWidget);
      expect(find.text('Numéro Inconnu'), findsOneWidget);
      expect(find.text('22h47. Un SMS...'), findsOneWidget);
      expect(find.text('Entrer'), findsOneWidget);
      expect(find.byType(ConsentScreen), findsNothing, reason: 'un seul écran, pas deux');
      expect(find.byType(IntroScreen), findsNothing);
    });

    testWidgets('la case n\'est pas cochée par défaut (bible §9)', (tester) async {
      await monter(tester,
          getState: etatSansConsentement(), racine: true, attendreStabilisation: false);
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsNothing);
    });

    testWidgets('« Entrer » est inactif tant que la case n\'est pas cochée', (tester) async {
      // Consentement obligatoire, décision explicite de Vivien (voir la doc
      // de classe d'EntryCardScreen) : un tap sur « Entrer » case décochée ne
      // doit rien envoyer, rien fermer.
      Map<String, dynamic>? envoye;
      await monter(
        tester,
        getState: etatSansConsentement(),
        aiChat: reponseAiChat(),
        racine: true,
        surAiChat: (corps) => envoye = corps,
        attendreStabilisation: false,
      );

      await tester.tap(find.text('Entrer'), warnIfMissed: false);
      await tester.pump();

      expect(envoye, isNull, reason: 'bouton inactif : aucune requête ne doit partir');
      expect(find.byType(EntryCardScreen), findsOneWidget, reason: 'l\'écran doit rester ouvert');
    });

    testWidgets('case cochée puis « Entrer » : le consentement accepté part au serveur',
        (tester) async {
      Map<String, dynamic>? envoye;
      await monter(
        tester,
        getState: etatSansConsentement(),
        aiChat: reponseAiChat(),
        racine: true,
        surAiChat: (corps) => envoye = corps,
        attendreStabilisation: false,
      );

      await tester.tap(find.byIcon(Icons.check_box_outline_blank));
      await tester.pump();
      expect(find.byIcon(Icons.check_box), findsOneWidget);

      await tester.tap(find.text('Entrer'));
      await tester.pumpAndSettle();

      expect(envoye, {'consent': true});
      expect(find.byType(EntryCardScreen), findsNothing);
    });
  });

  group('Séquence d\'intronisation', () {
    final intro = {
      'panels': [
        {'lines': ['Jeudi 13 août 2026.']},
        {'lines': ['22h47.']},
      ],
      'music_url': null,
    };

    Map<String, dynamic> etatAvecIntro() => {
          'story': {'slug': 's', 'title': 'T'},
          'intro': intro,
          'new_messages': [
            message(seq: 1, body: 'jeudi — 22h47', type: 'separator'),
            message(seq: 2, body: 'C\'est bon.', delay: 4, typing: 3),
          ],
          'conversations': [conversation()],
          'history': const [],
          'node': noeud(),
          'chapter_end': null,
          'ai_moment_pending': false,
          // Ces tests portent sur l'intro, pas sur la carte d'entrée qui la
          // précède désormais : consentement déjà tranché pour ne pas la voir.
          'ai_consent_decided': true,
        };

    testWidgets('elle précède la conversation et date l\'histoire', (tester) async {
      await monter(tester, getState: etatAvecIntro(), racine: true);
      expect(find.byType(IntroScreen), findsOneWidget);
      expect(find.text('Jeudi 13 août 2026.'), findsOneWidget);
      // Le fil n'existe pas encore.
      expect(find.byType(MessageBubble), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 30));
    });

    testWidgets('une file en attente survit à l\'intro et se joue après',
        (tester) async {
      // Régression : quand une file persistée et une intro coexistaient, le
      // déroulé démarrait DERRIÈRE l'écran d'intro, puis `introTerminee`
      // appelait `jouer` à son tour — ce qui annulait le premier. Les messages
      // restaient en base et disparaissaient du fil.
      await monter(tester, racine: true, prefs: {
        'flutter.file_en_attente:joueur-test': jsonEncode([
          message(seq: 9, body: 'C\'est bon.', delay: 2),
        ]),
      }, getState: {
        'story': {'slug': 's', 'title': 'T'},
        'intro': intro,
        'new_messages': const [],
        'conversations': [conversation()],
        'history': [message(seq: 9, body: 'C\'est bon.')],
        'node': noeud(),
        'chapter_end': null,
        'ai_moment_pending': false,
        'ai_consent_decided': true,
      });

      expect(find.byType(IntroScreen), findsOneWidget);
      await tester.tap(find.byType(IntroScreen)); // skip debug
      await tester.pump();
      expect(find.text('C\'est bon.'), findsNothing, reason: '4 s de vide');

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('C\'est bon.'), findsOneWidget,
          reason: 'le message n\'a pas été avalé par l\'intro');
    });

    testWidgets('rejouée après réinitialisation, elle délivre bien les messages',
        (tester) async {
      // Régression : `invalidateSelf` déclenche le onDispose du build précédent,
      // qui posait un verrou « terminé » jamais rouvert. L'intro rejouait, la
      // musique démarrait, puis la conversation s'ouvrait VIDE — les choix
      // affichés, mais Léna n'avait jamais parlé.
      SharedPreferences.setMockInitialValues({});
      final api = EngineApi(
        jetonAcces: () => 'jeton',
        baseUrl: 'http://test.local',
        apiKey: 'k',
        httpClient: MockClient(
            (_) async => http.Response.bytes(utf8.encode(jsonEncode(etatAvecIntro())), 200)),
      );
      final conteneur = ProviderContainer(overrides: [
        authPreteProvider.overrideWith((ref) async => 'joueur-test'),
        engineApiProvider.overrideWithValue(api),
      ]);
      addTearDown(conteneur.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: conteneur,
        child: MaterialApp(theme: AppTheme.sombre, home: const RootScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(IntroScreen), findsOneWidget);

      // Premier passage : on saute l'intro, les messages arrivent.
      await tester.tap(find.byType(IntroScreen));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('C\'est bon.'), findsOneWidget);

      // Retour à la liste, puis vrai bouton de réinitialisation — c'est lui qui
      // purge la mémoire locale ET rejoue `build` sur la même instance.
      Navigator.of(tester.element(find.byType(ConversationScreen))).pop();
      await tester.pumpAndSettle();
      await conteneur.read(conversationProvider.notifier).reinitialiser();
      await tester.pumpAndSettle();
      expect(find.byType(IntroScreen), findsOneWidget, reason: 'l\'intro rejoue');

      await tester.tap(find.byType(IntroScreen));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('C\'est bon.'), findsOneWidget,
          reason: 'Léna doit reparler après une réinitialisation');
    });

    testWidgets('elle ne rejoue pas si elle a déjà été vue', (tester) async {
      await monter(tester, getState: etatAvecIntro(), racine: true,
          prefs: {'flutter.intro_vue:joueur-test': true});
      expect(find.byType(IntroScreen), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 30));
    });

    testWidgets(
        'la musique de fin reste exposée même une fois l\'intronisation déjà vue',
        (tester) async {
      // Régression : `ConversationState.intro` (et donc son
      // `chapter_end_music_url`) était nullé dès que l'intro avait déjà été
      // vue, alors que ce segment doit rester disponible à CHAQUE passage par
      // l'écran de fin — pas seulement à la toute première ouverture de l'app.
      // Signalé par Vivien : sur son téléphone, seul le son de l'intro du tout
      // début fonctionnait.
      //
      // La musique des écrans noirs échappe désormais à ce piège par
      // construction : elle voyage sur le `media_url` de leur message, donc
      // par le fil, et non par l'intro.
      //
      // Testé au niveau de l'état exposé par le contrôleur, pas en montant
      // `NarrationScreen` : ce widget résout `Env.supabaseUrl` dès qu'un
      // `musique` non nul lui est passé, absent en environnement de test
      // (voir `tool/run_local.sh`) — hors sujet ici, le bug vivait dans la
      // dérivation de l'état, pas dans l'écran.
      final api = EngineApi(
        jetonAcces: () => 'jeton',
        baseUrl: 'http://test.local',
        apiKey: 'k',
        httpClient: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'story': {'slug': 's', 'title': 'T'},
              'intro': {
                'panels': const [],
                'music_url': null,
                'chapter_end_music_url': '/musique-fin.mp3',
              },
              'new_messages': const [],
              'conversations': [conversation()],
              'history': const [],
              'node': noeud(),
              'chapter_end': null,
              'ai_moment_pending': false,
              'ai_consent_decided': true,
            })),
            200)),
      );
      SharedPreferences.setMockInitialValues({'flutter.intro_vue:joueur-test': true});
      final conteneur = ProviderContainer(overrides: [
        authPreteProvider.overrideWith((ref) async => 'joueur-test'),
        engineApiProvider.overrideWithValue(api),
      ]);
      addTearDown(conteneur.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: conteneur,
        child: MaterialApp(theme: AppTheme.sombre, home: const ConversationScreen()),
      ));
      await tester.pumpAndSettle();

      final etat = conteneur.read(conversationProvider).value!;
      expect(etat.intro, isNull, reason: 'l\'intro elle-même ne doit pas rejouer');
      expect(etat.musiqueFin, '/musique-fin.mp3');
    });

    testWidgets('la zone de choix reste masquée pendant les 4 s de vide', (tester) async {
      // Régression : les réponses proposées s'affichaient dès la fin de
      // l'intro, avant le moindre message de Léna, puis disparaissaient au
      // démarrage du déroulé, puis revenaient. Un choix ne peut pas précéder
      // ce à quoi il répond.
      await monter(tester, racine: true, getState: {
        'story': {'slug': 's', 'title': 'T'},
        'intro': intro,
        'new_messages': [
          message(seq: 1, body: 'jeudi — 22h47', type: 'separator'),
          message(seq: 2, body: 'C\'est bon.', delay: 4, typing: 3),
        ],
        'conversations': [conversation()],
        'history': const [],
        'node': noeud(choix: [
          {'id': 'a', 'position': 0, 'label': 'Qui ça, « elle » ?', 'kind': 'reply'},
          {'id': 'b', 'position': 1, 'label': 'Ignorer', 'kind': 'ignore'},
        ]),
        'chapter_end': null,
        'ai_moment_pending': false,
        'ai_consent_decided': true,
      });

      await tester.tap(find.byType(IntroScreen)); // skip debug
      await tester.pump();

      // Pendant les 4 s de vide.
      expect(find.text('Qui ça, « elle » ?'), findsNothing);
      expect(find.text('Ignorer'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Qui ça, « elle » ?'), findsNothing,
          reason: 'toujours rien : Léna n\'a pas encore parlé');

      // Pendant le déroulé du N1 : séparateur à t=4, message à t=8.
      await tester.pump(const Duration(seconds: 2)); // t=5
      expect(find.text('Qui ça, « elle » ?'), findsNothing);
      await tester.pump(const Duration(seconds: 2)); // t=7, message pas encore là
      expect(find.text('Qui ça, « elle » ?'), findsNothing);

      // Une fois le dernier message arrivé, et seulement là.
      await tester.pump(const Duration(seconds: 2)); // t=9
      await tester.pumpAndSettle();
      expect(find.text('C\'est bon.'), findsOneWidget);
      expect(find.text('Qui ça, « elle » ?'), findsOneWidget);
      expect(find.text('Ignorer'), findsOneWidget);
    });

    // Le carnet est accessible depuis l'en-tête de la CONVERSATION, jamais
    // depuis celui de la liste — là-bas vit l'icône Réglages, et confondre les
    // deux ferait entrer un objet d'application dans le fil avec Léna.
    testWidgets('l\'icône du carnet ouvre « Ce qu\'on sait » avec ce qui est trouvé',
        (tester) async {
      await monter(tester, getState: {
        ...etatAvecIntro(),
        'clues': [
          {'code': 'PLAQUE', 'texte': 'Une Peugeot 508 grise.'},
        ],
      }, prefs: {'flutter.intro_vue:joueur-test': true});

      await tester.tap(find.byTooltip('Ce qu\'on sait'));
      await tester.pumpAndSettle();

      expect(find.byType(CarnetScreen), findsOneWidget);
      expect(find.text('Une Peugeot 508 grise.'), findsOneWidget);
    });

    // Présente dès le départ, carnet vide : une icône qui APPARAÎTRAIT à la
    // première trouvaille annoncerait qu'il vient de se passer quelque chose.
    testWidgets('l\'icône est là même quand rien n\'a été trouvé', (tester) async {
      await monter(tester, getState: etatAvecIntro(),
          prefs: {'flutter.intro_vue:joueur-test': true});

      await tester.tap(find.byTooltip('Ce qu\'on sait'));
      await tester.pumpAndSettle();

      expect(find.text('Rien de noté pour l\'instant.'), findsOneWidget);
    });

    testWidgets('4 s de silence total avant que quoi que ce soit n\'arrive', (tester) async {
      await monter(tester, getState: etatAvecIntro(), racine: true);

      // On saute l'intro (skip debug) pour se placer à l'instant du basculement.
      await tester.tap(find.byType(IntroScreen));
      await tester.pump();

      expect(find.byType(SeparatorPill), findsNothing);
      expect(find.byType(TypingIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 3900));
      expect(find.byType(SeparatorPill), findsNothing,
          reason: 'les 4 s de vide ne sont pas négociables');

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SeparatorPill), findsOneWidget, reason: 'puis le fil démarre');

      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(TypingIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('C\'est bon.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

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

  testWidgets('« Ignorer » est proposé, mais une interaction par geste ne devient jamais un bouton',
      (tester) async {
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': const [],
      'node': noeud(choix: [
        {'id': 'a', 'position': 0, 'label': 'NON. Restez où vous êtes', 'kind': 'reply'},
        {'id': 'b', 'position': 1, 'label': 'Ignorer', 'kind': 'ignore'},
        // Le cas du N17 : ce label EST l'indice, et l'interaction se provoque
        // en RÉÉCOUTANT le vocal. C'est le déclencheur `geste` qui la tient
        // hors de la liste — les options atténuées ne portent que du `texte`.
        {
          'id': 'c',
          'position': 2,
          'label': 'C\'est quoi ce bruit derrière vous ?',
          'kind': 'interaction', 'declencheur': 'geste'
        },
      ]),
      'chapter_end': null,
      'ai_moment_pending': false,
    });

    expect(find.text('NON. Restez où vous êtes'), findsOneWidget);
    expect(find.text('Ignorer'), findsOneWidget);
    expect(find.text('C\'est quoi ce bruit derrière vous ?'), findsNothing,
        reason: 'protection de mécanique : un GESTE n\'est JAMAIS un bouton');
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
        {'id': 'i', 'position': 0, 'label': 'Zoomer sur l\'autocollant', 'kind': 'interaction', 'declencheur': 'geste'},
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
    // Aucun choix sur ce nœud : le champ reste actif (silence du N19, geste
    // de continuation...). Voir « le champ se verrouille dès qu'un choix
    // s'affiche » plus bas pour le cas où des choix sont présents.
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': [message(seq: 1, body: '23h31', type: 'separator')],
      'node': noeud(),
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

  testWidgets('le champ ignore le tap dès qu\'un choix est affiché', (tester) async {
    // Régression : le champ restait cliquable même avec des choix affichés —
    // le curseur s'activait et clignotait sans jamais ouvrir le clavier, un
    // geste parasite qui cassait l'immersion pour rien, le vrai choix étant
    // déjà à l'écran. Signalé par Vivien.
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': const [],
      'node': noeud(choix: [
        {'id': 'a', 'position': 0, 'label': 'Réponse A', 'kind': 'reply'},
      ]),
      'chapter_end': null,
      'ai_moment_pending': false,
    });

    await tester.tap(find.byType(TextField), warnIfMissed: false);
    await tester.pump();

    final champ = tester.widget<TextField>(find.byType(TextField));
    expect(champ.focusNode?.hasFocus, isFalse);
    // Aspect rigoureusement inchangé : même indice, jamais grisé.
    expect(find.text('Message'), findsOneWidget);
  });

  testWidgets('les médias portent leur heure de fiction, comme les bulles texte',
      (tester) async {
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation()],
      'history': [
        message(seq: 1, body: '23h31', type: 'separator'),
        message(seq: 2, body: null, type: 'image', media: 'placeholder://photo'),
      ],
      'node': noeud(),
      'chapter_end': null,
      'ai_moment_pending': false,
    });

    // L'heure figure sur la vignette, pas seulement sur le séparateur.
    expect(find.text('23h31'), findsNWidgets(2));
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

  group('Interactions cachées', () {
    testWidgets('sur un nœud à média, aucune option atténuée : le geste est sur la photo',
        (tester) async {
      await monter(tester, getState: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': [
          message(seq: 1, body: null, type: 'image', media: 'placeholder://photo-N16-plaque'),
        ],
        'node': noeud(code: 'N16', attenteInteraction: true, peutContinuer: true, choix: [
          {'id': 'i', 'position': 0, 'label': 'Zoomer sur l\'autocollant', 'kind': 'interaction', 'declencheur': 'geste'},
        ]),
        'chapter_end': null,
        'ai_moment_pending': false,
      });
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.text('Zoomer sur l\'autocollant'), findsNothing);
    });

    testWidgets('les répliques sont des options atténuées, après les réponses',
        (tester) async {
      Map<String, dynamic>? envoye;
      await monter(tester, surAdvance: (c) => envoye = c, advance: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': const [],
        'node': noeud(),
        'chapter_end': null,
        'ai_moment_pending': false,
      }, getState: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': [message(seq: 1, body: 'T\'as rien demandé, je sais.')],
        'node': noeud(code: 'N8', choix: [
          {'id': 'a', 'position': 0, 'label': 'Ok. Je garde mon téléphone', 'kind': 'reply'},
          {'id': 'i1', 'position': 3, 'label': 'C\'est qui, ce type ?', 'kind': 'interaction', 'declencheur': 'texte'},
          {'id': 'i2', 'position': 4, 'label': 'Pourquoi cet entrepôt ?', 'kind': 'interaction', 'declencheur': 'texte'},
        ]),
        'chapter_end': null,
        'ai_moment_pending': false,
      });

      // Plus de feuille à ouvrir : elles sont là, simplement moins en avant.
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.text('C\'est qui, ce type ?'), findsOneWidget);
      expect(find.text('Pourquoi cet entrepôt ?'), findsOneWidget);

      // Atténuées : plus petites et plus sourdes que la réponse au-dessus.
      TextStyle style(String t) => tester.widget<Text>(find.text(t)).style!;
      final reponse = style('Ok. Je garde mon téléphone');
      final discret = style('C\'est qui, ce type ?');
      expect(discret.fontSize! < reponse.fontSize!, isTrue,
          reason: 'corps plus petit que celui d\'une réponse');
      expect(discret.color, AppColors.texteTertiaire);
      expect(reponse.color, AppColors.textePrincipal);

      // Et elles restent des interactions : le tap les déclenche.
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('C\'est qui, ce type ?'));
      await tester.pumpAndSettle();
      expect(envoye?['choice_id'], 'i1');
    });

    testWidgets('elles arrivent APRÈS les réponses, jamais avant', (tester) async {
      await monter(tester, getState: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': [message(seq: 1, body: 'T\'as rien demandé, je sais.')],
        'node': noeud(code: 'N8', choix: [
          {'id': 'a', 'position': 0, 'label': 'Ok. Je garde mon téléphone', 'kind': 'reply'},
          {'id': 'i1', 'position': 3, 'label': 'C\'est qui, ce type ?', 'kind': 'interaction', 'declencheur': 'texte'},
        ]),
        'chapter_end': null,
        'ai_moment_pending': false,
      });
      final yReponse = tester.getTopLeft(find.text('Ok. Je garde mon téléphone')).dy;
      final yDiscret = tester.getTopLeft(find.text('C\'est qui, ce type ?')).dy;
      expect(yDiscret > yReponse, isTrue,
          reason: 'une option de plus au bas de la liste, pas une concurrente');
    });
  });

  group('Carte d\'enregistrement de contact', () {
    Map<String, dynamic> etatAvecCarte({bool revele = false}) => {
          'story': {'slug': 's', 'title': 'T'},
          'conversations': [conversation(nom: revele ? 'Léna' : 'Numéro inconnu', revele: revele)],
          'history': [
            message(seq: 1, body: 'Moi c\'est Léna, au passage.'),
            message(seq: 2, body: null, type: 'contact_card'),
          ],
          'node': noeud(),
          'chapter_end': null,
          'ai_moment_pending': false,
        };

    testWidgets('elle vit dans le fil, avec le numéro et les deux gestes',
        (tester) async {
      await monter(tester, getState: etatAvecCarte());

      expect(find.byType(ContactCard), findsOneWidget);
      expect(find.text('06 39 98 41 07'), findsOneWidget);
      expect(find.text('Enregistrer le contact'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
      // Ce n'est pas une modale : le fil est toujours là derrière.
      expect(find.text('Moi c\'est Léna, au passage.'), findsOneWidget);
    });

    testWidgets('« Plus tard » ne fait rien : le contact reste anonyme',
        (tester) async {
      await monter(tester, getState: etatAvecCarte());
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();

      expect(find.text('Numéro inconnu'), findsWidgets, reason: 'toujours pas nommée');
      expect(find.byType(ContactCard), findsOneWidget, reason: 'la carte reste consultable');
      expect(find.text('Enregistrer le contact'), findsOneWidget,
          reason: 'et le geste reste possible plus tard');
    });

    testWidgets('une fois enregistrée, la carte reste mais ne propose plus rien',
        (tester) async {
      await monter(tester, getState: etatAvecCarte(revele: true));

      expect(find.byType(ContactCard), findsOneWidget);
      expect(find.text('Contact enregistré'), findsOneWidget);
      expect(find.text('Enregistrer le contact'), findsNothing);
      // L'en-tête porte le vrai nom.
      expect(find.text('Léna'), findsWidgets);
    });
  });

  testWidgets('la fin de chapitre sort du fil et prend tout l\'écran', (tester) async {
    await monter(tester, getState: {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [conversation(nom: 'Léna', revele: true)],
      'history': [
        message(seq: 1, body: 'Et le mien a disparu de mon appart il y a 3 semaines.'),
        message(seq: 2, body: 'Quelqu\'un est entré chez Léna.', type: 'system'),
      ],
      'node': noeud(code: 'N22', kind: 'chapter_end'),
      'chapter_end': {
        'chapter_title': 'Le mauvais numéro',
        'next_chapter_title': 'Chloé',
        'next_chapter_position': 2,
        'unlocked_at': DateTime.now().add(const Duration(hours: 8)).toIso8601String(),
        'next_chapter_pending': true,
        'next_chapter_unlock_delay_minutes': 480,
        'next_chapter_notification_text': 'Léna vous attend. Le chapitre 2 est disponible.',
        'next_chapter_teaser_text': null,
      },
      'ai_moment_pending': false,
    });
    await tester.pumpAndSettle();

    expect(find.byType(ChapterEndScreen), findsOneWidget);

    // Le cliffhanger s'écrit maintenant caractère par caractère : on laisse la
    // frappe se terminer avant de chercher la phrase entière.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Quelqu\'un est entré chez Léna.'), findsOneWidget);
    expect(find.text('CHAPITRE 2 — CHLOÉ'), findsOneWidget);
    // Plus de compte à rebours en chiffres : un bouton pour programmer un
    // rappel, jamais un chiffre qui descend.
    expect(find.textContaining(':'), findsNothing);
    expect(find.text('Me prévenir dans 8h'), findsOneWidget);
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

  group('Silence de lecture avant les choix', () {
    Map<String, dynamic> etatAvecChoix(String dernierMessage) => {
          'story': {'slug': 's', 'title': 'T'},
          'conversations': [conversation()],
          'history': [message(seq: 1, body: dernierMessage)],
          'node': noeud(choix: [
            {'id': 'a', 'position': 0, 'label': 'Réponse A', 'kind': 'reply'},
            {'id': 'b', 'position': 1, 'label': 'Réponse B', 'kind': 'reply'},
          ]),
          'chapter_end': null,
          'ai_moment_pending': false,
        };

    /// Comme `monter()`, mais SANS `pumpAndSettle()` au montage.
    ///
    /// `pumpAndSettle()` avance l'horloge factice par pas jusqu'à ce que plus
    /// aucune frame ne soit programmée — et selon ce qui reste à animer à cet
    /// instant précis, ce pas peut suffire à faire expirer un minuteur de
    /// 1 à 2 s avant même que le corps du test ait commencé à pomper. Constaté
    /// en dur : le verrou d'un message de 200 caractères se retrouvait déjà
    /// levé au retour de `monter()`. Des `pump()` sans durée vident la file de
    /// microtâches et peignent une frame sans avancer le temps — assez pour
    /// résoudre l'authentification et le premier `get-state`.
    Future<void> monterSansAvancerHorloge(
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
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    testWidgets('le tap est ignoré pendant le silence de lecture', (tester) async {
      await monterSansAvancerHorloge(tester,
          getState: etatAvecChoix('Une réplique de taille ordinaire.'));

      // Présents dès l'affichage — rien ne doit manquer à l'écran.
      expect(find.text('Réponse A'), findsOneWidget);

      // Mais le tap immédiat ne fait rien : aucune requête n'est partie, donc
      // aucun nouveau nœud n'est arrivé et le bouton est toujours là.
      await tester.tap(find.text('Réponse A'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Réponse A'), findsOneWidget);
    });

    testWidgets('rien à l\'écran ne distingue le silence de l\'état normal',
        (tester) async {
      // Contrainte du produit : jamais de grisé, jamais d'icône d'attente —
      // le joueur ne doit jamais pouvoir repérer qu'un verrou existe.
      await monterSansAvancerHorloge(tester, getState: etatAvecChoix('Une réplique.'));
      final avant = tester
          .widget<TextButton>(find.ancestor(
              of: find.text('Réponse A'), matching: find.byType(TextButton)))
          .style;

      await tester.pump(const Duration(seconds: 3));
      final apres = tester
          .widget<TextButton>(find.ancestor(
              of: find.text('Réponse A'), matching: find.byType(TextButton)))
          .style;

      expect(avant?.backgroundColor?.resolve({}), apres?.backgroundColor?.resolve({}));
    });

    testWidgets('le tap fonctionne une fois le silence passé', (tester) async {
      await monterSansAvancerHorloge(
        tester,
        getState: etatAvecChoix('Une réplique.'),
        advance: {
          'new_messages': [message(seq: 2, body: 'suite')],
          'node': noeud(code: 'N2'),
          'conversations': [conversation()],
          'chapter_end': null,
          'ai_moment_pending': false,
          'idempotent_replay': false,
        },
      );

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Réponse A'));
      await tester.pumpAndSettle();
      expect(find.text('suite'), findsOneWidget);
    });

    testWidgets('un message plus long tient le verrou plus longtemps', (tester) async {
      final long = 'x' * 200;
      await monterSansAvancerHorloge(tester, getState: etatAvecChoix(long));

      // 900 + 200×10 = 2900, borné à 2000 ms : encore verrouillé à 1,5 s.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.tap(find.text('Réponse A'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Réponse A'), findsOneWidget,
          reason: 'un message long garde le verrou plus longtemps qu\'un court');
    });
  });

  group('Le fil ne vole jamais la position de lecture', () {
    testWidgets('un joueur remonté n\'est pas ramené en bas par une livraison',
        (tester) async {
      // Container explicite : la lazy-list ne construit que les items
      // visibles, donc une fois remonté, le nouveau message livré au bas du
      // fil n'apparaît jamais dans l'arbre de widgets — vérifier l'ÉTAT
      // directement est la seule façon fiable de confirmer qu'il est bien
      // arrivé sans dépendre de ce qui est rendu à l'écran.
      final api = EngineApi(
        jetonAcces: () => 'jeton',
        baseUrl: 'http://test.local',
        apiKey: 'k',
        httpClient: MockClient((requete) async {
          final estAdvance = requete.url.path.endsWith('advance');
          final corps = estAdvance
              ? {
                  'new_messages': [
                    message(seq: 41, body: 'Nouveau message pendant la lecture'),
                  ],
                  'node': noeud(code: 'N2'),
                  'conversations': [conversation()],
                  'chapter_end': null,
                  'ai_moment_pending': false,
                  'idempotent_replay': false,
                }
              : {
                  'story': {'slug': 's', 'title': 'T'},
                  'conversations': [conversation()],
                  'history': [for (var i = 1; i <= 40; i++) message(seq: i, body: 'Message $i')],
                  'node': noeud(choix: [
                    {'id': 'a', 'position': 0, 'label': 'Réponse A', 'kind': 'reply'},
                  ]),
                  'chapter_end': null,
                  'ai_moment_pending': false,
                };
          return http.Response.bytes(utf8.encode(jsonEncode(corps)), 200);
        }),
      );
      final conteneur = ProviderContainer(overrides: [
        authPreteProvider.overrideWith((ref) async => 'joueur-test'),
        engineApiProvider.overrideWithValue(api),
      ]);
      addTearDown(conteneur.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: conteneur,
        child: MaterialApp(theme: AppTheme.sombre, home: const ConversationScreen()),
      ));
      await tester.pumpAndSettle();

      // Ciblé explicitement sur le ListView du fil : `find.byType(Scrollable)`
      // seul aurait pu accrocher un autre scrollable de l'arbre (champ de
      // texte multi-ligne, transition de route) sans qu'on s'en aperçoive.
      final liste =
          find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));
      final scroll = tester.state<ScrollableState>(liste).position;
      // Le joueur remonte délibérément, sans pour autant remonter jusqu'au
      // tout début du fil — un drag trop généreux collerait au sommet
      // (pixels == 0) et donnerait un résultat correct pour la mauvaise
      // raison.
      await tester.drag(liste, const Offset(0, 800));
      await tester.pumpAndSettle();
      final positionAvant = scroll.pixels;
      // Même seuil que _ConversationScreenState._seuilProcheDuBas.
      expect(positionAvant, lessThan(scroll.maxScrollExtent - 120),
          reason: 'le remontage doit avoir vraiment éloigné le joueur du bas');

      // La zone de choix vit maintenant DANS la liste défilable, en dernière
      // position — c'est le point même de cette fonctionnalité (voir la
      // fonctionnalité "clavier ne masque jamais les choix"). Remonté loin du
      // bas, « Réponse A » n'est donc plus construit par la liste lazy : on
      // déclenche le choix directement sur le contrôleur, sans dépendre de ce
      // qui est rendu à l'écran à cet instant.
      await tester.pump(const Duration(seconds: 2));
      conteneur.read(conversationProvider.notifier).choisir('a');
      await tester.pumpAndSettle();

      final etat = conteneur.read(conversationProvider).value!;
      expect(etat.fil.map((m) => m.body), contains('Nouveau message pendant la lecture'),
          reason: 'le message est bien arrivé, même invisible à l\'écran');
      expect(scroll.pixels, positionAvant,
          reason: 'mais il n\'a pas ramené le joueur en bas');
    });

    testWidgets('un joueur déjà en bas suit le direct normalement', (tester) async {
      await monter(
        tester,
        getState: {
          'story': {'slug': 's', 'title': 'T'},
          'conversations': [conversation()],
          'history': [message(seq: 1, body: 'Premier message')],
          'node': noeud(choix: [
            {'id': 'a', 'position': 0, 'label': 'Réponse A', 'kind': 'reply'},
          ]),
          'chapter_end': null,
          'ai_moment_pending': false,
        },
        advance: {
          'new_messages': [message(seq: 2, body: 'Réponse de Léna')],
          'node': noeud(code: 'N2'),
          'conversations': [conversation()],
          'chapter_end': null,
          'ai_moment_pending': false,
          'idempotent_replay': false,
        },
      );

      // Le joueur n'a jamais quitté le bas du fil : le comportement historique
      // — suivre le direct — doit tenir exactement comme avant ce correctif.
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Réponse A'));
      await tester.pumpAndSettle();
      expect(find.text('Réponse de Léna'), findsOneWidget);
    });
  });

  group('Le clavier ne masque jamais les choix', () {
    // Reproduit le nœud le plus chargé du chapitre 1 (N8) : trois réponses
    // structurantes aux libellés longs, plus deux interactions cachées. C'est
    // sur un bloc comme celui-ci, combiné à un clavier qui mange la moitié de
    // l'écran, que le débordement se produisait.
    Map<String, dynamic> etatCharge() => {
          'story': {'slug': 's', 'title': 'T'},
          'conversations': [conversation()],
          'history': [message(seq: 1, body: 'Un message de contexte, pour la lecture.')],
          'node': noeud(choix: [
            {
              'id': 'a',
              'position': 0,
              'label': 'N\'y allez pas seule, retournez voir la police avec ça',
              'kind': 'reply',
            },
            {
              'id': 'b',
              'position': 1,
              'label': 'D\'accord, je garde mon téléphone à côté de moi ce soir',
              'kind': 'reply',
            },
            {
              'id': 'c',
              'position': 2,
              'label': 'Pourquoi moi ? Vous ne me connaissez pas, et pourtant',
              'kind': 'reply',
            },
            {'id': 'i1', 'position': 50, 'label': 'C\'est qui, ce type ?', 'kind': 'interaction', 'declencheur': 'texte'},
            {'id': 'i2', 'position': 51, 'label': 'Pourquoi cet entrepôt ?', 'kind': 'interaction', 'declencheur': 'texte'},
          ]),
          'chapter_end': null,
          'ai_moment_pending': false,
        };

    /// Simule un clavier ouvert : ~40 % d'un écran de téléphone ordinaire.
    Future<void> ouvrirClavier(WidgetTester tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pumpAndSettle();
    }

    testWidgets('un fil plus court que l\'écran s\'empile contre le champ, sans vide résiduel',
        (tester) async {
      // Régression : la ListView occupant toute la hauteur disponible, un fil
      // plus court que l'écran (début de chapitre) se posait EN HAUT et
      // laissait un grand vide entre le dernier choix et le champ de saisie.
      // Signalé par Vivien au N1. Une vraie messagerie empile depuis le bas :
      // le vide doit se retrouver en haut, jamais entre les deux.
      await monter(tester, getState: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': [message(seq: 1, body: 'Un seul message : le fil est court.')],
        'node': noeud(choix: [
          {'id': 'a', 'position': 0, 'label': 'Réponse A', 'kind': 'reply'},
          {'id': 'b', 'position': 1, 'label': 'Réponse B', 'kind': 'reply'},
        ]),
        'chapter_end': null,
        'ai_moment_pending': false,
      });

      final basDesChoix = tester.getBottomLeft(find.byType(ChoiceArea)).dy;
      final hautDuChamp = tester.getTopLeft(find.byType(Composer)).dy;

      // Seule la marge basse de la liste (AppSpacing.m) doit subsister. Avant
      // le correctif, l'écart valait plusieurs centaines de pixels.
      expect(hautDuChamp - basDesChoix, lessThan(32),
          reason: 'les choix doivent toucher le champ, pas flotter loin au-dessus');
    });

    testWidgets('aucun débordement quand le clavier ouvre sur un bloc chargé',
        (tester) async {
      await monter(tester, getState: etatCharge());
      await ouvrirClavier(tester);

      // Un RenderFlex qui déborde lève une FlutterError capturée par le test —
      // en particulier en debug, où le résultat serait les hachures
      // jaune-noir. `takeException()` la remonte explicitement au lieu de
      // laisser le test réussir malgré une erreur déjà survenue.
      expect(tester.takeException(), isNull);

      // Le champ reste joignable : c'est lui qui doit rester fixe, quoi qu'il
      // arrive au reste.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets(
        'taper le champ ne bouge rien quand des choix sont affichés, même remonté dans le fil',
        (tester) async {
      // Avant le verrouillage (voir § Verrouillage, DESIGN.md), un tap
      // délibéré sur le champ ramenait le joueur en bas pour révéler les
      // choix sous le clavier qui s'ouvrait. Depuis, le champ ignore
      // justement ce tap quand des choix sont affichés — rien à révéler
      // puisque rien ne s'ouvre. Ce test vérifie que ça tient même sur un
      // fil long et un bloc de choix chargé, pas seulement le cas trivial.
      await monter(
        tester,
        getState: {
          ...etatCharge(),
          'history': [
            for (var i = 1; i <= 40; i++) message(seq: i, body: 'Message $i'),
          ],
        },
      );

      final liste =
          find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable));
      final scroll = tester.state<ScrollableState>(liste).position;
      await tester.drag(liste, const Offset(0, 800));
      await tester.pumpAndSettle();
      final positionRemontee = scroll.pixels;
      expect(positionRemontee, lessThan(scroll.maxScrollExtent - 120),
          reason: 'point de départ : bien remonté, loin du bas');

      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(scroll.pixels, positionRemontee,
          reason: 'le tap est ignoré : aucune raison de bouger le fil');
      final champ = tester.widget<TextField>(find.byType(TextField));
      expect(champ.focusNode?.hasFocus, isFalse);
    });
  });

  group('L\'heure des bulles photo et audio suit la règle du texte', () {
    // Régression : l'addendum sur les horodatages (heure sous la bulle, un
    // seul par groupe) n'avait été appliqué qu'aux bulles de texte — la photo
    // et le vocal gardaient l'heure incrustée dans le média, telle qu'avant la
    // refonte. Les deux widgets passaient par un chemin de rendu séparé du
    // texte, et la correction de l'un n'avait pas traversé vers l'autre.
    //
    // L'horloge de fiction ne démarre qu'après un séparateur ancré
    // (`FictionClock.horaires`) : sans lui, `heure` reste nulle pour tout le
    // monde, et un test qui l'omettrait passerait pour la mauvaise raison. Un
    // séparateur ouvre donc chacun de ces scénarios.
    Map<String, dynamic> separateur() => message(seq: 0, body: 'jeudi — 22h47', type: 'separator');

    testWidgets('une photo seule affiche son heure en dessous, jamais dedans',
        (tester) async {
      await monter(tester, getState: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': [
          separateur(),
          message(seq: 1, type: 'image', media: 'placeholder://photo', body: null, delay: 0),
        ],
        'node': noeud(),
        'chapter_end': null,
        'ai_moment_pending': false,
      });

      expect(find.byType(MessageFooter), findsOneWidget,
          reason: 'le pied de groupe existe pour une bulle photo, comme pour le texte');
      // Sous la bulle, dans le pied — pas ailleurs.
      expect(
          find.descendant(of: find.byType(MessageFooter), matching: find.text('22h47')),
          findsOneWidget);

      // Aucun horodatage en surimpression : la vignette ne contient plus de
      // Positioned portant l'heure au-dessus de l'image.
      final photo = find.byType(PhotoBubble);
      expect(find.descendant(of: photo, matching: find.byType(Positioned)), findsNothing,
          reason: 'plus de surimpression sur la vignette');
      expect(find.descendant(of: photo, matching: find.text('22h47')), findsNothing,
          reason: 'l\'heure n\'est plus DANS le widget de la photo');
    });

    testWidgets('un vocal seul affiche son heure en dessous, jamais à côté de la durée',
        (tester) async {
      await monter(tester, getState: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': [
          separateur(),
          message(seq: 1, type: 'audio', media: 'placeholder://vocal', body: null, delay: 0),
        ],
        'node': noeud(),
        'chapter_end': null,
        'ai_moment_pending': false,
      });

      expect(find.byType(MessageFooter), findsOneWidget,
          reason: 'le pied de groupe existe pour une bulle audio, comme pour le texte');
      expect(
          find.descendant(of: find.byType(MessageFooter), matching: find.text('22h47')),
          findsOneWidget);
      expect(find.descendant(of: find.byType(AudioBubble), matching: find.text('22h47')),
          findsNothing,
          reason: 'l\'heure n\'est plus à côté de la durée, DANS le lecteur');
    });

    testWidgets('groupe mixte texte + photo du même émetteur : une seule heure, sous la photo',
        (tester) async {
      await monter(tester, getState: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': [
          separateur(),
          message(seq: 1, body: 'Regardez ça.', delay: 0),
          message(seq: 2, type: 'image', media: 'placeholder://photo', body: null, delay: 0),
        ],
        'node': noeud(),
        'chapter_end': null,
        'ai_moment_pending': false,
      });

      // Même émetteur, même minute de fiction (les deux à délai nul) : un
      // seul pied pour les deux bulles, exactement comme un groupe tout-texte.
      expect(find.byType(MessageFooter), findsOneWidget,
          reason: 'texte et photo du même émetteur, même minute : un seul groupe');
    });

    testWidgets('une photo puis un texte de Léna change de minute : deux pieds',
        (tester) async {
      await monter(tester, getState: {
        'story': {'slug': 's', 'title': 'T'},
        'conversations': [conversation()],
        'history': [
          separateur(),
          message(seq: 1, type: 'image', media: 'placeholder://photo', body: null, delay: 0),
          // delay > 0 fait avancer l'horloge de fiction : nouvelle minute,
          // donc nouveau groupe même si l'émetteur ne change pas.
          message(seq: 2, body: 'Vous voyez ?', delay: 90),
        ],
        'node': noeud(),
        'chapter_end': null,
        'ai_moment_pending': false,
      });

      expect(find.byType(MessageFooter), findsNWidgets(2),
          reason: 'la minute a changé entre les deux : deux groupes, deux pieds');
      expect(find.text('22h47'), findsOneWidget, reason: 'pied de la photo');
      expect(find.text('22h48'), findsOneWidget, reason: 'pied du texte, une minute plus tard');
    });
  });
}
