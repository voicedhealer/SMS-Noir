import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../theme/tokens.dart';
import '../widgets/typewriter.dart';
import '../services/musique_narrative.dart';
import '../config/env.dart';

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
    this.musique,
  });

  /// Segment 3 du morceau : le seul qui joue jusqu'au bout et qui culmine.
  /// Les deux autres sont coupés net par un retour à la conversation.
  final String? musique;

  final ChapterEnd fin;

  /// Le message `system` du N22.
  final String texte;

  /// Les trois temps du cliffhanger. Le contenu arrive en une chaîne — on la
  /// découpe sur la ponctuation forte plutôt que d'imposer un format au seed :
  /// c'est de la mise en scène, pas du contenu.
  List<String> get phrases {
    final decoupe = RegExp(r'[^.!?]+[.!?]+')
        .allMatches(texte)
        .map((m) => m.group(0)!.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return decoupe.isEmpty ? [texte] : decoupe;
  }
  final VoidCallback onFermer;

  @override
  State<ChapterEndScreen> createState() => _ChapterEndScreenState();
}

class _ChapterEndScreenState extends State<ChapterEndScreen> {
  Timer? _tic;
  bool _visible = false;

  /// Index de la dernière phrase autorisée à s'écrire. Les suivantes attendent.
  var _phraseEcrite = 0;
  late final _phrases = widget.phrases;

  /// Un temps de silence entre deux phrases : c'est lui qui fait tomber la
  /// troisième. Sans pause, les trois se lisent comme un paragraphe.
  void _phraseSuivante(int i) {
    if (i != _phraseEcrite) return;
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _phraseEcrite = i + 1);
    });
  }

  @override
  void initState() {
    super.initState();
    // Le compte à rebours est du TEMPS RÉEL — la seule exception à la règle du
    // temps de fiction. C'est une attente réelle, pas une heure d'histoire.
    _tic = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    final url = widget.musique;
    // Même chemin relatif que l'intro et le N19 : préfixage obligatoire.
    if (url != null) {
      unawaited(MusiqueNarrative.instance.demarrer('${Env.supabaseUrl}$url'));
    }
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
                // Le cliffhanger tombe en TROIS temps, écrits l'un après
                // l'autre. Les trois phrases d'un coup se lisent comme un
                // paragraphe ; séparées, chacune a le temps d'atterrir — et la
                // troisième (« …a désormais votre numéro ») n'existe que par
                // le silence qui la précède.
                for (var i = 0; i < _phrases.length; i++)
                  if (i <= _phraseEcrite)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.l),
                      child: Typewriter(
                        key: ValueKey(i),
                        texte: _phrases[i],
                        style: AppText.titreFinChapitre
                            .copyWith(color: AppColors.textePrincipal),
                        onFini: () => _phraseSuivante(i),
                      ),
                    ),
                const SizedBox(height: AppSpacing.xxl),
                // Ne s'affiche qu'une fois le cliffhanger posé : le compte à
                // rebours ne doit pas voler la fin.
                if (_phraseEcrite >= _phrases.length) ...[
                  Text('La suite de Numéro Inconnu, prochainement.',
                      style: AppText.libelleChoix
                          .copyWith(color: AppColors.texteSecondaire)),
                  const SizedBox(height: AppSpacing.s),
                  Text('Un retour, une note, une idée ? Écrivez-nous.',
                      style: AppText.horodatage
                          .copyWith(color: AppColors.texteTertiaire)),
                  const SizedBox(height: AppSpacing.xxl),
                ],
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
