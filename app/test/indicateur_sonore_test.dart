import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/services/indicateur_sonore.dart';

void main() {
  setUp(() {
    // Instance à état global : on repart propre à chaque test en coupant
    // tout ce qu'un test précédent aurait pu laisser enregistré.
    IndicateurSonore.instance.couperTout();
  });

  test('rien au repos', () {
    expect(IndicateurSonore.instance.enCours.value, isFalse);
  });

  test('une source enregistrée passe enCours à vrai', () {
    IndicateurSonore.instance.signaler(() {});
    expect(IndicateurSonore.instance.enCours.value, isTrue);
  });

  test('la source qui se désinscrit repasse enCours à faux', () {
    final desinscrire = IndicateurSonore.instance.signaler(() {});
    desinscrire();
    expect(IndicateurSonore.instance.enCours.value, isFalse);
  });

  test('deux sources : enCours ne retombe qu\'à la dernière désinscription', () {
    final finA = IndicateurSonore.instance.signaler(() {});
    IndicateurSonore.instance.signaler(() {});
    finA();
    expect(IndicateurSonore.instance.enCours.value, isTrue,
        reason: 'la seconde source joue toujours');
  });

  test('couperTout() appelle chaque arrêt et vide le registre', () {
    var arreteeA = false;
    var arreteeB = false;
    IndicateurSonore.instance.signaler(() => arreteeA = true);
    IndicateurSonore.instance.signaler(() => arreteeB = true);

    IndicateurSonore.instance.couperTout();

    expect(arreteeA, isTrue);
    expect(arreteeB, isTrue);
    expect(IndicateurSonore.instance.enCours.value, isFalse);
  });

  test('une désinscription rappelée deux fois ne fait rien de plus', () {
    final desinscrire = IndicateurSonore.instance.signaler(() {});
    IndicateurSonore.instance.signaler(() {}); // une deuxième source active
    desinscrire();
    desinscrire();
    expect(IndicateurSonore.instance.enCours.value, isTrue,
        reason: 'la deuxième source n\'a pas dû être désinscrite par erreur');
  });

  test('un arrêt qui se désinscrit lui-même pendant couperTout() ne casse rien', () {
    // Reproduit le cas réel : `MusiqueNarrative.arreter()` appelée par
    // `couperTout()` se désinscrit elle-même en retour, mutant le registre
    // pendant qu'on le parcourt.
    late VoidCallback desinscrire;
    void arreter() => desinscrire();
    desinscrire = IndicateurSonore.instance.signaler(arreter);

    IndicateurSonore.instance.couperTout();

    expect(IndicateurSonore.instance.enCours.value, isFalse);
  });
}
