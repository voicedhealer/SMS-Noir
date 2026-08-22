import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/services/notifications_locales.dart';

void main() {
  // Aucune implémentation de plateforme n'est enregistrée dans
  // `flutter test` (ni iOS ni Android réels) : ces tests vérifient
  // précisément que le service ne lève JAMAIS dans ce cas — le même
  // environnement qu'un futur test d'un écran qui l'utilise.

  test('programmer() ne lève jamais et renvoie false sans plateforme', () async {
    final ok = await NotificationsLocales.instance.programmer(
      quand: DateTime.now().add(const Duration(hours: 8)),
      titre: 'SMS Noir',
      corps: 'Léna vous attend. Le chapitre 2 est disponible.',
    );
    expect(ok, isFalse);
  });

  test('programmee ne lève jamais et renvoie false sans plateforme', () async {
    expect(await NotificationsLocales.instance.programmee, isFalse);
  });

  test('annuler() ne lève jamais, même sans rien à annuler', () async {
    await expectLater(NotificationsLocales.instance.annuler(), completes);
  });
}
