import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/client_message.dart';
import 'package:numero_inconnu/services/read_receipts.dart';

ClientMessage m(int seq, MessageSender s, {ContentType t = ContentType.text, String? b = 'x'}) =>
    ClientMessage(
      seq: seq, contactId: 'c', sender: s, contentType: t, body: b, mediaUrl: null,
      delaySeconds: 0, typingSeconds: 0, pushNotification: false, pushText: null,
    );

ClientMessage deco(int seq) =>
    ClientMessage.decorative(contactId: 'c', texte: 'réponds', ancreSeq: seq);

void main() {
  test('le joueur répond, Léna enchaîne : vu', () {
    final fil = [m(1, MessageSender.player), m(2, MessageSender.contact)];
    expect(ReadReceipts.dernierVu(fil), 1);
  });

  test('rien ne suit : pas de marqueur — elle n\'a pas lu', () {
    final fil = [m(1, MessageSender.contact), m(2, MessageSender.player)];
    expect(ReadReceipts.dernierVu(fil), isNull);
  });

  test('un séparateur ne vaut pas lecture', () {
    final fil = [
      m(1, MessageSender.player),
      m(2, MessageSender.contact, t: ContentType.separator, b: '00h34'),
    ];
    expect(ReadReceipts.dernierVu(fil), isNull);
  });

  test('un changement de présence non plus — c\'est ce qui tient le N19', () {
    final fil = [
      m(1, MessageSender.player),
      m(2, MessageSender.contact, t: ContentType.system, b: 'Léna est hors ligne'),
    ];
    expect(ReadReceipts.dernierVu(fil), isNull);
  });

  test('le silence du N19 puis son retour : tout passe vu d\'un coup', () {
    // Elle part hors ligne, le joueur écrit trois fois dans le vide.
    final fil = [
      m(1, MessageSender.contact, b: 'merde'),
      m(2, MessageSender.contact, t: ContentType.system, b: 'Léna est hors ligne'),
      deco(3), deco(4), deco(5),
    ];
    expect(ReadReceipts.dernierVu(fil), isNull,
        reason: 'pendant le silence, aucun message décoratif n\'est vu');

    // Le séparateur « 00h34 » ne suffit pas : ce n'est pas une parole.
    fil.add(m(6, MessageSender.contact, t: ContentType.separator, b: '00h34'));
    expect(ReadReceipts.dernierVu(fil), isNull);

    // Elle reparle enfin.
    fil.add(m(7, MessageSender.contact, b: 'C\'est bon. Je suis dans ma caisse.'));
    expect(ReadReceipts.dernierVu(fil), 5,
        reason: 'le marqueur descend d\'un coup jusqu\'au dernier message écrit');
  });

  test('le marqueur est unique et suit le dernier message vu', () {
    final fil = [
      m(1, MessageSender.player),
      m(2, MessageSender.contact),
      m(3, MessageSender.player),
      m(4, MessageSender.contact),
    ];
    expect(ReadReceipts.dernierVu(fil), 3);
  });

  test('une photo ou un vocal valent parole', () {
    for (final t in [ContentType.image, ContentType.audio]) {
      final fil = [m(1, MessageSender.player), m(2, MessageSender.contact, t: t, b: null)];
      expect(ReadReceipts.dernierVu(fil), 1);
    }
  });
}
