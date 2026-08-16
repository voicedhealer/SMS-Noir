import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/client_message.dart';
import 'package:numero_inconnu/services/fiction_clock.dart';
import 'package:numero_inconnu/services/playback.dart';

ClientMessage msg({
  required int seq,
  String? body = 'x',
  ContentType type = ContentType.text,
  MessageSender sender = MessageSender.contact,
  int delay = 0,
  int typing = 0,
  int? phantom,
  int? haptic,
}) =>
    ClientMessage(
      seq: seq,
      contactId: 'c-1',
      sender: sender,
      contentType: type,
      body: body,
      mediaUrl: null,
      delaySeconds: delay,
      typingSeconds: typing,
      pushNotification: false,
      pushText: null,
      phantomTypingAt: phantom,
      hapticAt: haptic,
    );

/// Horloge simulée : le moteur attend, le test décide quand le temps passe.
class Horloge {
  final List<({int secondes, Completer<void> quand})> _attentes = [];
  int ecoule = 0;

  Future<void> attendre(Duration d) {
    final c = Completer<void>();
    if (d.inSeconds <= 0) return Future<void>.value();
    _attentes.add((secondes: d.inSeconds, quand: c));
    return c.future;
  }

  /// Avance de [secondes].
  ///
  /// ⚠️ Toutes les attentes en cours avancent **ensemble**. Le moteur en a
  /// plusieurs en parallèle — le délai d'un message et, par-dessus, les rafales
  /// de typing. Les sérialiser donnerait des résultats faux.
  Future<void> avancer(int secondes) async {
    await _laisserTournerLesMicrotaches();
    for (var i = 0; i < secondes; i++) {
      ecoule++;
      final echues = <Completer<void>>[];
      for (var j = 0; j < _attentes.length; j++) {
        final a = _attentes[j];
        _attentes[j] = (secondes: a.secondes - 1, quand: a.quand);
        if (a.secondes - 1 <= 0) echues.add(a.quand);
      }
      _attentes.removeWhere((a) => a.secondes <= 0);
      for (final c in echues) {
        c.complete();
      }
      await _laisserTournerLesMicrotaches();
    }
  }

  Future<void> _laisserTournerLesMicrotaches() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  group('Déroulé temporel', () {
    late Horloge horloge;
    late List<ClientMessage> delivres;
    late PlaybackEngine moteur;
    late int vibrations;

    setUp(() {
      horloge = Horloge();
      delivres = [];
      vibrations = 0;
      moteur = PlaybackEngine(
        onMessage: delivres.add,
        onChangement: () {},
        onVibration: () => vibrations++,
        duree: horloge.attendre,
      );
    });

    test('les messages arrivent dans l\'ordre, chacun après son délai', () async {
      unawaited(moteur.jouer([
        msg(seq: 1, body: 'un', delay: 0),
        msg(seq: 2, body: 'deux', delay: 25),
        msg(seq: 3, body: 'trois', delay: 8),
      ]));
      await horloge.avancer(0);
      expect(delivres.map((m) => m.body), ['un']);

      await horloge.avancer(24);
      expect(delivres.map((m) => m.body), ['un'], reason: 'pas encore : 25 s attendues');

      await horloge.avancer(1);
      expect(delivres.map((m) => m.body), ['un', 'deux']);

      await horloge.avancer(8);
      expect(delivres.map((m) => m.body), ['un', 'deux', 'trois']);
    });

    test('un déroulé en cours masque la zone de choix', () async {
      expect(moteur.enCours, isFalse);
      unawaited(moteur.jouer([msg(seq: 1, delay: 10)]));
      await horloge.avancer(1);
      expect(moteur.enCours, isTrue);
      await horloge.avancer(10);
      expect(moteur.enCours, isFalse);
    });

    test('le typing occupe la fin de l\'attente et annonce le message', () async {
      unawaited(moteur.jouer([msg(seq: 1, delay: 10, typing: 3)]));
      await horloge.avancer(6);
      expect(moteur.typing, TypingState.aucun, reason: 'silence pendant 10 - 3 = 7 s');

      await horloge.avancer(2);
      expect(moteur.typing, TypingState.reel);

      await horloge.avancer(2);
      expect(moteur.typing, TypingState.aucun);
      expect(delivres, hasLength(1));
    });

    test('au-delà du seuil, le typing se joue en rafales (N2, N13)', () async {
      // N13#0 : delay 50, typing 50 — hésitation par à-coups.
      unawaited(moteur.jouer([msg(seq: 1, delay: 50, typing: 50)]));
      await horloge.avancer(1);
      expect(moteur.typing, TypingState.reel, reason: 'première rafale visible');

      await horloge.avancer(5);
      expect(moteur.typing, TypingState.aucun, reason: 'la rafale s\'interrompt');

      await horloge.avancer(3);
      expect(moteur.typing, TypingState.reel, reason: 'elle reprend');
      expect(delivres, isEmpty, reason: 'le message n\'est pas encore arrivé');
    });
  });

