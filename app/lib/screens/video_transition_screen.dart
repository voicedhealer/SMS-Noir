import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../config/env.dart';
import '../models/client_message.dart';
import '../services/musique_narrative.dart';

/// Transition vidéo plein écran — Léna rentre chez elle (addendum transition
/// N20-N9 §2).
///
/// Même famille que [NarrationScreen] : le client quitte le fil et bascule en
/// plein écran tant que le message suivant n'est pas arrivé. La différence est
/// le fond — une vidéo plutôt qu'un noir pur — et l'absence totale de texte à
/// superposer : « Léna rentre chez elle. » est incrusté DANS le fichier, rien
/// à synchroniser côté client, contrairement aux lignes du N19.
///
/// **Aucune sortie, aucun bouton, aucun champ de saisie.** Même principe que
/// l'écran noir : ce n'est pas un menu, c'est un sas.
class VideoTransitionScreen extends StatefulWidget {
  const VideoTransitionScreen({super.key, required this.message});

  final ClientMessage message;

  @override
  State<VideoTransitionScreen> createState() => _VideoTransitionScreenState();
}

class _VideoTransitionScreenState extends State<VideoTransitionScreen> {
  VideoPlayerController? _controleur;

  @override
  void initState() {
    super.initState();
    // Musique en silence (décision de Vivien) : aucun segment n'est déclenché
    // ici, donc rien ne joue par construction. On coupe quand même par
    // prudence, même paranoïa que `reinitialiser()` — un écran précédent qui
    // aurait laissé quelque chose tourner ne doit pas se superposer.
    unawaited(MusiqueNarrative.instance.arreter());

    // `isPlaceholderMedia` d'abord : `Env.supabaseUrl` lève si aucune base
    // n'est configurée, et l'argument d'un appel s'évalue avant d'entrer dans
    // `urlAbsolue` — voir le même garde dans AudioBubble.
    if (widget.message.isPlaceholderMedia) return;
    final url = widget.message.urlAbsolue(Env.supabaseUrl);
    if (url == null) return;

    final controleur = VideoPlayerController.networkUrl(Uri.parse(url));
    _controleur = controleur;
    unawaited(controleur.initialize().then((_) {
      if (!mounted) return;
      // Le fichier est déjà muet à la source (audio retiré au traitement) ;
      // couper le volume aussi côté lecteur ne coûte rien et n'en dépend pas.
      unawaited(controleur.setVolume(0));
      unawaited(controleur.setLooping(false));
      unawaited(controleur.play());
      setState(() {});
    }));
  }

  @override
  void dispose() {
    _controleur?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controleur = _controleur;
    return Scaffold(
      backgroundColor: Colors.black,
      // Pas encore prête (ou pas encore téléversée) : fond noir, jamais une
      // erreur visible — même principe que MediaPlaceholder pour les autres
      // médias.
      // `contain`, pas `cover`. Le carton « Léna rentre chez elle. » est
      // incrusté dans le fichier, en 1080×1920 : sur un écran plus étroit que
      // du 9:16 — le Galaxy S23 Ultra fait 1440×3088 — `cover` remplit la
      // hauteur et rogne 297 px de large, soit ~8 % de chaque côté. Assez pour
      // couper le « L » et le « e » du carton, constaté en jouant par Vivien.
      //
      // Le cadre entier est donc préservé, quitte à border de noir : le fond
      // de l'écran EST noir, et la vidéo a des bords sombres, donc la bande se
      // lit comme un cadrage de cinéma, pas comme un défaut. C'est aussi le
      // seul choix qui tienne sur tous les formats d'écran — `cover` rogne
      // d'une quantité qui dépend de l'appareil.
      body: (controleur != null && controleur.value.isInitialized)
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controleur.value.size.width,
                  height: controleur.value.size.height,
                  child: VideoPlayer(controleur),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
