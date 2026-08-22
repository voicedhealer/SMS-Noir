import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numero_inconnu/models/game_state.dart';
import 'package:numero_inconnu/screens/chapter_end_screen.dart';
import 'package:numero_inconnu/theme/app_theme.dart';

ChapterEnd fin({
  String? nextChapterTitle = 'Chloé',
  int? nextChapterPosition = 2,
  DateTime? unlockedAt,
  bool nextChapterPending = true,
  int? nextChapterUnlockDelayMinutes = 480,
  String? nextChapterNotificationText = 'Léna vous attend. Le chapitre 2 est disponible.',
  String? nextChapterTeaserText,
}) =>
    ChapterEnd(
      chapterTitle: 'Le mauvais numéro',
      nextChapterTitle: nextChapterTitle,
      nextChapterPosition: nextChapterPosition,
      unlockedAt: unlockedAt ?? DateTime.now().add(const Duration(hours: 8)),
      nextChapterPending: nextChapterPending,
      nextChapterUnlockDelayMinutes: nextChapterUnlockDelayMinutes,
      nextChapterNotificationText: nextChapterNotificationText,
      nextChapterTeaserText: nextChapterTeaserText,
    );

Future<void> monter(
  WidgetTester tester, {
  required ChapterEnd fin,
  String texte = 'Quelqu\'un est entré chez Léna.',
}) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: AppTheme.sombre,
      home: ChapterEndScreen(fin: fin, texte: texte, onFermer: () {}),
    ),
  ));
  // Laisse le cliffhanger (une seule phrase ici) finir de s'écrire.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('le compte à rebours en chiffres a disparu', (tester) async {
    await monter(tester, fin: fin());
    // Aucun ':' à l'écran : ni hh:mm:ss, ni aucun autre affichage chiffré du
    // temps restant — remplacé par le bouton « Me prévenir ».
    expect(find.textContaining(':'), findsNothing);
  });

  testWidgets('le label du chapitre suivant porte son numéro', (tester) async {
    await monter(tester, fin: fin());
    expect(find.text('CHAPITRE 2 — CHLOÉ'), findsOneWidget);
  });

  testWidgets('le bouton « Me prévenir » porte le délai du serveur, jamais codé en dur',
      (tester) async {
    await monter(tester, fin: fin(nextChapterUnlockDelayMinutes: 90));
    expect(find.text('Me prévenir dans 1h30'), findsOneWidget);
  });

  testWidgets('le teaser ne s\'affiche que s\'il existe', (tester) async {
    await monter(tester, fin: fin());
    expect(find.text('Un secret.'), findsNothing);

    await monter(tester, fin: fin(nextChapterTeaserText: 'Un secret.'));
    expect(find.text('Un secret.'), findsOneWidget);
  });

  testWidgets('sans chapitre suivant, aucune des trois actions ne s\'affiche',
      (tester) async {
    await monter(tester, fin: fin(nextChapterTitle: null, nextChapterPosition: null));
    expect(find.text('Me prévenir'), findsNothing);
    expect(find.textContaining('Me prévenir'), findsNothing);
    expect(find.text('Débloquer ce chapitre'), findsNothing);
    expect(find.text('Voir toutes les offres'), findsNothing);
  });

  testWidgets(
      'tap sur « Me prévenir » : sans plateforme de notifications (test), '
      'bascule sur l\'état informatif, jamais un blocage', (tester) async {
    await monter(tester, fin: fin());
    expect(find.text('Me prévenir dans 8h'), findsOneWidget);

    await tester.tap(find.text('Me prévenir dans 8h'));
    await tester.pumpAndSettle();

    // `NotificationsLocales` ne peut rien accorder dans l'environnement de
    // test (aucune plateforme enregistrée) : c'est exactement le chemin
    // « refusé », et il doit rester un vrai bouton, pas un état bloqué.
    expect(find.text('Vous pourrez revenir consulter l\'histoire'), findsOneWidget);
    expect(find.text('Me prévenir dans 8h'), findsNothing);
  });

  testWidgets('« Débloquer ce chapitre » reste inerte mais répond, pas de crash',
      (tester) async {
    await monter(tester, fin: fin());
    await tester.tap(find.text('Débloquer ce chapitre'));
    await tester.pump();
    expect(find.textContaining('bientôt disponible'), findsOneWidget);
  });

  testWidgets('« Voir toutes les offres » reste inerte mais répond, pas de crash',
      (tester) async {
    await monter(tester, fin: fin());
    await tester.tap(find.text('Voir toutes les offres'));
    await tester.pump();
    expect(find.textContaining('bientôt disponible'), findsOneWidget);
  });

  testWidgets('« Revenir aux messages » reste présent et fonctionnel', (tester) async {
    var ferme = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.sombre,
        home: ChapterEndScreen(
          fin: fin(),
          texte: 'Quelqu\'un est entré chez Léna.',
          onFermer: () => ferme = true,
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revenir aux messages'));
    expect(ferme, isTrue);
  });

  testWidgets('« Écrivez-nous » reste un texte décoratif, pas un lien', (tester) async {
    await monter(tester, fin: fin());
    expect(find.textContaining('Écrivez-nous'), findsOneWidget);
  });
}
