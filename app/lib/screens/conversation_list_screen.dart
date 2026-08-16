import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../models/client_message.dart';
import '../providers/conversation_controller.dart';
import '../services/fiction_clock.dart';
import '../theme/tokens.dart';
import 'conversation_screen.dart';

/// Liste des conversations.
///
/// Une seule au chapitre 1, mais l'architecture est multi-conversations dès
/// maintenant : au chapitre 4 un deuxième puis un troisième contact écrivent, et
/// un groupe apparaît. Le coût est nul aujourd'hui, il serait élevé après.
class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          // Outil de développement : rejoue l'histoire depuis l'intronisation.
          // Absent en release — l'arbre est élagué à la compilation.
          if (Env.outilsDebug)
            IconButton(
              icon: const Icon(Icons.restart_alt, color: AppColors.texteTertiaire),
              tooltip: 'Réinitialiser l\'histoire',
              onPressed: () => ref.read(conversationProvider.notifier).reinitialiser(),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.texteTertiaire),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text('$e',
                textAlign: TextAlign.center,
                style: AppText.corpsMessage.copyWith(color: AppColors.texteSecondaire)),
          ),
        ),
        data: (etat) => ListView(
          children: [
            for (final c in etat.conversations)
              _Ligne(
                nom: c.displayName,
                revele: c.revealed,
                dernier: _apercu(etat.fil, c.contactId),
                heure: _heure(etat, c.contactId),
                nonLus: etat.nonLus,
                onOuvrir: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConversationScreen()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _apercu(List<ClientMessage> fil, String contactId) {
    for (final m in fil.reversed) {
      if (m.contactId != contactId) continue;
      // Un séparateur ou un changement de présence n'est pas un message :
      // on remonte jusqu'au dernier vrai contenu.
      if (m.contentType == ContentType.separator || m.contentType == ContentType.system) {
        continue;
      }
      return switch (m.contentType) {
        ContentType.image => 'Photo',
        ContentType.audio => 'Message vocal',
        ContentType.text => m.body ?? '',
        _ => '',
      };
    }
    return '';
  }

  /// Heure **de fiction**, jamais l'horloge système — y compris ici.
  String _heure(ConversationState etat, String contactId) {
    for (final m in etat.fil.reversed) {
      if (m.contactId != contactId) continue;
      final min = etat.heures[m.seq];
      if (min != null) return FictionClock.formater(min);
    }
    return '';
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.nom,
    required this.revele,
    required this.dernier,
    required this.heure,
    required this.nonLus,
    required this.onOuvrir,
  });

  final String nom;
  final bool revele;
  final String dernier;
  final String heure;
  final int nonLus;
  final VoidCallback onOuvrir;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onOuvrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l, vertical: AppSpacing.m),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.bulleContact,
                child: Icon(
                  // Tant que le contact n'est pas révélé, pas d'initiale : ce
                  // serait déjà dire quelque chose de lui.
                  revele ? Icons.person : Icons.help_outline,
                  color: AppColors.texteTertiaire,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          // La bascule d'identité est un micro-événement
                          // narratif : on lui accorde du temps.
                          child: AnimatedSwitcher(
                            duration: AppMotion.basculeIdentite,
                            // Sans ça, le switcher centre son enfant et le nom
                            // se retrouve au milieu de la ligne.
                            layoutBuilder: (courant, precedents) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [...precedents, ?courant],
                            ),
                            child: Text(nom,
                                key: ValueKey(nom),
                                style: AppText.titreConversation
                                    .copyWith(color: AppColors.textePrincipal)),
                          ),
                        ),
                        Text(heure,
                            style: AppText.horodatage
                                .copyWith(color: AppColors.texteTertiaire)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dernier,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.apercuConversation
                                .copyWith(color: AppColors.texteSecondaire),
                          ),
                        ),
                        if (nonLus > 0) ...[
                          const SizedBox(width: AppSpacing.s),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.pastille,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$nonLus',
                                style: AppText.horodatage
                                    .copyWith(color: AppColors.texteJoueur)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
