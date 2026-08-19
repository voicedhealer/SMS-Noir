import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conversation_controller.dart';
import '../theme/tokens.dart';
import 'consent_screen.dart';
import 'conversation_list_screen.dart';
import 'conversation_screen.dart';
import 'entry_card_screen.dart';
import 'intro_screen.dart';

/// Aiguillage d'entrée.
///
/// La carte d'entrée (titre, accroche, consentement IA) précède **tout**, y
/// compris l'intronisation : tant qu'aucune décision de consentement n'existe
/// en base, le joueur n'a même pas encore vu le titre de l'histoire. Puis la
/// séquence d'intronisation précède le reste, y compris la liste des
/// conversations. Une fois jouée, on bascule directement dans la conversation :
/// un message vient d'arriver, on ne fait pas passer le joueur par une liste
/// pour le lui dire. La liste reste dessous dans la pile — c'est là qu'il
/// reviendra, et c'est là que les ouvertures suivantes le déposeront.
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  bool _introJouee = false;

  /// La carte d'entrée a été tapée cette session : on peut montrer le
  /// consentement. Purement local — c'est `consentDecide` (état serveur) qui
  /// referme réellement la carte, pas ce drapeau.
  bool _entreeFaite = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationProvider);
    final etat = async.value;

    // Carte d'entrée + consentement IA, avant même l'intronisation — demandé
    // une fois pour toutes, pas à la première saisie libre du N9.
    if (etat != null && !etat.consentDecide) {
      if (!_entreeFaite) {
        return EntryCardScreen(
          titre: etat.storyTitle,
          accroche: etat.storyTagline,
          onEntrer: () => setState(() => _entreeFaite = true),
        );
      }
      return ConsentScreen(
        onReponse: ref.read(conversationProvider.notifier).repondreConsentement,
      );
    }

    final intro = etat?.intro;

    if (intro != null) {
      _introJouee = true;
      return IntroScreen(
        intro: intro,
        onTermine: () {
          // L'ordre compte : la partie synchrone de `introTerminee` marque le
          // déroulé comme imminent. Elle doit s'exécuter AVANT que l'écran de
          // conversation ne se construise, sinon il affiche brièvement des
          // réponses à un message qui n'est pas encore arrivé.
          ref.read(conversationProvider.notifier).introTerminee();
          // On bascule tout de suite : les 4 s de vide se jouent DANS la
          // conversation, écran ouvert et vide, pas sur le noir de l'intro.
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConversationScreen()),
          );
        },
      );
    }

    // Pendant le tout premier chargement, on ne montre pas une liste vide qui
    // se remplirait sous les yeux du joueur : un écran noir suffit.
    if (async.isLoading && !_introJouee) {
      return const Scaffold(
        backgroundColor: AppColors.fond,
        body: SizedBox.shrink(),
      );
    }

    return const ConversationListScreen();
  }
}
