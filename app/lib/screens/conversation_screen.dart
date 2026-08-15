import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
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

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scroll = ScrollController();

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
      floatingActionButton: (Env.outilsDebug && !kReleaseMode &&
              (async.value?.enDeroule ?? false))
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
          onOuvrir: () {
            ref.read(conversationProvider.notifier).signalerActivite();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PhotoViewer(message: message),
              fullscreenDialog: true,
            ));
          },
        ),
      ContentType.audio => AudioBubble(message: message),
      ContentType.text => MessageBubble(message: message, heure: heure),
    };
  }
}
