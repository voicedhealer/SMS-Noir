import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/env.dart';
import '../services/musique_narrative.dart';
import '../theme/tokens.dart';
import '../widgets/typewriter.dart';

/// Écran noir narratif — les bascules du chapitre.
///
/// Deux fois dans le chapitre 1, l'app quitte la conversation et bascule en
/// plein écran : le trajet vers l'entrepôt (N14) et les 60 s où Léna ne répond
/// plus (N19). Ce sont les seuls moments où le joueur cesse d'être dans une
/// messagerie : il n'a plus rien à faire, et c'est le sujet.
///
/// **Chaque écran a SA musique**, portée par le `media_url` de son message —
/// pas un segment d'histoire partagé. Le N14 ouvre sur une amorce « danger »,
/// froide et retenue ; le N19 la reprend, plus forte.
///
/// **Aucune sortie, aucun bouton, aucun champ de saisie.** L'impuissance est la
/// scène — un champ actif sur un écran noir sans fil visible ne ressemblerait à
/// rien de réel, et laisserait croire qu'une action est possible.
///
/// Au N19, la dernière ligne est **volontairement inachevée**. Elle est coupée
/// par le retour de Léna. Ne jamais la compléter, ne jamais la faire
/// disparaître proprement : la coupure est l'effet. Au N14 elle est entière —
/// « Allez-vous soutenir cette inconnue ? » est rhétorique, aucune réponse
/// n'est attendue — mais sa dernière lettre tombe tout aussi juste : le
/// générateur cale son décalage sur le délai du message qui referme l'écran.
class NarrationScreen extends StatefulWidget {
  const NarrationScreen({super.key, required this.lignes, this.musique});

  /// `[{"texte": …, "a": secondes}]`, tel que le contenu le pose en base.
  final List<({String texte, int a})> lignes;

  /// Chemin signé RELATIF du segment de cet écran, ou `null` si le fichier
  /// n'est pas encore livré — l'écran se joue alors en silence plutôt que de
  /// bloquer l'histoire.
  ///
  /// Coupé **net** à la fermeture de l'écran, jamais en fondu : c'est la règle
  /// de tous les segments, et ici la coupure est l'effet.
  final String? musique;

  /// Décode le `body` d'un message `narration`.
  ///
  /// Le body ne porte QUE les lignes : la musique de l'écran est son
  /// `media_url`, signé comme n'importe quel média.
  ///
  /// Un contenu illisible ne doit pas noircir l'écran indéfiniment : on renvoie
  /// une liste vide, l'appelant n'affiche rien, et l'histoire continue.
  static List<({String texte, int a})> decoder(String? body) {
    if (body == null) return const [];
    try {
      final brut = jsonDecode(body);
      if (brut is! List) return const [];
      return [
        for (final l in brut)
          if (l is Map && l['texte'] is String)
            (texte: l['texte'] as String, a: (l['a'] as num?)?.toInt() ?? 0),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  State<NarrationScreen> createState() => _NarrationScreenState();
}

class _NarrationScreenState extends State<NarrationScreen> {
  final _timers = <Timer>[];
  var _visibles = 0;

  @override
  void initState() {
    super.initState();
    final url = widget.musique;
    // Le serveur renvoie un chemin RELATIF signé, comme pour les photos et
    // l'intro : c'est le client qui préfixe avec sa propre base. Oublié ici,
    // le lecteur recevait un chemin sans hôte et échouait en silence — aucune
    // erreur visible, juste aucun son.
    //
    // `null` = fichier pas encore livré : l'écran se joue en silence plutôt
    // que d'empêcher l'histoire d'avancer.
    if (url != null) {
      unawaited(MusiqueNarrative.instance.demarrer('${Env.supabaseUrl}$url'));
    }
    for (var i = 0; i < widget.lignes.length; i++) {
      final ligne = widget.lignes[i];
      if (ligne.a == 0) {
        _visibles = i + 1;
        continue;
      }
      _timers.add(Timer(Duration(seconds: ligne.a), () {
        if (mounted) setState(() => _visibles = i + 1);
      }));
    }
  }

  @override
  void dispose() {
    // Coupure nette, et explicite : compter sur la destruction du lecteur
    // laisserait la musique traîner sur la conversation. Déjà constaté avec la
    // musique d'intro.
    unawaited(MusiqueNarrative.instance.arreter());
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.lignes.length; i++)
                if (i < _visibles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child: Typewriter(
                      // Une clé par ligne : sans elle, Flutter réutiliserait
                      // l'état de la précédente et la ligne suivante
                      // apparaîtrait déjà écrite.
                      key: ValueKey(i),
                      texte: widget.lignes[i].texte,
                      style: AppText.corpsMessage.copyWith(
                        color: AppColors.texteSecondaire,
                        height: 1.6,
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
