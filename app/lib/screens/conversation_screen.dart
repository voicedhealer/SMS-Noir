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
        data: (etat) => Column(
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
                    return _Element(message: etat.fil[i], etat: etat);
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
            Composer(mode: etat.mode, onEnvoyer: ctrl.envoyerTexte),
          ],
        ),
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
    return AppBar(
      titleSpacing: AppSpacing.l,
      title: Column(
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
            Text(etat!.sousTitre,
                style: AppText.sousTitrePresence.copyWith(color: AppColors.texteSecondaire)),
        ],
      ),
    );
  }
}

class _Element extends ConsumerWidget {
  const _Element({required this.message, required this.etat});
  final ClientMessage message;
  final ConversationState etat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = etat.heures[message.seq];
    final heure = minutes == null ? null : FictionClock.formater(minutes);

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
      ContentType.text => MessageBubble(message: message, heure: heure),
    };
  }
}
