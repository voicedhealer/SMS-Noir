import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/client_message.dart';
import 'package:numero_inconnu/theme/app_theme.dart';
import 'package:numero_inconnu/theme/tokens.dart';
import 'package:numero_inconnu/widgets/message_widgets.dart';

ClientMessage msg(MessageSender qui, String texte) => ClientMessage(
      seq: 1, contactId: 'c', sender: qui, contentType: ContentType.text,
      body: texte, mediaUrl: null, delaySeconds: 0, typingSeconds: 0,
      pushNotification: false, pushText: null,
    );

/// Un texte assez long pour que la bulle bute forcément sur sa largeur maximale.
const long =
    'Si j\'y vais et qu\'il m\'arrive un truc, il faut que quelqu\'un sache où je suis. '
    'T\'as rien demandé, je sais. Mais t\'es là, et c\'est déjà beaucoup pour ce soir.';

Future<Size> mesurer(WidgetTester tester, MessageSender qui) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.sombre,
    home: Scaffold(body: MessageBubble(message: msg(qui, long))),
  ));
  // On mesure le DecoratedBox, pas le Container : `getSize` sur ce dernier
  // inclurait sa marge externe, qui vit HORS de la contrainte de largeur.
  // C'est la surface colorée que le lecteur voit, et c'est elle qui définit
  // le couloir laissé en face.
  return tester.getSize(find
      .descendant(of: find.byType(MessageBubble), matching: find.byType(DecoratedBox))
      .first);
}

void main() {
  // Le couloir vide en face de chaque colonne est ce qui dit au lecteur que
  // chaque interlocuteur a son côté de l'écran — plus que l'alignement, qui ne
  // se voit plus quand les deux colonnes se rejoignent au milieu.
  //
  // C'est une contrainte esthétique, donc la première à disparaître lors d'une
  // refonte : on la verrouille ici plutôt que dans une relecture.
  testWidgets('une bulle ne dépasse jamais 72 % de la largeur', (tester) async {
    const ecran = 1080 / 3;

    for (final qui in [MessageSender.contact, MessageSender.player]) {
      final taille = await mesurer(tester, qui);
      expect(taille.width / ecran, lessThanOrEqualTo(AppSpacing.largeurMaxBulle + 0.001),
          reason: '$qui déborde du couloir');
      expect(taille.width / ecran, greaterThan(0.6),
          reason: '$qui : le texte est assez long pour buter sur la limite, '
              'une bulle étroite voudrait dire que la contrainte ne s\'applique pas');
      // Le couloir vide en face : au moins un quart de l'écran.
      expect(ecran - taille.width, greaterThan(ecran * 0.25),
          reason: '$qui : le couloir opposé s\'est refermé');
    }
  });

  test('la valeur documentée dans DESIGN.md est celle du code', () {
    expect(AppSpacing.largeurMaxBulle, 0.72);
  });
}
