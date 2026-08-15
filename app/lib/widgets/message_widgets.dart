import 'package:flutter/material.dart';

import '../config/env.dart';
import '../models/client_message.dart';
import '../theme/tokens.dart';

/// Bulle de message. Reçue à gauche, envoyée à droite.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.heure});

  final ClientMessage message;

  /// Heure **de fiction** (« 23h31 »). Jamais l'horloge système.
  final String? heure;

  bool get _duJoueur => message.sender == MessageSender.player;

  @override
  Widget build(BuildContext context) {
    final largeurMax = MediaQuery.sizeOf(context).width * AppSpacing.largeurMaxBulle;

    return Align(
      alignment: _duJoueur ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: largeurMax),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.interBulles / 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s + 2),
        decoration: BoxDecoration(
          color: _duJoueur
              // Non délivré : même bulle, atténuée. Rien d'autre ne le signale.
              ? (message.isLocalDecorative
                  ? AppColors.bulleJoueurNonDelivre
                  : AppColors.bulleJoueur)
              : AppColors.bulleContact,
          borderRadius: BorderRadius.circular(AppSpacing.rayonBulle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.body ?? '',
              style: AppText.corpsMessage.copyWith(
                color: _duJoueur ? AppColors.texteJoueur : AppColors.texteContact,
              ),
            ),
            if (heure != null || message.isLocalDecorative)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (heure != null)
                      Text(
                        heure!,
                        style: AppText.horodatage.copyWith(
                          color: _duJoueur
                              ? AppColors.texteJoueur.withValues(alpha: 0.55)
                              : AppColors.texteTertiaire,
                        ),
                      ),
                    if (message.isLocalDecorative) ...[
                      const SizedBox(width: AppSpacing.xs),
                      // Une seule coche : envoyé, jamais délivré. Il ne passera
                      // pas — et rien ne doit le dire au joueur.
                      Icon(Icons.check,
                          size: 13, color: AppColors.texteJoueur.withValues(alpha: 0.45)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ellipse narrative. Le libellé vient du serveur et s'affiche **tel quel**.
class SeparatorPill extends StatelessWidget {
  const SeparatorPill({super.key, required this.libelle});
  final String libelle;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.l),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: AppColors.separateurFond,
            borderRadius: BorderRadius.circular(AppSpacing.m),
          ),
          child: Text(libelle,
              style: AppText.separateur.copyWith(color: AppColors.separateurTexte)),
        ),
      );
}

/// Média pas encore produit (`placeholder://…`).
///
/// Neutre et jamais alarmant : le joueur ne doit pas croire à une panne réseau.
/// Reste **tapable** — le zoom est une mécanique de jeu, pas un confort.
class MediaPlaceholder extends StatelessWidget {
  const MediaPlaceholder({super.key, required this.type, this.hauteur = 180});
  final ContentType type;
  final double hauteur;

  @override
  Widget build(BuildContext context) => Container(
        height: hauteur,
        decoration: BoxDecoration(
          color: AppColors.mediaAbsentFond,
          border: Border.all(color: AppColors.mediaAbsentBord),
          borderRadius: BorderRadius.circular(AppSpacing.m),
        ),
        child: Center(
          child: Icon(
            type == ContentType.audio ? Icons.graphic_eq : Icons.photo_outlined,
            color: AppColors.texteTertiaire,
            size: 28,
          ),
        ),
      );
}

/// Photo du fil. Le tap ouvre la visionneuse zoomable.
class PhotoBubble extends StatelessWidget {
  const PhotoBubble({super.key, required this.message, required this.onOuvrir});
  final ClientMessage message;
  final VoidCallback onOuvrir;

  @override
  Widget build(BuildContext context) {
    final largeurMax = MediaQuery.sizeOf(context).width * AppSpacing.largeurMaxBulle;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l, vertical: AppSpacing.interBulles / 2),
        child: GestureDetector(
          onTap: onOuvrir,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.rayonBulle),
            child: SizedBox(
              width: largeurMax,
              child: message.isPlaceholderMedia
                  ? const MediaPlaceholder(type: ContentType.image)
                  : Image.network(
                      message.urlAbsolue(Env.supabaseUrl)!,
                      fit: BoxFit.cover,
                      // Un média illisible ne casse pas le fil : on retombe sur
                      // le cartouche, comme pour un placeholder.
                      errorBuilder: (_, _, _) =>
                          const MediaPlaceholder(type: ContentType.image),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visionneuse plein écran. Le zoom lui-même est la mécanique cachée : c'est
/// le geste, pas un bouton, qui déclenche l'interaction.
class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.message, this.onZoom});
  final ClientMessage message;

  /// Appelé au premier zoom réel (pas au simple affichage).
  final VoidCallback? onZoom;

  @override
  Widget build(BuildContext context) {
    final controleur = TransformationController();
    var signale = false;
    controleur.addListener(() {
      if (signale) return;
      if (controleur.value.getMaxScaleOnAxis() > 1.15) {
        signale = true;
        onZoom?.call();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          transformationController: controleur,
          minScale: 1,
          maxScale: 5,
          child: message.isPlaceholderMedia
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: MediaPlaceholder(type: ContentType.image, hauteur: 320),
                )
              : Image.network(
                  message.urlAbsolue(Env.supabaseUrl)!,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: MediaPlaceholder(type: ContentType.image, hauteur: 320),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Lecteur de note vocale.
///
/// Les médias réels n'existent pas encore : la lecture est simulée, mais le
/// signal de **réécoute** est réel — c'est lui qui portera l'interaction cachée
/// du N17. À remplacer par un vrai lecteur quand les fichiers arriveront.
class AudioBubble extends StatefulWidget {
  const AudioBubble({super.key, required this.message, this.onReecoute});
  final ClientMessage message;

  /// Appelé à partir de la DEUXIÈME lecture.
  final VoidCallback? onReecoute;

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  int _lectures = 0;
  bool _enLecture = false;

  Future<void> _lire() async {
    setState(() {
      _enLecture = true;
      _lectures++;
    });
    if (_lectures >= 2) widget.onReecoute?.call();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _enLecture = false);
  }

  @override
  Widget build(BuildContext context) {
    final largeurMax = MediaQuery.sizeOf(context).width * AppSpacing.largeurMaxBulle;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: largeurMax,
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l, vertical: AppSpacing.interBulles / 2),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.m),
        decoration: BoxDecoration(
          color: AppColors.bulleContact,
          borderRadius: BorderRadius.circular(AppSpacing.rayonBulle),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _lire,
              child: Icon(
                _enLecture ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.texteContact,
                size: 30,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: AppColors.texteTertiaire,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trois points. Aucune différence visuelle entre un typing réel et un faux :
/// c'est tout l'intérêt du second.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.l, vertical: AppSpacing.interBulles),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
          decoration: BoxDecoration(
            color: AppColors.bulleContact,
            borderRadius: BorderRadius.circular(AppSpacing.rayonBulle),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
                final opacite = 0.3 + 0.7 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.texteSecondaire.withValues(alpha: opacite),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      );
}
