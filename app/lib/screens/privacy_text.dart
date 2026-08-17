import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Politique de confidentialité, **texte intégral embarqué**.
///
/// Embarquée et pas liée : le joueur peut la lire hors ligne, elle ne peut pas
/// pointer vers une page morte, et elle est versionnée avec le code qu'elle
/// décrit. C'est aussi ce qui lève le blocage `PRIVACY_URL` — l'écran de
/// consentement du moment IA a désormais quelque chose à montrer.
///
/// ⚠️ **Deux champs restent à compléter par Vivien** : l'identité du
/// responsable de traitement et l'adresse de contact. Je ne les invente pas —
/// un document qui désigne un responsable fictif ne protège personne, et
/// tromperait le joueur sur qui détient ses données.
const _texte = '''
Cette application raconte une histoire par messages. Elle collecte le minimum
nécessaire pour que l'histoire fonctionne, et rien pour autre chose.

## Ce qui est enregistré

**Votre progression** — les nœuds atteints, les choix faits, les messages
échangés dans la fiction. C'est ce qui permet de reprendre l'histoire là où vous
l'avez laissée.

**Un compte anonyme** — créé automatiquement à la première ouverture. Aucune
adresse e-mail, aucun numéro de téléphone, aucun identifiant publicitaire. Rien
ne relie ce compte à votre identité.

## Les moments d'écriture libre

À certains moments, vous pouvez écrire un message de votre choix. Ce texte est
transmis à **Mistral AI**, un fournisseur européen de modèles de langage, pour
produire la réponse du personnage. Il est traité sur des serveurs situés dans
l'Union européenne.

Ces moments ne surviennent **qu'après votre consentement explicite**, demandé la
première fois. Refuser n'empêche pas de jouer : l'histoire continue autrement,
sans perte.

De ce que vous écrivez, **un seul élément est conservé** : un détail anodin que
vous auriez donné sur vous — un prénom, une ville, un métier, un animal. Rien
d'autre. Tout ce qui touche à la santé, aux croyances, aux opinions, à la vie
intime, aux origines ou à vos coordonnées est écarté automatiquement, y compris
si vous le mentionnez.

## Ce qui n'est jamais fait

Aucune publicité. Aucun traceur. Aucune revente. Aucun partage avec un tiers
autre que l'hébergement et le fournisseur de modèle nommés ici.

## Vos droits

Vous pouvez **effacer toute votre progression** depuis les Réglages, à tout
moment et sans justification. L'effacement est immédiat et définitif.

Le compte étant anonyme, il n'existe aucun moyen pour nous de retrouver vos
données à partir de votre identité : l'effacement depuis l'application est donc
le moyen le plus direct d'exercer votre droit à la suppression.

## Hébergement

Les données sont hébergées par **Supabase**, sur des serveurs situés dans
l'Union européenne.

## Responsable de traitement

À COMPLÉTER — identité et adresse du responsable de traitement.

## Contact

À COMPLÉTER — adresse à laquelle exercer vos droits.
''';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: AppColors.fond,
        surfaceTintColor: Colors.transparent,
        title: Text('Confidentialité',
            style: AppText.titreEnTete.copyWith(color: AppColors.textePrincipal)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          for (final bloc in _texte.trim().split('\n\n'))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.l),
              child: bloc.startsWith('## ')
                  ? Text(bloc.substring(3),
                      style: AppText.libelleChoix
                          .copyWith(color: AppColors.textePrincipal))
                  : Text(
                      bloc.replaceAll('\n', ' ').replaceAll('**', ''),
                      style: AppText.corpsMessage
                          .copyWith(color: AppColors.texteSecondaire, height: 1.5),
                    ),
            ),
        ],
      ),
    );
  }
}
