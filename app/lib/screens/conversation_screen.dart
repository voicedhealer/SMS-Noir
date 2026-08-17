import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../models/client_message.dart';
import '../models/game_state.dart';
import '../providers/conversation_controller.dart';
import '../services/fiction_clock.dart';
import '../services/playback.dart';
import '../theme/tokens.dart';
import '../widgets/composer.dart';
import '../widgets/message_widgets.dart';
import 'chapter_end_screen.dart';
import 'consent_screen.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scroll = ScrollController();
  bool _finMontree = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(conversationProvider.notifier).marquerLu());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _versLeBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.arriveeMessage,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationProvider);
    final ctrl = ref.read(conversationProvider.notifier);

    ref.listen(conversationProvider, (_, _) => _versLeBas());

    // Fin de chapitre : plein écran, une fois le déroulé terminé.
    final etatCourant = async.value;
    if (etatCourant != null &&
        !_finMontree &&
        !etatCourant.enDeroule &&
        etatCourant.chapterEnd != null &&
        etatCourant.texteFinDeChapitre != null) {
      _finMontree = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChapterEndScreen(
            fin: etatCourant.chapterEnd!,
            texte: etatCourant.texteFinDeChapitre!,
            onFermer: () => Navigator.of(context).pop(),
          ),
          fullscreenDialog: true,
        ));
      });
    }

    return Scaffold(
      appBar: _EnTete(etat: async.value),
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
        data: (etat) {
          // Le consentement passe par-dessus le fil : c'est une obligation
          // légale, elle ne se glisse pas entre deux bulles.
          if (etat.consentementRequis) {
            return ConsentScreen(onReponse: ctrl.repondreConsentement);
          }
          final vu = etat.vu;
          return Column(
          children: [
            Expanded(
              child: Listener(
                // Toute action repousse l'affordance de continuation.
                onPointerDown: (_) => ctrl.signalerActivite(),
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                  itemCount: etat.fil.length + (etat.typing != TypingState.aucun ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == etat.fil.length) return const TypingIndicator();
                    return _Element(
                      message: etat.fil[i],
                      suivant: i + 1 < etat.fil.length ? etat.fil[i + 1] : null,
                      etat: etat,
                      vu: vu,
                    );
                  },
                ),
              ),
            ),
            if (!etat.enDeroule && etat.interactionsParlees.isNotEmpty)
              // « + » discret : les interactions que le joueur *dit* (relance
              // du N8, insistance du N13). Jamais leur libellé en clair —
              // il peut être l'indice lui-même.
              DiscreetPlus(
                choix: [
                  for (final c in etat.interactionsParlees) (id: c.id, label: c.label),
                ],
                onChoisir: ctrl.declencherInteraction,
              ),
            if (!etat.enDeroule)
              ChoiceArea(
                choix: [
                  for (final c in etat.node?.replies ?? const <ClientChoice>[])
                    (id: c.id, label: c.label, estIgnore: c.kind == ChoiceKind.ignore),
                ],
                onChoisir: ctrl.choisir,
                verrouille: false,
              ),
            Composer(
              mode: etat.mode,
              // Le mode décide de ce que devient le texte — le champ, lui, est
              // rigoureusement le même. Voir DESIGN.md § Champ de saisie.
              onEnvoyer: etat.mode == ComposerMode.aiInput
                  ? ctrl.envoyerAuMomentIA
                  : ctrl.envoyerTexte,
            ),
          ],
        );
        },
      ),
      // Outil de développement, absent en release.
      floatingActionButton: (Env.outilsDebug && (async.value?.enDeroule ?? false))
          ? FloatingActionButton.small(
              backgroundColor: AppColors.separateurFond,
              onPressed: ctrl.sauterLeDeroule,
              child: const Icon(Icons.fast_forward, color: AppColors.texteSecondaire),
            )
          : null,
    );
  }
}

