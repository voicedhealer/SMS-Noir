import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/widgets/typewriter.dart';

const phrase = 'Quelqu\'un est entré chez Léna.';

Future<void> monter(WidgetTester tester,
    {bool sansAnimation = false, VoidCallback? onFini}) async {
  // Le typewriter lit le réglage « ralentir le rythme » de l'app en plus de
  // celui du système : il lui faut un ProviderScope.
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: sansAnimation),
        child: Scaffold(body: Typewriter(texte: phrase, onFini: onFini)),
      ),
    ),
  ));
  await tester.pump();
}

String affiche(WidgetTester tester) => tester.widget<Text>(find.byType(Text)).data!;

void main() {
  testWidgets('le texte s\'écrit progressivement', (tester) async {
    await monter(tester);
    expect(affiche(tester), isEmpty);

    await tester.pump(const Duration(milliseconds: 500));
    final debut = affiche(tester);
    expect(debut, isNotEmpty);
    expect(debut.length, lessThan(phrase.length));
    expect(phrase.startsWith(debut), isTrue);

    await tester.pump(const Duration(seconds: 5));
    expect(affiche(tester), phrase);
  });

  // Quelqu'un qui a activé « réduire les animations » a une raison, et un texte
  // qui se déroule peut être pénible à lire, voire déclencher des symptômes.
  testWidgets('animations réduites : tout s\'affiche d\'un coup', (tester) async {
    await monter(tester, sansAnimation: true);
    await tester.pump();
    expect(affiche(tester), phrase);
  });

  testWidgets('un tap complète la ligne en cours', (tester) async {
    await monter(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(affiche(tester).length, lessThan(phrase.length));

    await tester.tap(find.byType(Typewriter));
    await tester.pump();
    expect(affiche(tester), phrase);
  });

  testWidgets('la fin est annoncée une seule fois', (tester) async {
    // L'écran de fin enchaîne ses phrases sur ce signal : un double appel
    // ferait sauter une phrase entière.
    var appels = 0;
    await monter(tester, onFini: () => appels++);
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byType(Typewriter));
    await tester.pump(const Duration(seconds: 2));
    expect(appels, 1);
  });
}