  group('Mise en scène du grand silence (N19 → N20)', () {
    late Horloge horloge;
    late PlaybackEngine moteur;
    late List<ClientMessage> delivres;
    late int vibrations;

    setUp(() {
      horloge = Horloge();
      delivres = [];
      vibrations = 0;
      moteur = PlaybackEngine(
        onMessage: delivres.add,
        onChangement: () {},
        onVibration: () => vibrations++,
        duree: horloge.attendre,
      );
    });

    test('le typing FANTÔME ne signale jamais de frappe — sinon le son trahit', () async {
      var frappes = 0;
      final moteurSonore = PlaybackEngine(
        onMessage: delivres.add,
        onChangement: () {},
        onVibration: () => vibrations++,
        onTypingReel: () => frappes++,
        duree: horloge.attendre,
      );
      unawaited(moteurSonore.jouer([
        msg(seq: 1, body: '00h34', type: ContentType.separator, delay: 90, phantom: 45, haptic: 60),
      ]));
      await horloge.avancer(50);
      expect(moteurSonore.typing, TypingState.aucun);
      expect(frappes, 0,
          reason: 'un son de frappe ici laisserait croire qu\'un message arrive');
      await horloge.avancer(45);
      expect(frappes, 0, reason: 'et jusqu\'au bout du silence');
    });

    test('elle lit AVANT de taper : Vu. puis points puis réponse', () async {
      final lectures = <int>[];
      var frappes = 0;
      final moteur2 = PlaybackEngine(
        onMessage: delivres.add,
        onChangement: () {},
        onLecture: () => lectures.add(horloge.ecoule),
        onTypingReel: () => frappes++,
        duree: horloge.attendre,
      );
      // Sa réponse au N3 : 25 s d'attente dont 3 s de frappe.
      unawaited(moteur2.jouer([msg(seq: 1, body: 'Attends', delay: 25, typing: 3)]));

      await horloge.avancer(1);
      expect(lectures, [0], reason: 'elle a lu tout de suite');
      expect(frappes, 0, reason: 'mais elle ne tape pas encore');
      expect(moteur2.typing, TypingState.aucun);

      await horloge.avancer(21);
      expect(frappes, 1, reason: 'la frappe démarre bien après la lecture');
      expect(delivres, isEmpty);

      await horloge.avancer(3);
      expect(delivres, hasLength(1), reason: 'et la réponse arrive en dernier');
    });

    test('un séparateur ne vaut pas lecture — les 90 s du N19 restent muettes',
        () async {
      final lectures = <int>[];
      final moteur2 = PlaybackEngine(
        onMessage: delivres.add,
        onChangement: () {},
        onLecture: () => lectures.add(horloge.ecoule),
        duree: horloge.attendre,
      );
      unawaited(moteur2.jouer([
        msg(seq: 1, body: '00h34', type: ContentType.separator, delay: 90),
        msg(seq: 2, body: 'C\'est bon.', delay: 4, typing: 3),
      ]));
      await horloge.avancer(89);
      expect(lectures, isEmpty,
          reason: 'elle est absente : rien ne doit indiquer qu\'elle a lu');

      await horloge.avancer(2);
      expect(lectures, hasLength(1), reason: 'le Vu. tombe à son retour, pas avant');
    });

    test('le typing RÉEL signale une frappe, une seule par message', () async {
      var frappes = 0;
      final moteurSonore = PlaybackEngine(
        onMessage: delivres.add,
        onChangement: () {},
        onTypingReel: () => frappes++,
        duree: horloge.attendre,
      );
      // N13#0 : 50 s de typing intermittent — plusieurs rafales, une seule prise
      // de parole, donc un seul son.
      unawaited(moteurSonore.jouer([msg(seq: 1, delay: 50, typing: 50)]));
      await horloge.avancer(30);
      expect(frappes, 1);
      await horloge.avancer(25);
      expect(frappes, 1, reason: 'les rafales ne rejouent pas le son');
    });

    test('faux typing à 45 s, 2 s, puis extinction sans message ; vibration à 60 s', () async {
      // Le séparateur « 00h34 » porte les 90 s : phantom 45, haptic 60.
      unawaited(moteur.jouer([
        msg(seq: 1, body: '00h34', type: ContentType.separator, delay: 90, phantom: 45, haptic: 60),
      ]));

      await horloge.avancer(44);
      expect(moteur.typing, TypingState.aucun, reason: 'le vide, d\'abord');
      expect(vibrations, 0);

      await horloge.avancer(1);
      expect(moteur.typing, TypingState.fantome, reason: 'elle a l\'air d\'écrire');
      expect(delivres, isEmpty);

      await horloge.avancer(2);
      expect(moteur.typing, TypingState.aucun,
          reason: 'il s\'éteint SANS qu\'aucun message n\'arrive — le cœur de la scène');
      expect(delivres, isEmpty);

      await horloge.avancer(13);
      expect(vibrations, 1, reason: 'vibration à 60 s');

      await horloge.avancer(30);
      expect(delivres, hasLength(1), reason: 'le séparateur arrive enfin, à 90 s');
      expect(vibrations, 1, reason: 'une seule vibration');
    });
  });