/// En-tête : nom du contact et, en sous-titre, sa présence.
/// C'est là qu'une vraie messagerie l'affiche — et c'est ce qui rend les
/// 90 secondes de silence du N19 lisibles comme intentionnelles.
class _EnTete extends StatelessWidget implements PreferredSizeWidget {
  const _EnTete({required this.etat});
  final ConversationState? etat;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final contact = etat?.contact;
    final horsLigne = etat?.presence != null;
    return AppBar(
      titleSpacing: AppSpacing.s,
      title: Row(
        children: [
          // Avatar générique tant que le contact n'est pas révélé : une
          // initiale en dirait déjà trop.
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.bulleContact,
            child: Icon(
              (contact?.revealed ?? false) ? Icons.person : Icons.help_outline,
              size: 20,
              color: AppColors.texteTertiaire,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // La bascule « Numéro inconnu » -> « Léna » est un micro-événement
          // narratif : c'est la seule animation à laquelle on donne du temps.
          AnimatedSwitcher(
            duration: AppMotion.basculeIdentite,
            layoutBuilder: (courant, precedents) => Stack(
              alignment: Alignment.centerLeft,
              children: [...precedents, ?courant],
            ),
            child: Text(
              contact?.displayName ?? '',
              key: ValueKey(contact?.displayName),
              style: AppText.titreEnTete,
            ),
          ),
          if (etat != null)
            Row(
              children: [
                // Pastille de statut : verte en ligne, sourde hors ligne.
                // Pendant les 90 s du N19, c'est elle qui rend le vide lisible
                // comme intentionnel plutôt que comme une panne.
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: AppSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: horsLigne
                        ? AppColors.presenceHorsLigne
                        : AppColors.presenceEnLigne,
                    shape: BoxShape.circle,
                  ),
                ),
                Flexible(
                  child: Text(etat!.sousTitre,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sousTitrePresence
                          .copyWith(color: AppColors.texteSecondaire)),
                ),
              ],
            ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Element extends ConsumerWidget {
  const _Element({required this.message, required this.etat, this.suivant, this.vu});
  final ClientMessage message;

  /// Le message suivant du fil, pour savoir si on clôt un groupe.
  final ClientMessage? suivant;

  final ConversationState etat;

  /// `seq` du message qui porte le marqueur « Vu. » dans tout le fil.
  final int? vu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = etat.heures[message.seq];
    final heure = minutes == null ? null : FictionClock.formater(minutes);

    // Un groupe = même émetteur, même minute de FICTION, sans rien entre les
    // deux. La minute compte autant que l'émetteur : grouper sur le seul
    // émetteur ferait disparaître un changement d'heure au milieu d'une série,
    // et l'heure de fiction est la seule horloge que le joueur ait.
    final s = suivant;
    final finDeGroupe = s == null ||
        s.sender != message.sender ||
        s.contentType != ContentType.text ||
        message.contentType != ContentType.text ||
        etat.heures[s.seq] != minutes;

    return switch (message.contentType) {
      ContentType.separator => SeparatorPill(libelle: message.body ?? ''),
      // Un `system` n'est jamais une bulle : il a déjà changé la présence.
      ContentType.system => const SizedBox.shrink(),
      ContentType.image => PhotoBubble(
          message: message,
          heure: heure,
          onOuvrir: () {
            final ctrl = ref.read(conversationProvider.notifier);
            ctrl.signalerActivite();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PhotoViewer(
                message: message,
                // Le zoom lui-même est la mécanique. Seul le dernier média du
                // fil compte : zoomer une vieille photo ne déclenche rien.
                onZoom: (etat.interactionParGeste && message.seq == etat.dernierMedia?.seq)
                    ? ctrl.declencherInteraction
                    : null,
              ),
              fullscreenDialog: true,
            ));
          },
        ),
      ContentType.audio => AudioBubble(
          message: message,
          heure: heure,
          // La réécoute est l'interaction, pas un confort de lecture.
          onReecoute: (etat.interactionParGeste && message.seq == etat.dernierMedia?.seq)
              ? ref.read(conversationProvider.notifier).declencherInteraction
              : null,
        ),
      // La carte porte l'identité du contact du fil, pas un contenu propre.
      ContentType.contactCard => ContactCard(
          nom: etat.contact?.displayName ?? '',
          numero: etat.contact?.phoneNumber,
          enregistre: etat.contact?.revealed ?? false,
          onEnregistrer: () =>
              ref.read(conversationProvider.notifier).enregistrerContact(),
        ),
      ContentType.text => Padding(
          padding: EdgeInsets.only(
              bottom: finDeGroupe ? AppSpacing.interGroupes : AppSpacing.interBulles),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MessageBubble(message: message),
              // Heure, « Vu. » et coche : sous le DERNIER du groupe seulement.
              if (finDeGroupe)
                MessageFooter(
                  duJoueur: message.sender == MessageSender.player,
                  heure: heure,
                  // Nul en tête-à-tête. Le mécanisme attend le groupe du ch. 3.
                  nom: etat.contact != null && etat.estGroupe ? etat.nomDe(message) : null,
                  vu: message.seq == vu,
                  nonDelivre: message.isLocalDecorative,
                ),
            ],
          ),
        ),
    };
  }
}
