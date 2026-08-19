import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';
import '../theme/tokens.dart';

/// Écran d'entrée — avant même l'intronisation, avant tout le reste.
///
/// La « pochette » de l'histoire : image de couverture, titre, accroche, et
/// le consentement IA posé une fois pour toutes, ici, avant que le joueur
/// n'entre. Spécifique à l'histoire (titre, accroche, image viennent tous du
/// serveur — `stories.title/tagline/cover_url`) pour resservir tel quel avec
/// les futures histoires de la bibliothèque, sans rien coder en dur.
///
/// Le bouton « Entrer » est **toujours actif**, coché ou non : la case ne le
/// bloque jamais, elle décide seulement de la valeur envoyée. Voir
/// `ConversationController.repondreConsentement`.
class EntryCardScreen extends StatefulWidget {
  const EntryCardScreen({
    super.key,
    required this.titre,
    this.accroche,
    this.coverUrl,
    required this.onEntrer,
  });

  final String titre;
  final String? accroche;

  /// Chemin signé relatif (voir `Env.supabaseUrl`) — null tant que l'histoire
  /// n'a pas encore d'image de couverture en base.
  final String? coverUrl;

  /// `true` = consentement accepté, `false` = refusé. Dans les deux cas,
  /// l'écran se referme et l'histoire continue.
  final void Function(bool consentementAccepte) onEntrer;

  @override
  State<EntryCardScreen> createState() => _EntryCardScreenState();
}

