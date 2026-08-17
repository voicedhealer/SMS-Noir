import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conversation_controller.dart';
import '../providers/reglages.dart';
import '../theme/tokens.dart';
import 'privacy_text.dart';

/// Réglages de l'application.
///
/// **Accessible depuis la liste des conversations uniquement.** Jamais depuis
/// le fil avec Léna : là-bas, aucun élément ne doit rappeler qu'on est dans une
/// app. Une vraie messagerie met ses paramètres dans l'en-tête de sa liste,
/// c'est exactement là qu'ils sont.
///
/// Contenu volontairement pauvre : son et vibrations, accessibilité,
/// confidentialité, effacement. **Pas de statistiques, pas de progression, pas
/// de chapitres débloqués** — ce sont des objets de jeu, et cette app n'en est
/// pas une.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(reglagesProvider);
    final notifier = ref.read(reglagesProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        backgroundColor: AppColors.fond,
        surfaceTintColor: Colors.transparent,
        title: Text('Réglages',
            style: AppText.titreEnTete.copyWith(color: AppColors.textePrincipal)),
      ),
      body: ListView(
        children: [
          _Section('Son'),
          _Bascule(
            titre: 'Sons',
            detail: 'Réception, envoi, musique.',
            valeur: r.sons,
            onChange: notifier.poserSons,
          ),
          _Bascule(
            titre: 'Vibrations',
            detail: 'À la réception d\'un message, quand le son est coupé.',
            valeur: r.vibrations,
            onChange: notifier.poserVibrations,
          ),
          _Section('Accessibilité'),
          _Bascule(
            titre: 'Ralentir le rythme',
            detail: 'Les textes narratifs s\'affichent d\'un coup, sans s\'écrire.',
            valeur: r.rythmeLent,
            onChange: notifier.poserRythmeLent,
          ),
          _Section('Confidentialité'),
          ListTile(
            title: Text('Politique de confidentialité',
                style: AppText.libelleChoix.copyWith(color: AppColors.textePrincipal)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.texteTertiaire),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const PrivacyScreen(),
            )),
          ),
          _Section('Données'),
          ListTile(
            title: Text('Effacer ma progression',
                style: AppText.libelleChoix.copyWith(color: AppColors.textePrincipal)),
            subtitle: Text('L\'histoire recommence depuis le début. Sans retour.',
                style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire)),
            onTap: () => _confirmerEffacement(context, ref),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _confirmerEffacement(BuildContext context, WidgetRef ref) async {
    // Irréversible, donc on demande. C'est le seul geste de l'app qui détruit
    // quelque chose que le joueur ne peut pas refaire autrement.
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.bulleContact,
        title: Text('Effacer la progression ?',
            style: AppText.libelleChoix.copyWith(color: AppColors.textePrincipal)),
        content: Text('Tout ce qui a été échangé sera perdu, et l\'histoire '
            'recommencera depuis le début.',
            style: AppText.corpsMessage.copyWith(color: AppColors.texteSecondaire)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text('Annuler',
                style: AppText.libelleChoix.copyWith(color: AppColors.texteSecondaire)),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text('Effacer',
                style: AppText.libelleChoix.copyWith(color: AppColors.textePrincipal)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(conversationProvider.notifier).reinitialiser();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

class _Section extends StatelessWidget {
  const _Section(this.titre);
  final String titre;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.l, AppSpacing.xl, AppSpacing.l, AppSpacing.s),
        child: Text(titre.toUpperCase(),
            style: AppText.separateur
                .copyWith(color: AppColors.texteTertiaire, letterSpacing: 1.5)),
      );
}

class _Bascule extends StatelessWidget {
  const _Bascule({
    required this.titre,
    required this.detail,
    required this.valeur,
    required this.onChange,
  });

  final String titre;
  final String detail;
  final bool valeur;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: valeur,
        onChanged: onChange,
        title: Text(titre,
            style: AppText.libelleChoix.copyWith(color: AppColors.textePrincipal)),
        subtitle: Text(detail,
            style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire)),
        activeThumbColor: AppColors.texteJoueur,
        activeTrackColor: AppColors.bulleJoueur,
      );
}
