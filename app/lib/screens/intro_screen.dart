import 'dart:async';

import 'package:flutter/material.dart';

import '../config/env.dart';
import '../models/game_state.dart';
import '../services/intro_music.dart';
import '../theme/tokens.dart';

/// Séquence d'intronisation.
///
/// Jouée **une seule fois**, à la toute première ouverture. Aucun bouton, aucun
/// skip visible : elle dure une dizaine de secondes et ne mérite pas d'être
/// passée. Aucune mention de jeu, de chapitre ou de mécanique — le joueur
/// comprend par l'usage.
///
/// Le texte vient du serveur (`stories.intro_panels`) : c'est du contenu
/// narratif, pas de l'interface. Timings exacts dans DESIGN.md.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.intro, required this.onTermine});

  final IntroSequence intro;
  final VoidCallback onTermine;

  // Timings de mise en scène — constantes du client, pas du contenu.
  static const fondu = Duration(milliseconds: 800);
  static const lecture = Duration(seconds: 2);

  /// Le dernier panneau reste seul un peu plus longtemps : c'est le basculement.
  static const lectureFinale = Duration(milliseconds: 2500);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  int _index = 0;
  bool _visible = false;
  bool _fini = false;

  @override
  void initState() {
    super.initState();
    final musique = widget.intro.musicUrl;
    if (musique != null) {
      unawaited(IntroMusic.instance.demarrer('${Env.supabaseUrl}$musique'));
    }
    unawaited(_derouler());
  }

  @override
  void dispose() {
    // Filet de sécurité seulement : l'arrêt réel se fait dans _terminer(), au
    // moment précis de la bascule. Compter sur dispose() reviendrait à confier
    // la coupure à l'ordre de destruction de l'arbre.
    unawaited(IntroMusic.instance.arreter());
    super.dispose();
  }

  /// Fin de la séquence : on coupe la musique **puis** on rend la main.
  void _terminer() {
    if (_fini) return;
    _fini = true;
    unawaited(IntroMusic.instance.arreter());
    widget.onTermine();
  }

  Future<void> _derouler() async {
    for (var i = 0; i < widget.intro.panels.length; i++) {
      if (!mounted) return;
      setState(() {
        _index = i;
        _visible = true;
      });

      final dernier = i == widget.intro.panels.length - 1;
      await Future<void>.delayed(
          IntroScreen.fondu + (dernier ? IntroScreen.lectureFinale : IntroScreen.lecture));
      if (!mounted) return;

      setState(() => _visible = false);
      await Future<void>.delayed(IntroScreen.fondu);
    }
    if (!mounted) return;
    _terminer();
  }

  /// Skip de développement : un tap n'importe où. Absent en release.
  void _sauter() {
    if (!Env.outilsDebug) return;
    _terminer();
  }

  @override
  Widget build(BuildContext context) {
    final panneau = widget.intro.panels.isEmpty
        ? const <String>[]
        : widget.intro.panels[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _sauter,
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: IntroScreen.fondu,
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final ligne in panneau)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                      child: Text(
                        ligne,
                        textAlign: TextAlign.center,
                        style: AppText.titreFinChapitre.copyWith(
                          color: AppColors.textePrincipal,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
