import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Carte d'entrée minimale — avant même l'intronisation.
///
/// Portée volontairement réduite : la vraie bibliothèque (plusieurs
/// histoires, à parcourir) viendra plus tard. En attendant, une seule
/// histoire ne mérite pas une liste — juste cette carte, absorbable par la
/// bibliothèque quand elle existera.
///
/// C'est elle qui précède le consentement IA (`ConsentScreen`, juste après un
/// tap), pas la première saisie libre du N9 : demandé une fois pour toutes,
/// avant que le joueur entre dans l'histoire — voir
/// `ConversationState.consentDecide`.
class EntryCardScreen extends StatelessWidget {
  const EntryCardScreen({super.key, required this.titre, this.accroche, required this.onEntrer});

  final String titre;
  final String? accroche;
  final VoidCallback onEntrer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onEntrer,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titre,
                    textAlign: TextAlign.center,
                    style: AppText.titreFinChapitre.copyWith(color: AppColors.textePrincipal),
                  ),
                  if (accroche case final texte?) ...[
                    const SizedBox(height: AppSpacing.l),
                    Text(
                      texte,
                      textAlign: TextAlign.center,
                      style: AppText.corpsMessage.copyWith(color: AppColors.texteSecondaire),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Toucher pour entrer',
                    style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
