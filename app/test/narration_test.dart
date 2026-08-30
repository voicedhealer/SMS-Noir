import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/client_message.dart';
import 'package:numero_inconnu/providers/conversation_controller.dart';
import 'package:numero_inconnu/services/playback.dart';
import 'package:numero_inconnu/screens/narration_screen.dart';
import 'package:numero_inconnu/theme/app_theme.dart';
import 'package:numero_inconnu/widgets/composer.dart';

const corps = '[{"texte":"Léna ne répond plus...","a":0},'
    '{"texte":"Il fait nuit, elle est seule.","a":20},'
    '{"texte":"Vous ne pouvez rien faire d\'autre qu\'attendre, ou prévenir la","a":40}]';

/// L'écran du trajet (N14) : trois lignes, la dernière entière.
const corpsTrajet = '[{"texte":"Léna est en route pour l\'entrepôt...","a":0},'
    '{"texte":"Elle cherche des réponses, un indice, n\'importe quoi.","a":7},'
    '{"texte":"Allez-vous soutenir cette inconnue ?","a":18}]';

void main() {
  group('décodage', () {
    test('les lignes et leurs décalages sortent du contenu', () {
      final l = NarrationScreen.decoder(corps);
      expect(l.map((e) => e.a).toList(), [0, 20, 40]);
      expect(l.first.texte, 'Léna ne répond plus...');
    });

    // Un contenu illisible ne doit pas noircir l'écran indéfiniment : mieux
    // vaut ne rien afficher et laisser l'histoire continuer.
    for (final mauvais in [null, '', 'pas du json', '{"texte":"seul"}', '[42]']) {
      test('« ${mauvais ?? "null"} » ne casse rien', () {
        expect(NarrationScreen.decoder(mauvais), isEmpty);
      });
    }
  });

  // La musique d'un écran noir voyage sur le `media_url` de SON message : c'est
  // ce qui permet au trajet et à l'incident d'avoir chacun la leur. Le fil est
  // la seule source — rien n'est déduit du nœud, que le client ne connaît pas.
  group('l\'écran en cours et sa musique', () {
    ClientMessage message(String type, {String? media}) =>
        ClientMessage.fromJson({
          'seq': 1,
          'contact_id': 'lena',
          'sender': 'contact',
          'content_type': type,
          'body': corpsTrajet,
          'media_url': media,
        });

    ConversationState etat(List<ClientMessage> fil) => ConversationState(
          fil: fil,
          node: null,
          conversations: const [],
          chapterEnd: null,
          typing: TypingState.aucun,
          presence: null,
          enDeroule: false,
          mode: ComposerMode.decorative,
          heures: const {},
        );

    test('le dernier message délivré porte l\'écran, et sa musique', () {
      final m = message('narration', media: '/musique-N14-trajet.mp3');
      expect(etat([m]).narrationEnCours?.mediaUrl, '/musique-N14-trajet.mp3');
    });

    test('un message derrière referme l\'écran', () {
      expect(
          etat([message('narration'), message('text')]).narrationEnCours, isNull);
    });

    test('fil vide : aucun écran', () {
      expect(etat(const []).narrationEnCours, isNull);
    });

    // Fichier pas encore téléversé : l'écran se joue en silence plutôt que
    // d'empêcher l'histoire d'avancer — même repli que pour une photo.
    test('un média non livré reste reconnaissable comme tel', () {
      final m = message('narration', media: 'placeholder://musique-N14-trajet');
      expect(etat([m]).narrationEnCours!.isPlaceholderMedia, isTrue);
    });
  });

  testWidgets('les lignes se posent à leur heure, la dernière reste inachevée',
      (tester) async {
    // Animations coupées : la frappe est instantanée, donc ce test mesure les
    // DÉCALAGES entre lignes sans dépendre de la vitesse de frappe. Il exerce
    // au passage le chemin d'accessibilité.
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
      theme: AppTheme.sombre,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: NarrationScreen(lignes: NarrationScreen.decoder(corps)),
      ),
    )));

    await tester.pump();
    await tester.pump();
    expect(find.text('Léna ne répond plus...'), findsOneWidget);
    expect(find.text('Il fait nuit, elle est seule.'), findsNothing);

    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(find.text('Il fait nuit, elle est seule.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    // Coupée en pleine phrase. Ne jamais la compléter : la coupure est l'effet.
    expect(find.textContaining('ou prévenir la'), findsOneWidget);
    expect(find.textContaining('police'), findsNothing);
  });

  // L'écran du trajet suit exactement le même mécanisme, avec trois lignes et
  // leurs pauses. Sa dernière ligne, elle, est entière : « Allez-vous soutenir
  // cette inconnue ? » est rhétorique — aucune réponse n'est attendue, et rien
  // ne s'affiche derrière. C'est l'arrivée de Léna qui referme l'écran.
  testWidgets('l\'écran du trajet pose ses trois lignes, la dernière entière',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
      theme: AppTheme.sombre,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: NarrationScreen(lignes: NarrationScreen.decoder(corpsTrajet)),
      ),
    )));

    await tester.pump();
    await tester.pump();
    expect(find.text('Léna est en route pour l\'entrepôt...'), findsOneWidget);
    expect(find.textContaining('Elle cherche des réponses'), findsNothing);

    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    expect(find.text('Elle cherche des réponses, un indice, n\'importe quoi.'),
        findsOneWidget);
    expect(find.textContaining('Allez-vous'), findsNothing);

    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    expect(find.text('Allez-vous soutenir cette inconnue ?'), findsOneWidget);

    // Rhétorique : rien à répondre, donc rien pour répondre.
    expect(find.byType(Composer), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('aucune sortie, aucun champ de saisie', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
      theme: AppTheme.sombre,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: NarrationScreen(lignes: NarrationScreen.decoder(corps)),
      ),
    )));
    await tester.pump();

    // L'impuissance est la scène : un champ actif sur un écran noir sans fil
    // visible laisserait croire qu'une action est possible.
    expect(find.byType(Composer), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
