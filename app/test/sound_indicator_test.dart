import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/services/indicateur_sonore.dart';
import 'package:numero_inconnu/widgets/sound_indicator.dart';

void main() {
  setUp(() {
    IndicateurSonore.instance.couperTout();
  });

  Future<void> monter(WidgetTester tester) => tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SoundIndicatorOverlay()),
        ),
      );

  testWidgets('absente tant qu\'aucun son narratif ne joue', (tester) async {
    await monter(tester);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });

  testWidgets('apparaît dès qu\'une source démarre', (tester) async {
    await monter(tester);
    IndicateurSonore.instance.signaler(() {});
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('disparaît quand la source se désinscrit', (tester) async {
    await monter(tester);
    final desinscrire = IndicateurSonore.instance.signaler(() {});
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    desinscrire();
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });

  testWidgets('le tap coupe la source et fait disparaître l\'icône', (tester) async {
    await monter(tester);
    var coupee = false;
    IndicateurSonore.instance.signaler(() => coupee = true);
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();

    expect(coupee, isTrue);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });

  testWidgets('pulse sans jamais disparaître complètement (présence, pas clignotement)',
      (tester) async {
    await monter(tester);
    IndicateurSonore.instance.signaler(() {});
    await tester.pump();

    final opacites = <double>[];
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      opacites.add(opacityWidget.opacity);
    }
    expect(opacites.every((o) => o >= 0.5), isTrue,
        reason: 'jamais totalement éteinte');
    expect(opacites.toSet().length, greaterThan(1), reason: 'ça pulse vraiment');
  });
}
