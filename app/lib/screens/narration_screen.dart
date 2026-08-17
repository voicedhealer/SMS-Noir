import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Écran noir narratif — le silence du N19.
///
/// Pendant les 60 s où Léna ne répond plus, l'app quitte la conversation et
/// bascule en plein écran. C'est la seule fois du chapitre où le joueur cesse
/// d'être dans une messagerie : il n'a plus rien à faire, et c'est le sujet.
///
/// **Aucune sortie, aucun bouton, aucun champ de saisie.** L'impuissance est la
/// scène — un champ actif sur un écran noir sans fil visible ne ressemblerait à
/// rien de réel, et laisserait croire qu'une action est possible.
///
/// La dernière ligne est **volontairement inachevée**. Elle est coupée par le
/// retour de Léna. Ne jamais la compléter, ne jamais la faire disparaître
/// proprement : la coupure est l'effet.
class NarrationScreen extends StatefulWidget {
  const NarrationScreen({super.key, required this.lignes});

  /// `[{"texte": …, "a": secondes}]`, tel que le contenu le pose en base.
  final List<({String texte, int a})> lignes;

  /// Décode le `body` d'un message `narration`.
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
                AnimatedOpacity(
                  opacity: i < _visibles ? 1 : 0,
                  duration: AppMotion.fonduNarration,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child: Text(
                      widget.lignes[i].texte,
                      style: AppText.corpsMessage.copyWith(
                        color: AppColors.texteSecondaire,
                        height: 1.6,
                      ),
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
