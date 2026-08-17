import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/screens/narration_screen.dart';
import 'package:numero_inconnu/theme/app_theme.dart';
import 'package:numero_inconnu/widgets/composer.dart';

const corps = '[{"texte":"Léna ne répond plus...","a":0},'
    '{"texte":"Il fait nuit, elle est seule.","a":20},'
    '{"texte":"Vous ne pouvez rien faire d\'autre qu\'attendre, ou prévenir la","a":40}]';

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
