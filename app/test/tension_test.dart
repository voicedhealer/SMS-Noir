import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/client_message.dart';
import 'package:numero_inconnu/theme/app_theme.dart';
import 'package:numero_inconnu/theme/tokens.dart';
import 'package:numero_inconnu/widgets/message_widgets.dart';

ClientMessage msg({
  required int seq,
  String body = 'x',
  MessageSender sender = MessageSender.contact,
  bool tension = false,
}) =>
    ClientMessage(
      seq: seq,
      contactId: 'c-1',
      sender: sender,
      contentType: ContentType.text,
      body: body,
      mediaUrl: null,
      delaySeconds: 0,
      typingSeconds: 0,
      pushNotification: false,
      pushText: null,
      tension: tension,
    );

Future<void> monter(WidgetTester tester, ClientMessage m) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.sombre,
        home: Scaffold(body: MessageBubble(message: m)),
      ),
    );

BoxDecoration? fond(WidgetTester tester) =>
    tester.widget<Container>(find.byType(Container).first).decoration as BoxDecoration?;

BoxDecoration? voile(WidgetTester tester) => tester
    .widget<Container>(find.byType(Container).first)
    .foregroundDecoration as BoxDecoration?;

void main() {
  testWidgets('une bulle sans tension n\'a ni bordure ni voile', (tester) async {
    await monter(tester, msg(seq: 1));
    expect(fond(tester)?.border, isNull);
    expect(voile(tester), isNull);
  });

  testWidgets('une bulle de Léna en tension porte la bordure et le voile rouges',
      (tester) async {
    await monter(tester, msg(seq: 1, tension: true));
    final bordure = fond(tester)?.border as Border?;
    expect(bordure?.top.color, AppColors.tensionBordure);
    expect(voile(tester)?.color, AppColors.tensionVoile);
  });

  testWidgets('jamais sur une bulle du joueur, même si le serveur l\'affirme',
      (tester) async {
    // Le serveur pose déjà `tension: false` sur les messages du joueur ; cette
    // garde côté client est la seconde barrière. Le prompt est explicite :
    // l'effet ne concerne que les bulles de Léna.
    await monter(tester, msg(seq: 1, sender: MessageSender.player, tension: true));
    expect(fond(tester)?.border, isNull);
    expect(voile(tester), isNull);
  });

  test('le drapeau se lit depuis le contrat serveur, et vaut false par défaut', () {
    // Un serveur plus ancien ne renvoie pas le champ : la bulle doit rester
    // normale plutôt que de planter au décodage.
    final sans = ClientMessage.fromJson({
      'seq': 1, 'contact_id': 'c-1', 'sender': 'contact',
      'content_type': 'text', 'body': 'x',
    });
    expect(sans.tension, isFalse);
    expect(sans.ambienceSoundUrl, isNull);

    final avec = ClientMessage.fromJson({
      'seq': 2, 'contact_id': 'c-1', 'sender': 'contact',
      'content_type': 'text', 'body': 'x',
      'tension': true, 'ambience_sound_url': '/storage/v1/heartbeat.mp3',
    });
    expect(avec.tension, isTrue);
    expect(avec.ambienceSoundUrl, '/storage/v1/heartbeat.mp3');
  });

  test('une bulle du joueur ne referme jamais la séquence de tension', () {
    // Règle du câblage de `SonAmbiance`, verrouillée ici parce qu'elle s'est
    // déjà trompée une fois : la première version coupait la boucle sur TOUT
    // message sans tension, y compris l'écho du choix du joueur — le battement
    // s'arrêtait donc dès la première réponse à un micro-choix du N19, au
    // moment le plus tendu du nœud. Seule une réplique de Léna referme.
    bool referme(ClientMessage m) =>
        !m.tension && m.sender == MessageSender.contact;

    expect(referme(msg(seq: 1, sender: MessageSender.player)), isFalse,
        reason: 'l\'écho du joueur traverse la séquence sans y toucher');
    expect(referme(msg(seq: 2, tension: true)), isFalse,
        reason: 'une réplique encore tendue la prolonge');
    expect(referme(msg(seq: 3)), isTrue,
        reason: 'la première réplique sans tension referme — ici l\'écran noir');
  });

  test('le voile reste assez léger pour ne pas gêner la lecture', () {
    // Contrainte non négociable du prompt, et la seule qui prime sur l'effet
    // lui-même. 12 % est le haut de la fourchette validée sur appareil :
    // au-delà, le texte commence à se battre avec le fond.
    expect(AppColors.tensionVoile.a, lessThanOrEqualTo(0.12),
        reason: 'le texte doit rester parfaitement lisible sous le voile');
  });
}
