import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../providers/session_providers.dart';
import '../theme/tokens.dart';

/// Écran d'amorçage de la Phase 1.
///
/// Il prouve que la chaîne complète fonctionne — session anonyme, appel du
/// moteur, désérialisation du contrat — et **sera remplacé** par la liste des
/// conversations en Phase 3. Il n'affiche que des données venues du serveur :
/// aucun contenu narratif n'est écrit ici.
class BootScreen extends ConsumerWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(gameStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: etat.when(
        loading: () => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.texteTertiaire),
          ),
        ),
        error: (e, _) => _Erreur(erreur: e, onReessayer: () => ref.invalidate(gameStateProvider)),
        data: (etat) => _Diagnostic(etat: etat),
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  const _Erreur({required this.erreur, required this.onReessayer});
  final Object erreur;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$erreur',
                  textAlign: TextAlign.center,
                  style: AppText.corpsMessage.copyWith(color: AppColors.texteSecondaire)),
              const SizedBox(height: AppSpacing.xl),
              TextButton(onPressed: onReessayer, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
}

class _Diagnostic extends StatelessWidget {
  const _Diagnostic({required this.etat});
  final GameState etat;

  @override
  Widget build(BuildContext context) {
    final noeud = etat.node;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        _ligne('Histoire', etat.storyTitle),
        _ligne('Conversations', etat.conversations.map((c) => c.displayName).join(', ')),
        _ligne('Identité révélée', '${etat.conversations.firstOrNull?.revealed}'),
        _ligne('Messages en historique', '${etat.history.length}'),
        _ligne('Nœud courant', noeud?.code ?? '—'),
        _ligne('Réponses proposées', '${noeud?.replies.length ?? 0}'),
        _ligne('Interactions disponibles', '${noeud?.interactions.length ?? 0}'),
        _ligne('En pause sur interaction', '${noeud?.awaitingInteraction}'),
        _ligne('Continuation possible', '${noeud?.canContinue}'),
        _ligne('Moment IA', '${etat.aiMomentPending}'),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Écran de diagnostic — Phase 1. Remplacé par la liste des '
          'conversations en Phase 3.',
          style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire),
        ),
      ],
    );
  }

  Widget _ligne(String cle, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 180,
              child: Text(cle,
                  style: AppText.apercuConversation.copyWith(color: AppColors.texteSecondaire)),
            ),
            Expanded(
              child: Text(valeur,
                  style: AppText.apercuConversation.copyWith(color: AppColors.textePrincipal)),
            ),
          ],
        ),
      );
}
