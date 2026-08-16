import 'package:flutter/material.dart';

import '../config/env.dart';
import '../theme/tokens.dart';

/// Consentement au traitement des saisies libres (bible §9, RGPD).
///
/// Demandé **une seule fois**, à la première saisie libre. Sobre, dans le ton
/// de l'app : c'est une obligation légale, pas un moment de jeu — mais ce n'est
/// pas une raison pour la traiter comme une bannière de cookies.
///
/// Un refus n'est pas une impasse : l'histoire continue par le fallback, sans
/// pénalité. On ne redemande jamais.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.onReponse});

  /// `true` = accepté, `false` = refusé. Dans les deux cas l'histoire continue.
  final void Function(bool accepte) onReponse;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _coche = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text('Avant de répondre',
                  style: AppText.titreFinChapitre.copyWith(color: AppColors.textePrincipal)),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Ce que vous écrivez ici est traité par une intelligence artificielle '
                'pour personnaliser l\'histoire, et peut être conservé.',
                style: AppText.corpsMessage.copyWith(color: AppColors.texteSecondaire),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Un seul élément anodin de ce que vous direz est retenu — un prénom, '
                'une ville, un métier. Rien d\'autre.',
                style: AppText.corpsMessage.copyWith(color: AppColors.texteSecondaire),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Vous pouvez refuser : l\'histoire continue sans rien perdre.',
                style: AppText.corpsMessage.copyWith(color: AppColors.texteTertiaire),
              ),
              if (Env.politiqueConfidentialite != null) ...[
                const SizedBox(height: AppSpacing.m),
                Text('Politique de confidentialité : ${Env.politiqueConfidentialite}',
                    style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire)),
              ],
              const SizedBox(height: AppSpacing.xxl),
              InkWell(
                onTap: () => setState(() => _coche = !_coche),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  child: Row(
                    children: [
                      Icon(
                        _coche ? Icons.check_box : Icons.check_box_outline_blank,
                        color: _coche ? AppColors.bulleJoueur : AppColors.texteTertiaire,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Text("J'accepte ce traitement",
                            style: AppText.libelleChoix
                                .copyWith(color: AppColors.textePrincipal)),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  // Grisé tant que la case n'est pas cochée : un consentement
                  // ne se donne pas par inadvertance.
                  onPressed: _coche ? () => widget.onReponse(true) : null,
                  style: TextButton.styleFrom(
                    backgroundColor: _coche ? AppColors.bulleJoueur : AppColors.bulleContact,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.m),
                    ),
                  ),
                  child: Text('Continuer',
                      style: AppText.libelleChoix.copyWith(
                        color: _coche ? AppColors.texteJoueur : AppColors.texteTertiaire,
                      )),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Center(
                child: TextButton(
                  onPressed: () => widget.onReponse(false),
                  child: Text('Refuser',
                      style: AppText.libelleChoix.copyWith(color: AppColors.texteSecondaire)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
