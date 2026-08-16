import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conversation_controller.dart';
import '../theme/tokens.dart';
import 'conversation_list_screen.dart';
import 'conversation_screen.dart';
import 'intro_screen.dart';

/// Aiguillage d'entrée.
///
/// La séquence d'intronisation précède **tout**, y compris la liste des
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationProvider);
    final intro = async.value?.intro;

    if (intro != null) {
      _introJouee = true;
      return IntroScreen(
        intro: intro,
        onTermine: () {
          final navigateur = Navigator.of(context);
          // On bascule tout de suite : les 4 s de vide se jouent DANS la
          // conversation, écran ouvert et vide, pas sur le noir de l'intro.
          navigateur.push(
            MaterialPageRoute(builder: (_) => const ConversationScreen()),
          );
          ref.read(conversationProvider.notifier).introTerminee();
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
