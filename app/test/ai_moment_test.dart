import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:numero_inconnu/providers/conversation_controller.dart';
import 'package:numero_inconnu/providers/session_providers.dart';
import 'package:numero_inconnu/screens/consent_screen.dart';
import 'package:numero_inconnu/screens/conversation_screen.dart';
import 'package:numero_inconnu/services/engine_api.dart';
import 'package:numero_inconnu/theme/app_theme.dart';
import 'package:numero_inconnu/widgets/composer.dart';
import 'package:numero_inconnu/widgets/message_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _msg(int seq, String sender, String body,
        {int delay = 0, int typing = 0}) =>
    {
      'seq': seq,
      'contact_id': 'c-1',
      'sender': sender,
      'content_type': 'text',
      'body': body,
      'media_url': null,
      'delay_seconds': delay,
      'typing_seconds': typing,
      'push_notification': false,
      'push_text': null,
      'phantom_typing_at': null,
      'haptic_at': null,
    };

Map<String, dynamic> _conv() => {
      'contact_id': 'c-1',
      'code': 'lena',
      'display_name': 'Léna',
      'phone_number': null,
      'avatar_url': null,
      'revealed': true,
    };

Map<String, dynamic> _noeud(String code, String kind, {bool peutContinuer = true}) => {
      'code': code,
      'kind': kind,
      'choices': const [],
      'awaiting_interaction': false,
      'can_continue': peutContinuer,
    };

/// État initial : on est sur le N9, la saisie libre est ouverte.
Map<String, dynamic> _etatN9() => {
      'story': {'slug': 's', 'title': 'T'},
      'conversations': [_conv()],
      'history': [_msg(1, 'contact', 'Je tremble encore. C\'est con, hein.')],
      'node': _noeud('N9', 'ai_moment'),
      'chapter_end': null,
      'ai_moment_pending': true,
    };

http.Response _json(Object corps) =>
    http.Response.bytes(utf8.encode(jsonEncode(corps)), 200);

/// Monte l'écran avec un `ai-chat` simulé. Le vrai EngineApi est utilisé : seul
/// le transport change, donc le chemin de code testé est celui de production.
Future<List<Map<String, dynamic>>> monter(
  WidgetTester tester,
  List<Object> reponsesAiChat,
) async {
  SharedPreferences.setMockInitialValues({});
  final recus = <Map<String, dynamic>>[];
  var i = 0;

  final api = EngineApi(
    jetonAcces: () => 'jeton',
    baseUrl: 'http://test.local',
    apiKey: 'k',
    httpClient: MockClient((requete) async {
      if (!requete.url.path.endsWith('ai-chat')) return _json(_etatN9());
      recus.add(jsonDecode(requete.body) as Map<String, dynamic>);
      final r = reponsesAiChat[i.clamp(0, reponsesAiChat.length - 1)];
      i++;
      return _json(r);
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
  return recus;
}

Future<void> ecrire(WidgetTester tester, String texte) async {
  await tester.enterText(find.byType(TextField), texte);
  await tester.pump();
  await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
  await tester.pump();
}

void main() {
  testWidgets('sur un moment IA, le champ passe en saisie réelle sans changer d\'aspect',
      (tester) async {
    await monter(tester, [_etatN9()]);
    final composer = tester.widget<Composer>(find.byType(Composer));
    expect(composer.mode, ComposerMode.aiInput);
    // Aucun libellé, aucune couleur, aucun indice ne distingue ce mode :
    // le joueur ne doit pas savoir quels moments « comptent ».
    expect(find.text('Message'), findsOneWidget);
  });

  testWidgets('le consentement est demandé à la première saisie, puis le message rejoué',
      (tester) async {
    final recus = await monter(tester, [
      {'consent_required': true},
      {..._etatN9(), 'new_messages': const [], 'exchanges_left': 4},
      {
        'new_messages': [
          _msg(2, 'player', 'Moi c\'est Sacha.'),
          _msg(3, 'contact', 'Sacha. Moi c\'est Léna.', delay: 2, typing: 2),
        ],
        'node': _noeud('N9', 'ai_moment'),
        'conversations': [_conv()],
        'chapter_end': null,
        'ai_moment_pending': true,
        'exchanges_left': 3,
      },
    ]);

    await ecrire(tester, 'Moi c\'est Sacha.');
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsOneWidget);

    // Le bouton reste inerte tant que la case n'est pas cochée.
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsOneWidget);

    await tester.tap(find.text("J'accepte ce traitement"));
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.byType(ConsentScreen), findsNothing);
    expect(find.text('Sacha. Moi c\'est Léna.'), findsOneWidget,
        reason: 'le message retenu pendant le consentement a bien été rejoué');
    expect(recus.map((r) => r.keys.first).toList(),
        ['message', 'consent', 'message']);
  });

  testWidgets('un refus ne bloque pas : elle raccroche et l\'histoire repart',
      (tester) async {
    await monter(tester, [
      {'consent_required': true},
      {
        'new_messages': [
          _msg(2, 'contact', 'Merci. J\'en avais besoin. Bon, je rentre.', delay: 0),
        ],
        'node': _noeud('N21', 'scripted'),
        'conversations': [_conv()],
        'chapter_end': null,
        'ai_moment_pending': false,
        'exchanges_left': 0,
      },
    ]);

    await ecrire(tester, 'salut');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byType(ConsentScreen), findsNothing);
    expect(find.text('Merci. J\'en avais besoin. Bon, je rentre.'), findsOneWidget);
    // Le champ est revenu à un mode ordinaire : le moment IA est clos.
    expect(tester.widget<Composer>(find.byType(Composer)).mode,
        isNot(ComposerMode.aiInput));
  });

  testWidgets('le typing tourne pendant l\'attente réseau', (tester) async {
    // Une réponse instantanée trahirait la machine : le joueur doit voir Léna
    // « écrire » pendant tout le temps de l'appel.
    SharedPreferences.setMockInitialValues({});
    final debloquer = Completer<http.Response>();
    final api = EngineApi(
      jetonAcces: () => 'jeton',
      baseUrl: 'http://test.local',
      apiKey: 'k',
      httpClient: MockClient((requete) async =>
          requete.url.path.endsWith('ai-chat') ? debloquer.future : _json(_etatN9())),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authPreteProvider.overrideWith((ref) async => 'joueur-test'),
        engineApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp(theme: AppTheme.sombre, home: const ConversationScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(TypingIndicator), findsNothing);
    await ecrire(tester, 'salut');
    await tester.pump();

    expect(find.byType(TypingIndicator), findsOneWidget,
        reason: 'elle « écrit » pendant tout l\'appel');
    expect(find.text('salut'), findsOneWidget,
        reason: 'et le message du joueur s\'affiche sans attendre le serveur');

    debloquer.complete(_json({
      'new_messages': [_msg(3, 'contact', 'Salut.', delay: 0)],
      'node': _noeud('N9', 'ai_moment'),
      'conversations': [_conv()],
      'chapter_end': null,
      'ai_moment_pending': true,
      'exchanges_left': 3,
    }));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byType(TypingIndicator), findsNothing);
    expect(find.text('Salut.'), findsOneWidget);
  });

  testWidgets('une panne du serveur ne laisse pas le joueur coincé', (tester) async {
    await monter(tester, [
      {
        'error': {'code': 'erreur_interne', 'message': 'boum'}
      },
    ]);
    await ecrire(tester, 'salut');
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Le champ reste utilisable, l'app ne s'est pas figée sur un typing éternel.
    expect(find.byType(TypingIndicator), findsNothing);
    expect(find.byType(Composer), findsOneWidget);
  });
}
