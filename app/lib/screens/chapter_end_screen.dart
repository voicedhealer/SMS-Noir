import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../services/duree_lisible.dart';
import '../services/notifications_locales.dart';
import '../theme/tokens.dart';
import '../widgets/typewriter.dart';
import '../services/musique_narrative.dart';
import '../config/env.dart';

/// Le nom de l'app, tel qu'affiché partout ailleurs (label système, icône) —
/// jamais le titre de l'histoire, qui est propre au chapitre 1. Une future
/// notification pour une autre histoire de la bibliothèque porterait le même
/// titre : c'est SMS Noir qui prévient, pas un chapitre en particulier.
const _nomApp = 'SMS Noir';

/// État de la démarche « Me prévenir », après le tap.
enum _EtatNotification {
  /// Pas encore tapé (ou pas encore su si déjà programmée depuis une
  /// session précédente : on démarre optimiste, `initState` corrige vite).
  initial,

  /// Permission accordée, rappel programmé.
  programmee,

  /// Permission refusée — jamais redemandée, jamais culpabilisant.
  refusee,
}

/// Écran de fin de chapitre.
///
/// Sort du fil, plein écran. Le texte est celui du message `system` du nœud
/// `chapter_end` — il n'est jamais rendu comme une bulle.
///
/// Refonte (prompt notifications + écran de fin) : plus de compte à rebours
/// en chiffres — le joueur programme un rappel plutôt que de regarder un
/// chiffre descendre. Voir docs/DESIGN.md § L'écran de fin de chapitre.
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
  bool _visible = false;

  /// Index de la dernière phrase autorisée à s'écrire. Les suivantes attendent.
  var _phraseEcrite = 0;
  late final _phrases = widget.phrases;

  var _etatNotification = _EtatNotification.initial;

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
    final url = widget.musique;
    // Même chemin relatif que l'intro et le N19 : préfixage obligatoire.
    if (url != null) {
      unawaited(MusiqueNarrative.instance.demarrer('${Env.supabaseUrl}$url'));
    }
    // Le joueur a pu déjà taper « Me prévenir » lors d'un passage précédent
    // sur cet écran (fermé puis l'app rouverte pendant l'attente) : on
    // reflète l'état réel plutôt que de reproposer le bouton à vide.
    unawaited(
      NotificationsLocales.instance.programmee.then((deja) {
        if (mounted && deja) {
          setState(() => _etatNotification = _EtatNotification.programmee);
        }
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  Future<void> _tapMePrevenir() async {
    final quand = widget.fin.unlockedAt;
    final corps = widget.fin.nextChapterNotificationText;
    // Rien à programmer avec un corps vide — mieux vaut un bouton inerte
    // qu'une notification muette. Ne devrait pas arriver une fois le
    // contenu du chapitre écrit ; reste défensif pour un chapitre en cours
    // d'écriture.
    if (quand == null || corps == null) return;

    final accordee = await NotificationsLocales.instance.programmer(
      quand: quand,
      titre: _nomApp,
      corps: corps,
    );
    if (!mounted) return;
    setState(() {
      _etatNotification = accordee
          ? _EtatNotification.programmee
          : _EtatNotification.refusee;
    });
  }

  void _bientotDisponible(String quoi) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$quoi — bientôt disponible.')));
  }

  @override
  Widget build(BuildContext context) {
    final suivant = widget.fin.nextChapterTitle;
    final position = widget.fin.nextChapterPosition;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Le cliffhanger tombe en TROIS temps, écrits l'un après
                    // l'autre. Les trois phrases d'un coup se lisent comme un
                    // paragraphe ; séparées, chacune a le temps d'atterrir — et
                    // la troisième (« …a désormais votre numéro ») n'existe que
                    // par le silence qui la précède.
                    for (var i = 0; i < _phrases.length; i++)
                      if (i <= _phraseEcrite)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.l),
                          child: Typewriter(
                            key: ValueKey(i),
                            texte: _phrases[i],
                            style: AppText.titreFinChapitre.copyWith(
                              color: AppColors.textePrincipal,
                            ),
                            onFini: () => _phraseSuivante(i),
                          ),
                        ),
                    // Rien de ce qui suit ne s'affiche avant que le cliffhanger
                    // soit posé : ni le teaser ni les actions ne doivent voler
                    // la fin.
                    if (_phraseEcrite >= _phrases.length) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      if (suivant != null && position != null) ...[
                        _Separateur(),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'CHAPITRE $position — ${suivant.toUpperCase()}',
                          style: AppText.separateur.copyWith(
                            color: AppColors.texteSecondaire,
                            letterSpacing: 2,
                          ),
                        ),
                        if (widget.fin.nextChapterTeaserText
                            case final teaser?) ...[
                          const SizedBox(height: AppSpacing.s),
                          Text(
                            teaser,
                            style: AppText.accrocheAccueil.copyWith(
                              color: AppColors.texteTertiaire,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        _BoutonMePrevenir(
                          etat: _etatNotification,
                          delaiMinutes:
                              widget.fin.nextChapterUnlockDelayMinutes,
                          onTap: _tapMePrevenir,
                          onFermer: widget.onFermer,
                        ),
                        const SizedBox(height: AppSpacing.m),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () =>
                                _bientotDisponible('Débloquer ce chapitre'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.l,
                              ),
                              side: const BorderSide(
                                color: AppColors.separateurLigne,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.m,
                                ),
                              ),
                            ),
                            child: Text(
                              'Débloquer ce chapitre',
                              style: AppText.libelleChoix.copyWith(
                                color: AppColors.textePrincipal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                _bientotDisponible('Toutes les offres'),
                            child: Text(
                              'Voir toutes les offres',
                              style: AppText.horodatage.copyWith(
                                color: AppColors.texteTertiaire,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                      Text(
                        'La suite de $_nomApp, prochainement.',
                        style: AppText.libelleChoix.copyWith(
                          color: AppColors.texteSecondaire,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        'Un retour, une note, une idée ? Écrivez-nous.',
                        style: AppText.horodatage.copyWith(
                          color: AppColors.texteTertiaire,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    Center(
                      child: TextButton(
                        onPressed: widget.onFermer,
                        child: Text(
                          'Revenir aux messages',
                          style: AppText.libelleChoix.copyWith(
                            color: AppColors.texteSecondaire,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne discrète entre le cliffhanger et le teaser — assez peu marquée pour
/// ne pas concurrencer le silence qui vient de tomber.
class _Separateur extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 32, height: 1, color: AppColors.separateurLigne);
}

/// Le bouton plein, le plus visible des trois actions — trois apparences
/// selon [_EtatNotification], jamais un état grisé qui se lirait comme une
/// panne : refusé reste un vrai bouton, avec un vrai texte.
class _BoutonMePrevenir extends StatelessWidget {
  const _BoutonMePrevenir({
    required this.etat,
    required this.delaiMinutes,
    required this.onTap,
    required this.onFermer,
  });

  final _EtatNotification etat;
  final int? delaiMinutes;
  final Future<void> Function() onTap;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    final (String texte, VoidCallback? onPressed) = switch (etat) {
      _EtatNotification.initial => (
        delaiMinutes != null
            ? 'Me prévenir dans ${dureeLisible(delaiMinutes!)}'
            : 'Me prévenir',
        () => unawaited(onTap()),
      ),
      _EtatNotification.programmee => ('Vous serez prévenu·e', null),
      _EtatNotification.refusee => (
        'Vous pourrez revenir consulter l\'histoire',
        onFermer,
      ),
    };

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.m),
          ),
        ),
        child: Text(
          texte,
          textAlign: TextAlign.center,
          style: AppText.libelleChoix.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
