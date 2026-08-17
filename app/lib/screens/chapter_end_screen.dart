import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../theme/tokens.dart';

/// Écran de fin de chapitre.
///
/// Sort du fil, plein écran. Le texte est celui du message `system` du nœud
/// `chapter_end` — il n'est jamais rendu comme une bulle.
class ChapterEndScreen extends StatefulWidget {
  const ChapterEndScreen({
    super.key,
    required this.fin,
    required this.texte,
    required this.onFermer,
  });

  final ChapterEnd fin;

  /// Le message `system` du N22.
  final String texte;
  final VoidCallback onFermer;

  @override
  State<ChapterEndScreen> createState() => _ChapterEndScreenState();
}

class _ChapterEndScreenState extends State<ChapterEndScreen> {
  Timer? _tic;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Le compte à rebours est du TEMPS RÉEL — la seule exception à la règle du
    // temps de fiction. C'est une attente réelle, pas une heure d'histoire.
    _tic = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  String get _restant {
    final cible = widget.fin.unlockedAt;
    if (cible == null) return '';
    final d = cible.difference(DateTime.now());
    if (d.isNegative) return 'maintenant';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final suivant = widget.fin.nextChapterTitle;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.texte,
                    style: AppText.titreFinChapitre.copyWith(color: AppColors.textePrincipal)),
                const SizedBox(height: AppSpacing.xxl * 2),
                if (suivant != null) ...[
                  Text(
                    suivant.toUpperCase(),
                    style: AppText.separateur.copyWith(
                      color: AppColors.texteSecondaire,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(_restant,
                      style: AppText.compteARebours.copyWith(color: AppColors.textePrincipal)),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    widget.fin.nextChapterPending
                        ? 'à venir'
                        : 'avant la suite',
                    style: AppText.horodatage.copyWith(color: AppColors.texteTertiaire),
                  ),
                ],
                const Spacer(),
                // Le déblocage immédiat (prompt 4) viendra ici.
                //
                // Rien n'est affiché en attendant, volontairement : un bouton
                // grisé se lit comme une panne, pas comme une promesse. Le
                // joueur ne peut pas savoir qu'une fonctionnalité n'existe pas
                // encore — il en déduit que l'app est cassée.
                const SizedBox(height: AppSpacing.l),
                Center(
                  child: TextButton(
                    onPressed: widget.onFermer,
                    child: Text('Revenir aux messages',
                        style:
                            AppText.libelleChoix.copyWith(color: AppColors.texteSecondaire)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
