import 'package:flutter/material.dart';

import '../services/indicateur_sonore.dart';
import '../theme/tokens.dart';

/// Icône haut-parleur discrète, posée près de la zone de statut système,
/// visible **uniquement** tant qu'un son narratif joue (voir
/// [IndicateurSonore]) — jamais pour les bips de message ni le typing.
/// Tapable : coupe tout net, sans passer par les Réglages du téléphone.
///
/// Monté une seule fois, au-dessus de tout le reste — voir `main.dart`,
/// `MaterialApp.builder`. Un écran noir narratif ou une note vocale n'ont pas
/// de zone de statut commune ; ancrer l'icône à ce niveau évite de la
/// dupliquer dans chaque écran qui peut faire du bruit.
class SoundIndicatorOverlay extends StatelessWidget {
  const SoundIndicatorOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: IndicateurSonore.instance.enCours,
      builder: (context, enCours, _) {
        // Absente, pas seulement invisible : rien à tapoter par erreur quand
        // aucun son ne joue.
        if (!enCours) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topRight,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs, right: AppSpacing.l),
              child: _PulsingSpeaker(onTap: IndicateurSonore.instance.couperTout),
            ),
          ),
        );
      },
    );
  }
}

class _PulsingSpeaker extends StatefulWidget {
  const _PulsingSpeaker({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PulsingSpeaker> createState() => _PulsingSpeakerState();
}

class _PulsingSpeakerState extends State<_PulsingSpeaker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Opacity(
            // Pulsation légère : jamais totalement éteinte, l'icône reste
            // lisible en continu — c'est une présence, pas un clignotement.
            opacity: 0.55 + 0.45 * _ctrl.value,
            child: child,
          ),
          child: const Icon(Icons.volume_up_rounded, size: 16, color: AppColors.texteSecondaire),
        ),
      ),
    );
  }
}
