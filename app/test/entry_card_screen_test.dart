import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/screens/entry_card_screen.dart';
import 'package:numero_inconnu/theme/app_theme.dart';

void main() {
  testWidgets('sans image de couverture, pas de tentative de chargement réseau',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.sombre,
      home: EntryCardScreen(titre: 'Numéro Inconnu', onEntrer: (_) {}),
    ));
    await tester.pump();

    // `Env.supabaseUrl` lève sans dart-define : ce test prouve que le chemin
    // « pas d'image de couverture » ne le sollicite jamais (pas d'exception
    // levée). L'icône de l'app reste affichée (Image.asset), seule l'image
    // réseau de couverture est absente.
    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage),
      findsNothing,
    );
  });

  testWidgets('réglage « réduire les animations » : tout est visible immédiatement',
      (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: AppTheme.sombre,
        home: EntryCardScreen(
          titre: 'Numéro Inconnu',
          accroche: 'Une accroche.',
          onEntrer: (_) {},
        ),
      ),
    ));
    // Une seule frame, volontairement : si l'animation n'était pas coupée,
    // le titre/l'accroche/le bouton seraient encore à opacité 0 ici.
    await tester.pump();

    final titre = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('Numéro Inconnu'), matching: find.byType(AnimatedOpacity)));
    final accroche = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('Une accroche.'), matching: find.byType(AnimatedOpacity)));
    final bouton = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('Entrer'), matching: find.byType(AnimatedOpacity)));

    expect(titre.opacity, 1);
    expect(accroche.opacity, 1);
    expect(bouton.opacity, 1);
  });

  testWidgets('sans le réglage, le titre n\'est pas encore visible à la toute première frame',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.sombre,
      home: EntryCardScreen(titre: 'Numéro Inconnu', onEntrer: (_) {}),
    ));
    await tester.pump();

    final titre = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('Numéro Inconnu'), matching: find.byType(AnimatedOpacity)));
    expect(titre.opacity, 0, reason: 'le fondu séquentiel démarre après l\'image');

    // Passé le délai de l'entrée, tout doit avoir fini d'apparaître.
    await tester.pumpAndSettle();
    final titreApres = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.text('Numéro Inconnu'), matching: find.byType(AnimatedOpacity)));
    expect(titreApres.opacity, 1);
  });

  testWidgets('le lien vers la politique de confidentialité est présent, souligné',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.sombre,
      home: EntryCardScreen(titre: 'Numéro Inconnu', onEntrer: (_) {}),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Politique de confidentialité'), findsOneWidget);
  });

  testWidgets('aucun accroche ne laisse aucun espace vide béant', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.sombre,
      home: EntryCardScreen(titre: 'Numéro Inconnu', onEntrer: (_) {}),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(EntryCardScreen), findsOneWidget);
  });

  testWidgets('recommandation casque/haut-parleur présente, avec ou sans accroche',
      (tester) async {
    for (final accroche in [null, 'Une accroche.']) {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.sombre,
        home: EntryCardScreen(
          titre: 'Numéro Inconnu',
          accroche: accroche,
          onEntrer: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Casque ou haut-parleur recommandé'), findsOneWidget,
          reason: 'accroche: $accroche');
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    }
  });
}
