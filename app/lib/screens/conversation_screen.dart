import 'dart:async';

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
import 'narration_screen.dart';
import 'video_transition_screen.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scroll = ScrollController();
  final _focusChamp = FocusNode();
  bool _finMontree = false;
  Timer? _revelationClavier;

  /// Distance au bas du fil en dessous de laquelle une nouvelle livraison peut
  /// encore faire défiler automatiquement. Au-delà, le joueur a délibérément
  /// remonté pour relire, et rien ne doit l'en déloger — pas plus qu'une vraie
  /// messagerie ne le ferait.
  static const double _seuilProcheDuBas = 120;

  /// Les choix restent présents à l'écran dès l'arrivée du dernier message,
  /// mais ne répondent pas au tap tant que ce verrou tient. Aucune icône, aucun
  /// grisé : `TextButton.styleFrom` fixe la même couleur pour tous les états,
  /// donc rien à l'écran ne trahit ce court délai — le joueur se sent juste
  /// moins bousculé, sans jamais voir pourquoi.
  bool _choixVerrouilles = false;
  Timer? _minuteurChoix;

  /// `seq` du dernier message pour lequel le verrou a déjà été armé.
  ///
  /// Comparé à chaque `build()`, pas détecté par transition dans `ref.listen`.
  /// Riverpod ne garantit pas qu'un `ref.listen` posé pendant `build()` reçoive
  /// un événement pour la toute première émission (`previous == null`) — sur
  /// un écran ouvert directement sur un nœud déjà arrêté (aucun déroulé à
  /// jouer), cette première émission peut être la SEULE, et un verrou qui
  /// dépend d'y avoir assisté ne s'arme jamais. Une comparaison de marqueur à
  /// chaque `build()` n'a pas ce problème : elle voit chaque état, y compris
  /// le premier.
  int? _dernierLotArme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(conversationProvider.notifier).marquerLu());
  }

  /// Le clavier anime son ouverture sur ~250 ms côté système, et la liste
  /// elle-même ajuste son `maxScrollExtent` sur plusieurs frames pendant
  /// qu'elle défile — une lazy list ne stabilise pas sa mesure en un seul pas.
  /// Une seule révélation viserait une cible déjà dépassée. On réessaie donc
  /// à intervalles courts, tant que le champ garde le focus, borné pour ne
  /// jamais tourner indéfiniment.
  void _revelerPourClavier() {
    _revelationClavier?.cancel();
    var tentatives = 0;
    // Bornée à 2 s : largement au-dessus des ~300-400 ms d'une vraie
    // animation de clavier, avec de la marge pour le temps que la mesure
    // elle-même prenne à se stabiliser après un relayout de cette taille.
    _revelationClavier = Timer.periodic(const Duration(milliseconds: 50), (t) {
      tentatives++;
      if (!mounted || !_focusChamp.hasFocus || tentatives > 40) {
        t.cancel();
        return;
      }
      _versLeBas();
    });
  }

  @override
  void dispose() {
    _revelationClavier?.cancel();
    _minuteurChoix?.cancel();
    _focusChamp.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Le joueur était-il déjà en bas AVANT cette mise à jour ?
  ///
  /// Appelé depuis `ref.listen`, donc avant que le nouveau contenu soit posé
  /// dans la liste : `_scroll.position` reflète encore l'ancien fil. C'est ce
  /// qui permet de distinguer « il lit le direct » de « il est remonté ».
  bool get _procheDuBas {
    if (!_scroll.hasClients) return true;
    final pos = _scroll.position;
    return pos.pixels >= pos.maxScrollExtent - _seuilProcheDuBas;
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

  /// Un court silence avant que les choix ne répondent, pour laisser le temps
  /// de lire le dernier message. Sa durée suit la longueur de ce message :
  /// « Merci. » n'a pas besoin des deux secondes que mérite une réplique
  /// entière — mais elle reste bornée, pour ne jamais devenir une vraie
  /// attente.
  void _armerVerrouChoix(ConversationState? etat) {
    _minuteurChoix?.cancel();
    final dernier = (etat?.fil.isNotEmpty ?? false) ? etat!.fil.last.body ?? '' : '';
    final ms = (900 + dernier.length * 10).clamp(1000, 2000);
    setState(() => _choixVerrouilles = true);
    _minuteurChoix = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _choixVerrouilles = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationProvider);
    final ctrl = ref.read(conversationProvider.notifier);

    ref.listen(conversationProvider, (previous, next) {
      // Ne jamais voler la position de lecture : seul un joueur déjà proche du
      // bas suit le fil automatiquement.
      final premiereFois = previous == null || previous is! AsyncData;
      if (premiereFois || _procheDuBas) _versLeBas();
    });

    // Un lot de messages vient de s'installer (déroulé arrêté, choix présents
    // ou non) : si c'en est un nouveau, on arme le verrou. Comparé à chaque
    // build plutôt qu'à une transition — voir le commentaire sur
    // `_dernierLotArme`.
    final etatPourVerrou = async.value;
    if (etatPourVerrou != null && !etatPourVerrou.enDeroule) {
      final lot = etatPourVerrou.fil.isNotEmpty ? etatPourVerrou.fil.last.seq : -1;
      if (lot != _dernierLotArme) {
        _dernierLotArme = lot;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _armerVerrouChoix(etatPourVerrou));
      }
    }

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
            musique: etatCourant.musiqueFin,
            onFermer: () => Navigator.of(context).pop(),
          ),
          fullscreenDialog: true,
        ));
      });
    }

    // La vidéo de transition est un plan, pas un écran de messagerie : à la
    // différence du noir narratif (qui garde l'en-tête pour vendre l'absence
    // de Léna), elle occupe tout l'écran, sans aucun chrome de conversation.
    final videoEnCours = async.value?.videoEnCours;

    return Scaffold(
      appBar: videoEnCours != null ? null : _EnTete(etat: async.value),
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
          // L'écran noir prend toute la place tant que le message suivant
          // n'est pas arrivé. Il sort le joueur de la messagerie — les seuls
          // moments du chapitre où il n'a rien à faire, et c'est le sujet.
          //
          // Sa musique est celle de CE message : chaque écran a son segment
          // (une amorce « danger » au N14, sa reprise au N19). Un fichier pas
          // encore téléversé laisse un `placeholder://` : l'écran se joue alors
          // en silence, comme une photo manquante affiche son cartouche.
          final narration = etat.narrationEnCours;
          if (narration != null) {
            final lignes = NarrationScreen.decoder(narration.body);
            if (lignes.isNotEmpty) {
              return NarrationScreen(
                  lignes: lignes,
                  musique: narration.isPlaceholderMedia
                      ? null
                      : narration.mediaUrl);
            }
          }
          // Même principe, fond vidéo plutôt que noir pur — addendum
          // transition N20-N9 §2.
          final video = etat.videoEnCours;
          if (video != null) {
            return VideoTransitionScreen(message: video);
          }
          final vu = etat.vu;

          // Les choix vivent DANS la liste défilable, en dernière position —
          // pas dans une zone fixe sous elle. Une zone fixe ne peut que
          // déborder quand le clavier ouvre et grignote la moitié de l'écran :
          // en release, un débordement de Column est clipé en silence, ce qui
          // donnait l'impression que les choix disparaissaient sous la barre de
          // titre. Une liste, elle, ne déborde jamais — elle défile.
          final queue = <Widget>[
            if (etat.typing != TypingState.aucun) const TypingIndicator(),
            // L'aparté : générique, piloté par le contenu (`nodes.aparte`),
            // pas propre au moment IA. `aparteEnCours` porte déjà toute la
            // logique de visibilité (ni déroulé, ni typing) — rien à
            // dupliquer ici.
            if (etat.aparteEnCours case final texte?) Aparte(texte: texte),
            if (!etat.enDeroule)
              ChoiceArea(
                choix: [
                  for (final c in etat.node?.replies ?? const <ClientChoice>[])
                    (id: c.id, label: c.label, estIgnore: c.kind == ChoiceKind.ignore),
                ],
                onChoisir: ctrl.choisir,
                // Les interactions que le joueur *dit* : une option de plus,
                // atténuée, au même endroit que les réponses. Elles n'ont plus
                // de « + » qui les cache — leur libellé est la réplique
                // elle-même, jamais l'indice, celui-ci vivant toujours
                // derrière un `geste`.
                discrets: [
                  for (final c in etat.interactionsParlees) (id: c.id, label: c.label),
                ],
                onDiscret: ctrl.declencherInteraction,
                verrouille: _choixVerrouilles,
              ),
          ];

          // Même condition que celle qui peuple `ChoiceArea` ci-dessus — ses
          // deux listes, réponses et options atténuées : le champ se verrouille
          // exactement quand elles apparaissent, jamais avant, jamais après. Le moment IA reste
          // toujours exempté — c'est le seul mode où le champ sert vraiment.
          final choixPresents = etat.mode != ComposerMode.aiInput &&
              !etat.enDeroule &&
              (etat.interactionsParlees.isNotEmpty ||
                  (etat.node?.replies.isNotEmpty ?? false));

          return Column(
          children: [
            Expanded(
              child: Listener(
                // Toute action repousse l'affordance de continuation.
                onPointerDown: (_) => ctrl.signalerActivite(),
                // Le fil s'empile depuis le BAS, contre le champ de saisie,
                // comme toute vraie messagerie. Sans ça, un fil plus court que
                // l'écran (début de chapitre) se posait en haut et laissait un
                // grand vide entre les choix et le champ — repéré par Vivien
                // au N1. Ce n'était pas une zone réservée : c'était du
                // défilement vide, la ListView occupant toute la hauteur.
                //
                // `shrinkWrap` + `Align` plutôt que `reverse: true` : inverser
                // la liste ancrerait aussi le contenu en bas, mais inverserait
                // du même coup tout le repère de défilement (offset 0 = bas),
                // or c'est exactement ce repère que règlent les protections
                // « le fil ne vole jamais la position de lecture ». On ne
                // renverse pas un axe déjà couvert par des tests pour un
                // problème de mise en page.
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ListView.builder(
                    controller: _scroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                    itemCount: etat.fil.length + queue.length,
                    itemBuilder: (context, i) {
                      if (i >= etat.fil.length) return queue[i - etat.fil.length];
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
            ),
            Composer(
              mode: etat.mode,
              choixPresents: choixPresents,
              // Le mode décide de ce que devient le texte — le champ, lui, est
              // rigoureusement le même. Voir DESIGN.md § Champ de saisie.
              onEnvoyer: etat.mode == ComposerMode.aiInput
                  ? ctrl.envoyerAuMomentIA
                  : ctrl.envoyerTexte,
              // Geste délibéré : le joueur a tapé pour écrire, le clavier
              // s'apprête à recouvrir la moitié de l'écran. On révèle ce qui
              // compte MÊME s'il était remonté relire — contrairement à une
              // livraison spontanée, ce n'est pas lui voler sa position, c'est
              // répondre à son geste.
              onFocusRecu: _revelerPourClavier,
              onSaisieChange: ctrl.signalerSaisie,
              focusNode: _focusChamp,
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
    // deux — et ça vaut pour les trois types de bulle (texte, photo, audio) à
    // égalité. La minute compte autant que l'émetteur : grouper sur le seul
    // émetteur ferait disparaître un changement d'heure au milieu d'une série,
    // et l'heure de fiction est la seule horloge que le joueur ait.
    //
    // `estBulle` isole les VRAIES bulles des interruptions structurelles
    // (séparateur, système, carte de contact) : ces dernières cassent
    // toujours un groupe, une bulle ne le casse que si l'émetteur ou la
    // minute changent.
    bool estBulle(ContentType t) =>
        t == ContentType.text || t == ContentType.image || t == ContentType.audio;

    final s = suivant;
    final finDeGroupe = s == null ||
        s.sender != message.sender ||
        !estBulle(message.contentType) ||
        !estBulle(s.contentType) ||
        etat.heures[s.seq] != minutes;

    // Le contenu propre à chaque type — sans heure ni pied : c'est le même
    // pied, plus bas, qui les porte pour les trois, exactement comme pour le
    // texte. Une heure incrustée DANS l'image avait survécu à la refonte qui
    // l'avait sortie des bulles de texte ; ça ne doit plus se reproduire.
    final contenu = switch (message.contentType) {
      ContentType.separator => SeparatorPill(libelle: message.body ?? ''),
      // Jamais dans le fil : la narration est affichée en plein écran, plus
      // haut. Elle ne laisse aucune trace une fois Léna revenue — c'est un
      // moment, pas un message qu'on relit en remontant.
      ContentType.narration => const SizedBox.shrink(),
      // Même principe que la narration : la vidéo de transition est affichée
      // en plein écran, plus haut, et ne laisse aucune trace dans le fil.
      ContentType.video => const SizedBox.shrink(),
      // Un `system` n'est jamais une bulle : il a déjà changé la présence.
      ContentType.system => const SizedBox.shrink(),
      ContentType.image => PhotoBubble(
          message: message,
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
      ContentType.text => MessageBubble(message: message),
    };

    if (!estBulle(message.contentType)) return contenu;

    return Padding(
      padding: EdgeInsets.only(
          bottom: finDeGroupe ? AppSpacing.interGroupes : AppSpacing.interBulles),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          contenu,
          // Heure, nom, « Vu. » et coche : sous le DERNIER élément du groupe
          // seulement, quel que soit son type.
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
    );
  }
}
