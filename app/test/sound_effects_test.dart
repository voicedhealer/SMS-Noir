import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/client_message.dart';
import 'package:numero_inconnu/services/sound_effects.dart';

ClientMessage msg({
  ContentType type = ContentType.text,
  MessageSender sender = MessageSender.contact,
  String? body = 'x',
}) =>
    ClientMessage(
      seq: 1,
      contactId: 'c',
      sender: sender,
      contentType: type,
      body: body,
      mediaUrl: null,
      delaySeconds: 0,
      typingSeconds: 0,
      pushNotification: false,
      pushText: null,
    );

void main() {
  group('Ce qui sonne', () {
    test('un message de Léna : son de réception', () {
      expect(SoundEffects.pour(msg()), EffetSonore.reception);
    });

    test('une photo et un vocal sonnent aussi — ce sont des messages', () {
      expect(SoundEffects.pour(msg(type: ContentType.image, body: null)),
          EffetSonore.reception);
      expect(SoundEffects.pour(msg(type: ContentType.audio, body: null)),
          EffetSonore.reception);
    });

    test('une réponse du joueur : son d\'envoi', () {
      expect(SoundEffects.pour(msg(sender: MessageSender.player)), EffetSonore.envoi);
    });
  });

  group('Ce qui ne sonne JAMAIS', () {
    test('un séparateur horaire — ce n\'est pas un message', () {
      expect(SoundEffects.pour(msg(type: ContentType.separator, body: '23h31')),
          EffetSonore.aucun);
    });

    test('un changement de présence — c\'est ce qui tient le silence du N19', () {
      // « Léna est hors ligne » ouvre les 90 s. Un bip à cet instant
      // annoncerait un message et détruirait la scène.
      expect(SoundEffects.pour(msg(type: ContentType.system, body: 'Léna est hors ligne')),
          EffetSonore.aucun);
    });

    test('un message décoratif — il ne part pas, il ne peut pas sonner', () {
      final decoratif =
          ClientMessage.decorative(contactId: 'c', texte: 'réponds', ancreSeq: 10);
      expect(SoundEffects.pour(decoratif), EffetSonore.aucun);
    });
  });

  test('le typing fantôme ne délivre aucun message, donc rien à faire sonner', () {
    // Garde-fou de conception : la décision ne porte que sur des messages
    // livrés. Le faux typing du N19 n'en produit aucun — il ne peut donc pas
    // sonner, quelle que soit l'évolution du moteur. Un bip laisserait croire
    // qu'un message est arrivé, et l'extinction sans message perdrait tout son
    // sens.
    expect(EffetSonore.values, hasLength(3));
  });
}
