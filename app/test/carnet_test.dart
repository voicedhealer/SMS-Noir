import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/game_state.dart';
import 'package:numero_inconnu/screens/carnet_screen.dart';
import 'package:numero_inconnu/theme/app_theme.dart';

const profil = 'Un homme, la cinquantaine. Toujours seul, toujours le jeudi. '
    'Il regarde autour de lui avant d\'entrer.';
const plaque = 'Une Peugeot 508 grise. Plaque partielle : ...843...';
const autocollant = 'Un macaron sur la vitre arrière de sa voiture : Sentinel Pro.';

Future<void> monter(WidgetTester tester, List<Clue> clues) => tester.pumpWidget(
      MaterialApp(theme: AppTheme.sombre, home: CarnetScreen(clues: clues)),
    );

void main() {
  group('décodage', () {
    test('le carnet arrive tel que le serveur l\'ordonne', () {
      final l = Clue.listeDe([
        {'code': 'PROFIL_SUSPECT', 'texte': profil},
        {'code': 'PLAQUE', 'texte': plaque},
      ]);
      expect(l.map((c) => c.code).toList(), ['PROFIL_SUSPECT', 'PLAQUE']);
      expect(l.first.texte, profil);
    });

    // Un indice dont on aurait oublié de rédiger le texte ne doit pas produire
    // une note vide dans le carnet : le serveur le filtre déjà, le client ne le
    // rattrape pas non plus.
    test('une note sans texte est ignorée', () {
      expect(Clue.listeDe([{'code': 'ORPHELIN', 'texte': ''}]), isEmpty);
    });

    for (final mauvais in [null, const [], 'pas une liste']) {
      test('« ${mauvais ?? "null"} » donne un carnet vide', () {
        expect(Clue.listeDe(mauvais), isEmpty);
      });
    }
  });

  testWidgets('rien de trouvé : une phrase, et rien d\'autre', (tester) async {
    await monter(tester, const []);
    expect(find.text('Rien de noté pour l\'instant.'), findsOneWidget);
  });

  testWidgets('les notes s\'affichent dans l\'ordre de découverte',
      (tester) async {
    // L'ordre vient du serveur (`variables.indices`, ordre d'ajout) : l'écran
    // ne trie pas. Un ordre de contenu n'existe pas — personne ne l'a écrit.
    await monter(tester, const [
      Clue(code: 'PLAQUE', texte: plaque),
      Clue(code: 'PROFIL_SUSPECT', texte: profil),
    ]);

    final rendus = tester.widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d == plaque || d == profil)
        .toList();
    expect(rendus, [plaque, profil]);
  });

  // La règle centrale du carnet : il documente l'enquête, il ne mesure pas la
  // progression. Une partie ne peut de toute façon jamais rassembler les cinq
  // indices — les deux relances du N8 s'excluent — donc tout compteur
  // annoncerait un complet inatteignable.
  testWidgets('aucun compteur, nulle part', (tester) async {
    await monter(tester, const [
      Clue(code: 'PROFIL_SUSPECT', texte: profil),
      Clue(code: 'PLAQUE', texte: plaque),
      Clue(code: 'AUTOCOLLANT', texte: autocollant),
    ]);

    final textes = tester.widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    // Le seul chiffre autorisé à l'écran est celui des textes eux-mêmes
    // (« 508 », « 843 »), jamais un décompte de notes.
    for (final compteur in ['3/', '/5', '/6', '3 notes', '3 indices']) {
      expect(textes.contains(compteur), isFalse,
          reason: 'le carnet ne compte pas : « $compteur » ne doit pas s\'afficher');
    }
    expect(find.textContaining('Rien de noté'), findsNothing);
  });

  // Un emplacement grisé pour un indice non trouvé dirait au joueur ce qu'il
  // lui reste à chercher. Le serveur n'envoie que les trouvés, donc l'écran ne
  // peut même pas en dessiner un — ce test épingle la conséquence visible.
  testWidgets('aucun emplacement pour ce qui n\'est pas trouvé', (tester) async {
    await monter(tester, const [Clue(code: 'PLAQUE', texte: plaque)]);
    expect(find.byType(ListTile), findsNothing);
    expect(find.textContaining('?'), findsNothing);
    expect(find.textContaining('à trouver'), findsNothing);
    expect(find.textContaining(profil), findsNothing);
  });

  testWidgets('le code d\'un indice n\'est jamais montré au joueur',
      (tester) async {
    await monter(tester, const [Clue(code: 'PROFIL_SUSPECT', texte: profil)]);
    expect(find.textContaining('PROFIL_SUSPECT'), findsNothing);
    expect(find.text(profil), findsOneWidget);
  });
}
