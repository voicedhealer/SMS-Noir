import 'dart:async';

import 'package:flutter/material.dart';

/// Texte qui s'écrit caractère par caractère.
///
/// **Uniquement sur les écrans narratifs** — l'écran noir du N19 et l'écran de
/// fin de chapitre. Jamais dans une bulle de conversation : une messagerie
/// n'écrit pas devant vous, elle livre.
///
/// Deux règles d'accessibilité, et ce ne sont pas des options :
///
///  • si le système demande de **réduire les animations**, le texte s'affiche
///    d'un coup. Quelqu'un qui a activé ce réglage a une raison, et un texte
///    qui se déroule lentement peut être pénible à lire, voire déclencher des
///    symptômes ;
///  • un **tap affiche la ligne en cours en entier**, sans accélérer la suite
///    ni sauter les lignes suivantes. Le joueur reprend la main sur SA lecture,
///    pas sur le rythme de la scène.
class Typewriter extends StatefulWidget {
  const Typewriter({
    super.key,
    required this.texte,
    this.style,
    this.parCaractere = const Duration(milliseconds: 45),
    this.surPause = const Duration(milliseconds: 400),
    this.onFini,
  });

  final String texte;
  final TextStyle? style;

  /// ~45 ms : le rythme d'une frappe posée, pas d'un télétype.
  final Duration parCaractere;

  /// Les points de suspension retiennent le souffle. C'est le seul endroit où
  /// la ponctuation change la vitesse — ailleurs elle sonnerait mécanique.
  final Duration surPause;

  final VoidCallback? onFini;

  @override
  State<Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<Typewriter> {
  Timer? _timer;
  var _ecrits = 0;
  var _fini = false;

  @override
  void initState() {
    super.initState();
    // Le réglage système n'est lisible qu'une fois le contexte monté.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _tout();
      } else {
        _suivant();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _suivant() {
    if (!mounted || _ecrits >= widget.texte.length) return _terminer();
    // Une pause plus longue après « … » : le texte respire là où il hésite.
    final avant = widget.texte.substring(0, _ecrits);
    final attente = avant.endsWith('...') || avant.endsWith('…')
        ? widget.surPause
        : widget.parCaractere;
    _timer = Timer(attente, () {
      if (!mounted) return;
      setState(() => _ecrits++);
      _suivant();
    });
  }

  void _tout() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _ecrits = widget.texte.length);
    _terminer();
  }

  void _terminer() {
    if (_fini) return;
    _fini = true;
    widget.onFini?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Comportement : la ligne en cours se complète. La séquence, elle, garde
      // son rythme — sinon un tap impatient escamoterait toute la scène.
      onTap: _tout,
      behavior: HitTestBehavior.opaque,
      child: Text(widget.texte.substring(0, _ecrits), style: widget.style),
    );
  }
}
