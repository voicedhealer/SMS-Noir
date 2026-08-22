import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/screens/entry_card_screen.dart';
import 'package:numero_inconnu/theme/app_theme.dart';

/// `pumpAndSettle` ne convient plus pour cet écran : la respiration de la
/// couverture boucle indéfiniment (`repeat(reverse: true)`), donc aucune
/// frame ne « se stabilise » jamais. On avance le temps d'un montant fixe,
/// largement suffisant pour que l'entrée séquentielle (image, puis textes en
/// fondu) ait fini, sans attendre que tout s'arrête.
Future<void> etablirEntree(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

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
    await etablirEntree(tester);
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
    await etablirEntree(tester);

    expect(find.textContaining('Politique de confidentialité'), findsOneWidget);
  });

  testWidgets('aucun accroche ne laisse aucun espace vide béant', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.sombre,
      home: EntryCardScreen(titre: 'Numéro Inconnu', onEntrer: (_) {}),
    ));
    await etablirEntree(tester);

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
      await etablirEntree(tester);

      expect(find.text('Casque ou haut-parleur recommandé'), findsOneWidget,
          reason: 'accroche: $accroche');
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    }
  });

  testWidgets('« Entrer » s\'active seulement une fois la case cochée', (tester) async {
    var appele = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.sombre,
      home: EntryCardScreen(titre: 'Numéro Inconnu', onEntrer: (_) => appele = true),
    ));
    await etablirEntree(tester);

    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Entrer')).onPressed,
      isNull,
      reason: 'case décochée par défaut (bible §9) : rien à activer encore',
    );

    await tester.tap(find.text('Entrer'), warnIfMissed: false);
    await tester.pump();
    expect(appele, isFalse, reason: 'bouton inactif : le tap ne doit rien déclencher');

    await tester.tap(find.byIcon(Icons.check_box_outline_blank));
    await tester.pump();
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Entrer')).onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Entrer'));
    await tester.pump();
    expect(appele, isTrue);
  });
}