class _EntryCardScreenState extends State<EntryCardScreen>
    with SingleTickerProviderStateMixin {
  // Case non cochée par défaut (bible §9) : un consentement ne se présume pas.
  bool _consentement = false;

  late final AnimationController _image;
  late final Animation<double> _imageOpacite;
  late final Animation<double> _imageFlou;

  final _timers = <Timer>[];
  var _titreVisible = false;
  var _accrocheVisible = false;
  var _consentementVisible = false;
  var _boutonVisible = false;

  static const _dureeImage = Duration(milliseconds: 700);
  static const _decalageTexte = Duration(milliseconds: 130);

  bool _demarre = false;

  @override
  void initState() {
    super.initState();
    _image = AnimationController(vsync: this, duration: _dureeImage);
    _imageOpacite = CurvedAnimation(parent: _image, curve: Curves.easeOut);
    // Flou qui se dissipe : sigma élevé -> 0, impression de mise au point.
    _imageFlou = Tween<double>(begin: 14, end: 0)
        .animate(CurvedAnimation(parent: _image, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `MediaQuery.of` a besoin du contexte pleinement monté : pas disponible
    // dans `initState`. Gardé par `_demarre` pour ne jouer l'entrée qu'une
    // seule fois, même si `didChangeDependencies` est rappelé plus tard.
    if (_demarre) return;
    _demarre = true;

    // Lu une seule fois : c'est une entrée jouée une seule fois, pas un état
    // qui doit réagir si le réglage change en cours d'écran.
    final reduit = MediaQuery.of(context).disableAnimations;
    if (reduit) {
      // Tout apparaît directement, sans transition — réglage d'accessibilité.
      _image.value = 1;
      _titreVisible = true;
      _accrocheVisible = true;
      _consentementVisible = true;
      _boutonVisible = true;
      return;
    }

    unawaited(_image.forward());
    // Fondu séquentiel des éléments de texte, après l'image — une seule fois,
    // jamais en boucle. Même idiome que NarrationScreen/IntroScreen.
    var quand = _dureeImage;
    for (final poser in [
      () => setState(() => _titreVisible = true),
      () => setState(() => _accrocheVisible = true),
      () => setState(() => _consentementVisible = true),
      () => setState(() => _boutonVisible = true),
    ]) {
      _timers.add(Timer(quand, () {
        if (mounted) poser();
      }));
      quand += _decalageTexte;
    }
  }

  @override
  void dispose() {
    _image.dispose();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _ouvrirPolitique() async {
    final url = Env.politiqueConfidentialite;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hauteurEcran = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: AppColors.fond,
      body: Column(
        children: [
          SizedBox(
            height: hauteurEcran * 0.46,
            width: double.infinity,
            child: _Couverture(
              url: widget.coverUrl,
              opacite: _imageOpacite,
              flou: _imageFlou,
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.l),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.m),
                    // Icône de l'app, petite, centrée, à la jonction entre
                    // l'image et le texte.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset('assets/icon/icon.png', width: 56, height: 56),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    AnimatedOpacity(
                      opacity: _titreVisible ? 1 : 0,
                      duration: AppMotion.fonduNarration,
                      curve: Curves.easeOut,
                      child: Text(
                        widget.titre,
                        textAlign: TextAlign.center,
                        style: AppText.titreAccueil.copyWith(color: AppColors.textePrincipal),
                      ),
                    ),
                    if (widget.accroche case final texte?) ...[
                      const SizedBox(height: AppSpacing.m),
                      AnimatedOpacity(
                        opacity: _accrocheVisible ? 1 : 0,
                        duration: AppMotion.fonduNarration,
                        curve: Curves.easeOut,
                        child: Text(
                          texte,
                          textAlign: TextAlign.center,
                          style: AppText.accrocheAccueil.copyWith(
                              color: AppColors.texteSecondaire),
                        ),
                      ),
                    ],
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _consentementVisible ? 1 : 0,
                      duration: AppMotion.fonduNarration,
                      curve: Curves.easeOut,
                      child: _LigneConsentement(
                        coche: _consentement,
                        onBascule: () => setState(() => _consentement = !_consentement),
                        onOuvrirPolitique: _ouvrirPolitique,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    AnimatedOpacity(
                      opacity: _boutonVisible ? 1 : 0,
                      duration: AppMotion.fonduNarration,
                      curve: Curves.easeOut,
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          // Toujours actif : la case ne bloque jamais l'entrée,
                          // elle décide seulement de ce qui est envoyé.
                          onPressed: () => widget.onEntrer(_consentement),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.m),
                            ),
                          ),
                          child: Text(
                            'Entrer',
                            style: AppText.libelleChoix.copyWith(
                                color: Colors.black, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Image de couverture, plein cadre, dégradé transparent → noir sur le tiers
/// inférieur : les silhouettes se dissolvent dans le fond plutôt que de
/// s'arrêter net sur un bord. Calque indépendant — jamais fusionné avec le
/// texte posé par-dessus.
class _Couverture extends StatelessWidget {
  const _Couverture({required this.url, required this.opacite, required this.flou});

  final String? url;
  final Animation<double> opacite;
  final Animation<double> flou;

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();
    final absolue = '${Env.supabaseUrl}$url';

    return AnimatedBuilder(
      animation: opacite,
      builder: (context, _) => Opacity(
        opacity: opacite.value,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
              sigmaX: flou.value, sigmaY: flou.value, tileMode: TileMode.decal),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                absolue,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              // Dégradé en overlay, sur le tiers inférieur uniquement.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.transparent, Colors.black],
                    stops: [0, 0.62, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Case à cocher + texte de consentement IA, avec le lien vers la politique
/// de confidentialité en surbrillance soulignée. Gris nettement contrasté sur
/// fond noir uni — jamais plus sombre que `texteSecondaire` (bible §9).
class _LigneConsentement extends StatelessWidget {
  const _LigneConsentement({
    required this.coche,
    required this.onBascule,
    required this.onOuvrirPolitique,
  });

  final bool coche;
  final VoidCallback onBascule;
  final VoidCallback onOuvrirPolitique;

  @override
  Widget build(BuildContext context) {
    final lien = TapGestureRecognizer()..onTap = onOuvrirPolitique;
    return InkWell(
      onTap: onBascule,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              coche ? Icons.check_box : Icons.check_box_outline_blank,
              color: coche ? AppColors.bulleJoueur : AppColors.texteSecondaire,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: AppText.accrocheAccueil.copyWith(color: AppColors.texteSecondaire),
                  children: [
                    const TextSpan(
                      text: "J'accepte que certains de mes échanges soient traités par "
                          'une IA pour personnaliser l\'histoire. ',
                    ),
                    TextSpan(
                      text: 'Politique de confidentialité',
                      recognizer: lien,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        color: AppColors.texteSecondaire,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