  group('Présence', () {
    test('un message system change le statut, sans créer de bulle', () async {
      final horloge = Horloge();
      final delivres = <ClientMessage>[];
      final moteur = PlaybackEngine(
        onMessage: delivres.add,
        onChangement: () {},
        duree: horloge.attendre,
      );

      unawaited(moteur.jouer([
        msg(seq: 1, body: 'Léna est hors ligne', type: ContentType.system, delay: 0),
        msg(seq: 2, body: 'il sort', delay: 5),
      ]));
      await horloge.avancer(0);
      expect(moteur.presence, 'Léna est hors ligne');

      await horloge.avancer(5);
      expect(moteur.presence, isNull,
          reason: 'le retour en ligne n\'est jamais annoncé : on le déduit du message');
    });
  });

  group('Interruption et reprise', () {
    test('ce qui reste est conservé pour être rejoué après une fermeture', () async {
      final horloge = Horloge();
      final delivres = <ClientMessage>[];
      final moteur = PlaybackEngine(
        onMessage: delivres.add,
        onChangement: () {},
        duree: horloge.attendre,
      );

      unawaited(moteur.jouer([
        msg(seq: 1, body: 'un', delay: 0),
        msg(seq: 2, body: 'deux', delay: 60),
        msg(seq: 3, body: 'trois', delay: 10),
      ]));
      await horloge.avancer(5);
      moteur.interrompre();

      expect(delivres.map((m) => m.body), ['un']);
      expect(moteur.restants.map((m) => m.body), ['deux', 'trois'],
          reason: 'rien n\'est perdu : le reste est persistable');
      expect(moteur.enCours, isFalse);
    });

    test('le bouton skip délivre tout, immédiatement', () async {
      final horloge = Horloge();
      final delivres = <ClientMessage>[];
      final moteur = PlaybackEngine(
        onMessage: delivres.add,
        onChangement: () {},
        duree: horloge.attendre,
      );

      unawaited(moteur.jouer([
        msg(seq: 1, body: 'un', delay: 0),
        msg(seq: 2, body: 'deux', delay: 90),
        msg(seq: 3, body: 'trois', delay: 60),
      ]));
      await horloge.avancer(1);
      moteur.sauter();

      expect(delivres.map((m) => m.body), ['un', 'deux', 'trois']);
      expect(moteur.restants, isEmpty);
      expect(moteur.enCours, isFalse);
    });
  });

  group('Horloge de fiction', () {
    test('un séparateur ancre l\'heure, les délais l\'avancent', () {
      final fil = [
        msg(seq: 1, body: '23h31', type: ContentType.separator),
        msg(seq: 2, delay: 4),
        msg(seq: 3, delay: 60),
        msg(seq: 4, delay: 4),
      ];
      final h = FictionClock.horaires(fil);
      expect(FictionClock.formater(h[1]!), '23h31');
      expect(FictionClock.formater(h[2]!), '23h31');
      expect(FictionClock.formater(h[3]!), '23h32');
      expect(FictionClock.formater(h[4]!), '23h32');
    });

    test('un nouveau séparateur réancre : la dérive ne s\'accumule pas', () {
      final fil = [
        msg(seq: 1, body: '23h31', type: ContentType.separator),
        msg(seq: 2, delay: 120),
        msg(seq: 3, body: '00h34', type: ContentType.separator),
        msg(seq: 4, delay: 4),
      ];
      final h = FictionClock.horaires(fil);
      expect(FictionClock.formater(h[2]!), '23h33');
      expect(FictionClock.formater(h[3]!), '00h34');
      expect(FictionClock.formater(h[4]!), '00h34');
    });

    test('le libellé du premier séparateur porte un jour', () {
      expect(FictionClock.formater(FictionClock.ancre('jeudi — 22h47')!), '22h47');
      expect(FictionClock.ancre('pas une heure'), isNull);
      expect(FictionClock.ancre('99h99'), isNull);
    });

    test('l\'heure courante est celle du dernier message : c\'est le « vu »', () {
      final fil = [
        msg(seq: 1, body: '23h31', type: ContentType.separator),
        msg(seq: 2, delay: 60),
        msg(seq: 3, delay: 60),
      ];
      expect(FictionClock.formater(FictionClock.maintenant(fil)!), '23h33');
    });

    test('aucune heure inventée avant le premier séparateur', () {
      final h = FictionClock.horaires([msg(seq: 1, delay: 10)]);
      expect(h, isEmpty);
    });

    test('un message décoratif porte l\'heure courante sans la faire avancer', () {
      final fil = [
        msg(seq: 1, body: '23h31', type: ContentType.separator),
        ClientMessage.decorative(contactId: 'c-1', texte: 'réponds', ancreSeq: 2),
        msg(seq: 3, delay: 60),
      ];
      final h = FictionClock.horaires(fil);
      expect(FictionClock.formater(h[2]!), '23h31');
      expect(FictionClock.formater(h[3]!), '23h32');
    });
  });
}
