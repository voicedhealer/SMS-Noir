import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../theme/tokens.dart';

/// « Ce qu'on sait » — le carnet de notes narratif.
///
/// Il existe pour donner une trace à l'exploration : trouver un indice caché
/// ne laissait rien derrière lui, et rien n'encourageait donc à chercher.
///
/// **Ce n'est pas un objet de jeu, et trois règles le tiennent :**
///
///  • **aucun compteur.** Pas de « 3/6 », pas de barre, pas de pastille sur
///    l'icône. Une partie ne peut de toute façon jamais rassembler les cinq
///    indices — les deux relances du N8 s'excluent — donc un compteur
///    annoncerait un complet impossible à atteindre ;
///  • **aucun emplacement vide.** Un indice non trouvé n'existe pas ici. Le
///    serveur n'envoie que les trouvés, si bien que le client ne pourrait pas
///    dessiner ce qui manque même s'il le voulait ;
///  • **l'enquête, pas la relation.** Ni les moments IA, ni les doutes, ni les
///    variables. Le carnet documente ce que le joueur a recueilli.
///
/// L'ordre est celui de la **découverte**, tel que le serveur l'envoie — jamais
/// un ordre de contenu, que personne n'a écrit.
class CarnetScreen extends StatelessWidget {
  const CarnetScreen({super.key, required this.clues});

  final List<Clue> clues;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: AppColors.fond,
        surfaceTintColor: Colors.transparent,
        // Le titre est le nom de l'écran, sans décompte ni sous-titre : y
        // ajouter « 3 notes » recréerait le compteur par la bande.
        title: Text('Ce qu\'on sait',
            style: AppText.titreEnTete.copyWith(color: AppColors.textePrincipal)),
      ),
      body: clues.isEmpty ? const _Vide() : _Notes(clues: clues),
    );
  }
}

/// Rien de trouvé. Une phrase, et c'est tout.
///
/// Surtout pas « 0/6 » ni « Continuez à chercher ! » : le premier est un
/// compteur, le second un objet de jeu qui souffle au joueur qu'il y a quelque
/// chose à faire. L'écran constate, il n'encourage pas.
class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Text(
          'Rien de noté pour l\'instant.',
          textAlign: TextAlign.center,
          style: AppText.corpsMessage.copyWith(color: AppColors.texteSecondaire),
        ),
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.clues});

  final List<Clue> clues;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.l),
      itemCount: clues.length,
      separatorBuilder: (_, _) => const Divider(
        height: AppSpacing.xxl,
        thickness: 1,
        color: AppColors.separateurLigne,
      ),
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text(
          // Le texte seul. Pas de code, pas de numéro, pas de date : ce sont
          // des notes prises à la volée, pas des fiches.
          clues[i].texte,
          style: AppText.corpsMessage.copyWith(
            color: AppColors.textePrincipal,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
