import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/services/duree_lisible.dart';

void main() {
  test('8h — le cas réel du chapitre 2 (480 min)', () {
    expect(dureeLisible(480), '8h');
  });

  test('moins d\'une heure', () {
    expect(dureeLisible(45), '45 min');
  });

  test('heures rondes', () {
    expect(dureeLisible(120), '2h');
  });

  test('heures avec un reste', () {
    expect(dureeLisible(90), '1h30');
  });

  test('un jour tout rond', () {
    expect(dureeLisible(24 * 60), '1 jour');
  });

  test('plusieurs jours avec un reste d\'heures', () {
    expect(dureeLisible(2 * 24 * 60 + 3 * 60), '2 jours 3 h');
  });
}
