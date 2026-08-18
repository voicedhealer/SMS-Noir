import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/client_message.dart';
import 'package:numero_inconnu/screens/video_transition_screen.dart';
import 'package:numero_inconnu/theme/app_theme.dart';
import 'package:numero_inconnu/widgets/composer.dart';

// Média en placeholder : `isPlaceholderMedia` court-circuite avant toute
// tentative de lecture réseau — même convention que les tests de PhotoBubble
// et AudioBubble. Ce test n'exerce donc pas le décodage vidéo lui-même (hors
// de portée d'un test widget), mais la SCÈNE : fond noir, aucune interaction,
// exactement ce que l'addendum §2 demande.
const _video = ClientMessage(
  seq: 1,
  contactId: 'lena',
  sender: MessageSender.contact,
  contentType: ContentType.video,
  body: null,
  mediaUrl: 'placeholder://lena-rentre-chez-elle',
  delaySeconds: 0,
  typingSeconds: 0,
  pushNotification: false,
  pushText: null,
);

void main() {
  testWidgets('aucune sortie, aucun bouton, aucun champ de saisie', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.sombre,
        home: const VideoTransitionScreen(message: _video),
      ),
    ));
    await tester.pump();

    // Même principe que l'écran noir narratif : c'est un sas, pas un menu.
    expect(find.byType(Composer), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('fond noir plein écran tant que la vidéo n\'est pas prête',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.sombre,
        home: const VideoTransitionScreen(message: _video),
      ),
    ));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.black);
    // Un média en placeholder ne casse pas l'écran : pas de VideoPlayer tant
    // qu'il n'y a rien à lire, jamais d'erreur visible.
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'VideoPlayer'),
        findsNothing);
  });
}
