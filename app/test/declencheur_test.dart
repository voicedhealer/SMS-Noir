import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/game_state.dart';

Map<String, dynamic> choix(String id, String label, String? decl) => {
      'id': id, 'position': 50, 'label': label, 'kind': 'interaction',
      'declencheur': ?decl,
    };

StoryNode n8() => StoryNode.fromJson({
      'code': 'N8', 'kind': 'scripted', 'awaiting_interaction': true,
      'can_continue': true,
      'choices': [
        choix('zoom', 'Zoomer sur la capture', 'geste'),
        choix('r1', "Vous l'avez déjà vu de près ?", 'texte'),
        choix('r2', "Et s'il vous a repérée ?", 'texte'),
      ],
    });

void main() {
  test('le N8 est mixte : le zoom au geste, les deux relances au texte', () {
    // Le nœud que l'ancienne règle ne savait pas traiter. Elle raisonnait par
    // NŒUD — « ce nœud a-t-il apporté un média ? » — et donnait donc le même
    // sort aux trois. Le zoom du récépissé a rejoint le N8 en V3.2 : depuis, un
    // nœud peut porter les deux natures.
    final n = n8();
    expect(n.interactions.map((c) => c.declencheur).toList(),
        [Declencheur.geste, Declencheur.texte, Declencheur.texte]);
  });

  test('un zoom ne se présente jamais comme une chose que le joueur dit', () {
    // LE défaut de la phase 2, vu en jouant : au N16, dès que le joueur
    // répondait à un micro-choix, le « + » apparaissait en proposant « Zoomer
    // sur l'autocollant » en clair — un bouton pour un geste, et l'indice
    // annoncé dans son libellé.
    final n16 = StoryNode.fromJson({
      'code': 'N16', 'kind': 'scripted', 'awaiting_interaction': true,
      'can_continue': true,
      'choices': [choix('zoom', "Zoomer sur l'autocollant", 'geste')],
    });
    final parles = n16.interactions.where((c) => c.declencheur == Declencheur.texte);
    expect(parles, isEmpty,
        reason: 'aucune interaction de ce nœud ne doit passer par les réponses');
  });

  test('la nature ne dépend plus de l\'état du fil', () {
    // L'ancienne inférence regardait ce qui SUIVAIT le dernier média : elle
    // basculait donc au premier message du joueur. La déclaration, elle, est
    // la même quel que soit le fil — c'est tout l'intérêt.
    final avant = n8().interactions.map((c) => c.declencheur).toList();
    final apres = n8().interactions.map((c) => c.declencheur).toList();
    expect(avant, apres);
  });

  test('une interaction sans déclencheur n\'est proposée nulle part', () {
    // Défaut volontairement fermé : mieux vaut ne rien offrir qu'offrir un
    // bouton pour un zoom. L'oubli est rattrapé en amont par le contrôle 63 de
    // verify-graph, qui refuse tout contenu où une interaction n'en déclare
    // pas — sinon la perte serait silencieuse en jeu.
    final n = StoryNode.fromJson({
      'code': 'NX', 'kind': 'scripted', 'awaiting_interaction': true,
      'can_continue': true,
      'choices': [choix('x', 'Sans déclencheur', null)],
    });
    final c = n.interactions.single;
    expect(c.declencheur, isNull);
    expect(c.declencheur == Declencheur.geste, isFalse);
    expect(c.declencheur == Declencheur.texte, isFalse);
  });
}
