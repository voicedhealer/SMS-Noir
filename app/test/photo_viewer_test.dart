import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/client_message.dart';
import 'package:numero_inconnu/theme/app_theme.dart';
import 'package:numero_inconnu/widgets/message_widgets.dart';

// Média en placeholder : `isPlaceholderMedia` court-circuite avant toute
// tentative de lecture réseau — `Env.supabaseUrl` lève si aucune base n'est
// configurée, ce que les tests widget ne fournissent jamais. Même convention
// que PhotoBubble/AudioBubble/VideoTransitionScreen.
//
// Le chemin réel (image chargée) — le sujet du §3.1 de l'addendum, `SizedBox
// .expand` + `BoxFit.contain` au lieu du rendu à taille intrinsèque — n'est
// donc pas exerçable ici : il n'y a pas de base à préfixer. Vérifié par
// lecture du widget (`message_widgets.dart`), pas par ce test.
const _photo = ClientMessage(
  seq: 1,
  contactId: 'lena',
  sender: MessageSender.contact,
  contentType: ContentType.image,
  body: null,
  mediaUrl: 'placeholder://photo-N16-plaque',
  delaySeconds: 0,
  typingSeconds: 0,
  pushNotification: false,
  pushText: null,
);

void main() {
  testWidgets('le zoom porte sur tout le corps, fond noir uniforme, sans bordure',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.sombre,
        home: const PhotoViewer(message: _photo),
      ),
    ));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);

    // Le zoom (InteractiveViewer) doit envelopper tout le contenu affiché,
    // pas juste le cartouche : c'est la mécanique cachée du geste.
    expect(
      find.descendant(
          of: find.byType(InteractiveViewer), matching: find.byType(MediaPlaceholder)),
      findsOneWidget,
    );
  });

  testWidgets('un média en placeholder ne casse pas la visionneuse', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.sombre,
        home: const PhotoViewer(message: _photo),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(PhotoViewer), findsOneWidget);
  });
}
