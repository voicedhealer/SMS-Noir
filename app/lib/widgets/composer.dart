import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Ce que fait l'envoi. **L'apparence ne change JAMAIS d'un mode à l'autre** :
/// si le champ changeait d'aspect quand l'IA écoute vraiment, le joueur saurait
/// instantanément quels moments comptent, et perdrait le doute qui rend le mode
/// décoratif intéressant. Voir docs/DESIGN.md § Champ de saisie.
enum ComposerMode {
  /// Le nœud propose des réponses : ce qu'on écrit ne part jamais.
  decorative,

  /// Nœud en pause : écrire fait avancer (`advance {continue:true}`).
  continuation,

  /// Moment IA — prompt 3. Saisie réelle.
  aiInput,
}

/// Champ de saisie.
///
/// Actif dans le silence (le joueur peut écrire, ses messages s'accumulent en
/// non délivrés, il agit sur son angoisse au lieu de la subir) et pendant un
/// vrai moment IA. **Verrouillé au tap, sans aucun changement d'aspect,
/// dès que des choix sont affichés** — [choixPresents] — pour qu'écrire dans
/// le vide ne devienne jamais un geste concurrent d'un vrai choix. Voir
/// docs/DESIGN.md § Champ de saisie.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.mode,
    required this.onEnvoyer,
    this.choixPresents = false,
    this.onFocusRecu,
    this.onSaisieChange,
    this.focusNode,
  });

  final ComposerMode mode;

  /// Des choix (réponses ou interactions) sont affichés à l'écran : le champ
  /// ignore alors tout geste — aucun focus, aucun clavier, aucun curseur
  /// clignotant. Jamais un changement d'aspect, seulement d'interactivité :
  /// un joueur qui compare une capture d'écran ne doit rien voir de différent.
  final bool choixPresents;

  /// Le texte saisi. C'est l'appelant qui décide quoi en faire selon le mode.
  final void Function(String texte) onEnvoyer;

  /// Le champ vient de recevoir le focus — le clavier est en train de s'ouvrir.
  ///
  /// Sert à révéler ce qui compte avant que le clavier ne le recouvre : un
  /// geste DÉLIBÉRÉ du joueur (il a tapé pour écrire), pas une livraison
  /// spontanée — donc ça peut faire défiler même s'il était remonté relire.
  final VoidCallback? onFocusRecu;

  /// Le champ passe de vide à non vide, ou l'inverse. Sert à masquer l'aparté
  /// dès que le joueur commence à écrire : l'invite a fait son travail, la
  /// laisser affichée par-dessus sa propre réponse n'a plus de sens.
  final void Function(bool ecrit)? onSaisieChange;

  /// Fourni par l'appelant quand il a besoin de connaître l'état du focus au-
  /// delà du seul instant où il est gagné — ici, pour continuer à ajuster le
  /// défilement pendant que le clavier finit son animation d'ouverture.
  /// Sinon, `Composer` gère le sien en interne, comme avant.
  final FocusNode? focusNode;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controleur = TextEditingController();
  late final FocusNode _focus;
  late final bool _focusEstNotre;
  var _vide = true;

  @override
  void initState() {
    super.initState();
    _focusEstNotre = widget.focusNode == null;
    _focus = widget.focusNode ?? FocusNode();
    _focus.canRequestFocus = !widget.choixPresents;
    _controleur.addListener(() {
      final vide = _controleur.text.trim().isEmpty;
      if (vide != _vide) {
        setState(() => _vide = vide);
        widget.onSaisieChange?.call(!vide);
      }
    });
    _focus.addListener(() {
      if (_focus.hasFocus) widget.onFocusRecu?.call();
    });
  }

  @override
  void didUpdateWidget(covariant Composer old) {
    super.didUpdateWidget(old);
    if (old.choixPresents == widget.choixPresents) return;
    _focus.canRequestFocus = !widget.choixPresents;
    // Des choix viennent d'apparaître pendant que le joueur écrivait : on ne
    // lui laisse pas un clavier ouvert concurrencer un vrai choix.
    if (widget.choixPresents && _focus.hasFocus) _focus.unfocus();
  }

  @override
  void dispose() {
    _controleur.dispose();
    // On ne détruit que le FocusNode qu'on a créé nous-mêmes : celui fourni
    // par l'appelant lui appartient, et sa durée de vie n'a pas de raison de
    // suivre celle de ce widget en particulier.
    if (_focusEstNotre) _focus.dispose();
    super.dispose();
  }

  void _envoyer() {
    final texte = _controleur.text.trim();
    if (texte.isEmpty) return;
    _controleur.clear();
    widget.onEnvoyer(texte);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(
        left: AppSpacing.m,
        right: AppSpacing.s,
        top: AppSpacing.s,
        bottom: MediaQuery.viewPaddingOf(context).bottom + AppSpacing.s,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            // Verrouille le geste, jamais l'aspect : `IgnorePointer` n'altère
            // rien visuellement, contrairement à `TextField(enabled: false)`
            // qui grise le champ — proscrit, voir DESIGN.md § Champ de saisie.
            child: IgnorePointer(
              ignoring: widget.choixPresents,
              child: Container(
                constraints: const BoxConstraints(minHeight: 38),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.fond,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: AppColors.separateurLigne),
                ),
                child: TextField(
                  controller: _controleur,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppText.corpsMessage.copyWith(color: AppColors.textePrincipal),
                  cursorColor: AppColors.bulleJoueur,
                  // Aucun libellé qui trahirait le mode. Le champ est le même partout.
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Message',
                    hintStyle: TextStyle(color: AppColors.texteTertiaire),
                    contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.s),
                  ),
                  onSubmitted: (_) => _envoyer(),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            onPressed: _vide ? null : _envoyer,
            icon: Icon(
              Icons.arrow_upward_rounded,
              color: _vide ? AppColors.texteTertiaire : AppColors.bulleJoueur,
            ),
            style: IconButton.styleFrom(
              backgroundColor: _vide ? Colors.transparent : AppColors.bulleJoueur.withValues(alpha: 0.15),
              minimumSize: const Size(38, 38),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le « + » discret.
///
/// Il ne dit jamais ce qu'il contient : son libellé est un simple « + », et les
/// répliques ne s'ouvrent qu'au tap. Au N8 elles porteraient sinon les deux
/// pistes d'enquête ; au N17, l'indice lui-même.
///
/// Il ne se distingue pas d'un bouton d'ajout de pièce jointe, ce qu'une vraie
/// messagerie a toujours — c'est exactement ce qu'on veut qu'il ait l'air d'être.
class DiscreetPlus extends StatelessWidget {
  const DiscreetPlus({
    super.key,
    required this.choix,
    required this.onChoisir,
    this.verrouille = false,
  });

  final List<({String id, String label})> choix;
  final void Function(String id) onChoisir;

  /// Même verrou temporisé que `ChoiceArea`, pour la même raison : laisser le
  /// temps de lire avant de pouvoir agir. Le bouton reste visible et identique
  /// — seul le geste ne fait rien tant que le verrou tient.
  final bool verrouille;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.surface,
        padding: const EdgeInsets.only(left: AppSpacing.l, top: AppSpacing.s),
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: verrouille ? null : () => _ouvrir(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s),
              child: Icon(Icons.add, size: 20, color: AppColors.texteTertiaire),
            ),
          ),
        ),
      );

  void _ouvrir(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.l)),
      ),
      builder: (contexte) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in choix)
              ListTile(
                title: Text(c.label,
                    style: AppText.libelleChoix.copyWith(color: AppColors.textePrincipal)),
                onTap: () {
                  Navigator.of(contexte).pop();
                  onChoisir(c.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Zone de choix. Masquée pendant un déroulé.
class ChoiceArea extends StatelessWidget {
  const ChoiceArea({
    super.key,
    required this.choix,
    required this.onChoisir,
    required this.verrouille,
  });

  /// Uniquement des `reply`/`ignore` — jamais d'interaction. Le filtrage se
  /// fait en amont : c'est une protection de mécanique, pas de mise en page.
  final List<({String id, String label, bool estIgnore})> choix;
  final void Function(String id) onChoisir;

  /// Un choix est déjà parti : on ne double-tape pas.
  final bool verrouille;

  @override
  Widget build(BuildContext context) {
    if (choix.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in choix)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: verrouille ? null : () => onChoisir(c.id),
                  style: TextButton.styleFrom(
                    // « Ignorer » est plus effacé : c'est un vrai choix, pas un
                    // abandon — mais il ne doit pas peser autant qu'une réponse.
                    backgroundColor: c.estIgnore ? Colors.transparent : AppColors.fond,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.m),
                      side: BorderSide(
                        color: c.estIgnore ? Colors.transparent : AppColors.separateurLigne,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.l, vertical: AppSpacing.m),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      c.label,
                      style: AppText.libelleChoix.copyWith(
                        color: c.estIgnore ? AppColors.texteSecondaire : AppColors.textePrincipal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
