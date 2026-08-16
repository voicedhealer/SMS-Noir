import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../config/env.dart';
import '../models/game_state.dart';
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

  /// Montée très courte : la musique doit être là dès le premier mot.
  static const fonduMusique = Duration(milliseconds: 500);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  int _index = 0;
  bool _visible = false;
  bool _fini = false;
  AudioPlayer? _lecteur;

  @override
  void initState() {
    super.initState();
    unawaited(_demarrerMusique());
    unawaited(_derouler());
  }

  @override
  void dispose() {
    // Coupure NETTE, pas de fondu descendant : le silence brutal qui suit fait
    // partie de l'effet. Les 4 secondes de vide doivent être totalement muettes.
    _lecteur?.stop();
    _lecteur?.dispose();
    super.dispose();
  }

  Future<void> _demarrerMusique() async {
    final chemin = widget.intro.musicUrl;
    if (chemin == null) return; // séquence muette : parfaitement valide
    try {
      final lecteur = AudioPlayer();
      _lecteur = lecteur;
      // Catégorie « ambient » : respecte le mode silencieux du téléphone et ne
      // coupe pas la musique que le joueur écoutait déjà.
      await lecteur.setAudioSource(AudioSource.uri(Uri.parse('${Env.supabaseUrl}$chemin')));
      await lecteur.setVolume(0);
      await lecteur.setLoopMode(LoopMode.off); // une seule lecture, jamais en boucle
      unawaited(lecteur.play());
      await _monterLeSon(lecteur);
    } catch (_) {
      // Une musique absente ou illisible ne doit jamais empêcher l'histoire de
      // commencer : on joue la séquence en silence.
      _lecteur = null;
    }
  }

  Future<void> _monterLeSon(AudioPlayer lecteur) async {
    const pas = 20;
    const cible = 0.45; // volume modéré : c'est une ambiance, pas une bande-son
    for (var i = 1; i <= pas && mounted; i++) {
      await Future<void>.delayed(IntroScreen.fonduMusique ~/ pas);
      await lecteur.setVolume(cible * i / pas);
    }
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
    if (!mounted || _fini) return;
    _fini = true;
    widget.onTermine();
  }

  /// Skip de développement : un tap n'importe où. Absent en release.
  void _sauter() {
    if (!Env.outilsDebug || _fini) return;
    _fini = true;
    widget.onTermine();
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
