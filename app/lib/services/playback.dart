import 'dart:async';

import '../models/client_message.dart';

/// Ce que le typing indicator est en train de faire.
enum TypingState {
  /// Rien.
  aucun,

  /// Léna écrit — un message va arriver.
  reel,

  /// Faux typing : il s'éteindra **sans qu'aucun message n'arrive**.
  /// Voir docs/LOGIQUE.md § Mise en scène d'une attente.
  fantome,
}

/// Un battement à jouer pendant une attente, à un offset donné.
class _Battement {
  const _Battement(this.offset, this.action);
  final int offset; // secondes depuis le début du délai du message
  final void Function() action;
}

/// Moteur de déroulé temporel.
///
/// `advance` renvoie des messages avec leurs délais ; c'est le client qui les
/// joue. Ce moteur est la seule pièce qui manipule le temps, et il ne touche ni
/// au réseau ni à l'UI : il expose un état, et prévient quand il change.
///
/// Pendant un déroulé, les choix ne sont pas proposés — c'est l'appelant qui
/// s'en assure en lisant [enCours].
class PlaybackEngine {
  PlaybackEngine({
    required this.onMessage,
    required this.onChangement,
    this.onVibration,
    this.duree = _attenteReelle,
  });

  /// Un message vient d'être délivré : à ajouter au fil.
  final void Function(ClientMessage) onMessage;

  /// L'état visible a changé (typing, présence, déroulé en cours).
  final void Function() onChangement;

  /// Vibration discrète, sans notification.
  final void Function()? onVibration;

  /// Indirection pour les tests : permet de piloter le temps.
  final Future<void> Function(Duration) duree;

  static Future<void> _attenteReelle(Duration d) => Future<void>.delayed(d);

  /// Durée du faux typing. Constante du client, pas une donnée de contenu.
  static const Duration dureeTypingFantome = Duration(seconds: 2);

  /// Rafale de typing intermittent, au-delà du seuil de contenu (>= 15 s).
  static const Duration _rafaleVisible = Duration(seconds: 5);
  static const Duration _rafaleMasquee = Duration(seconds: 3);

  TypingState _typing = TypingState.aucun;
  TypingState get typing => _typing;

  bool _enCours = false;

  /// Un déroulé est en cours : la zone de choix reste masquée.
  bool get enCours => _enCours;

  /// Libellé de présence courant, tel que le serveur l'a envoyé
  /// (« Léna est hors ligne »). Le client n'en invente jamais.
  String? _presence;
  String? get presence => _presence;

  /// Messages pas encore délivrés — ce qui doit survivre à une fermeture d'app.
  final List<ClientMessage> _restants = [];
  List<ClientMessage> get restants => List.unmodifiable(_restants);

  int _generation = 0;
  Completer<void>? _fin;

  /// Déroule une salve. Un nouvel appel annule le déroulé en cours.
  Future<void> jouer(List<ClientMessage> messages) async {
    _restants
      ..clear()
      ..addAll(messages);
    final generation = ++_generation;
    _fin = Completer<void>();
    _enCours = _restants.isNotEmpty;
    onChangement();

    while (_restants.isNotEmpty) {
      final message = _restants.first;
      await _attendre(message, generation);
      if (generation != _generation) return; // annulé ou sauté
      _restants.removeAt(0);
      _delivrer(message);
    }

    _enCours = false;
    _typing = TypingState.aucun;
    onChangement();
    _fin?.complete();
  }

  /// Attente d'un message, avec ses battements de mise en scène.
  Future<void> _attendre(ClientMessage m, int generation) async {
    final total = m.delaySeconds;
    if (total <= 0) return;

    // Le typing réel occupe la FIN de l'attente : il annonce le message.
    final debutTyping = (total - m.typingSeconds).clamp(0, total);

    final battements = <_Battement>[
      if (m.phantomTypingAt != null && m.typingSeconds == 0)
        _Battement(m.phantomTypingAt!, () => _poserTyping(TypingState.fantome)),
      if (m.phantomTypingAt != null && m.typingSeconds == 0)
        _Battement(m.phantomTypingAt! + dureeTypingFantome.inSeconds,
            () => _poserTyping(TypingState.aucun)),
      if (m.hapticAt != null) _Battement(m.hapticAt!, () => onVibration?.call()),
      if (m.typingSeconds > 0) _Battement(debutTyping, () => _lancerTypingReel(m, generation)),
    ]..sort((a, b) => a.offset.compareTo(b.offset));

    var ecoule = 0;
    for (final b in battements) {
      if (b.offset > total) continue;
      if (b.offset > ecoule) {
        await duree(Duration(seconds: b.offset - ecoule));
        if (generation != _generation) return;
        ecoule = b.offset;
      }
      b.action();
    }
    if (ecoule < total) {
      await duree(Duration(seconds: total - ecoule));
    }
  }

  /// Typing réel. Au-delà du seuil de contenu, il se joue en rafales : c'est la
  /// marque d'une hésitation visible (N2, N13), pas un simple long délai.
  void _lancerTypingReel(ClientMessage m, int generation) {
    if (!m.hasIntermittentTyping) {
      _poserTyping(TypingState.reel);
      return;
    }
    unawaited(_rafales(m.typingSeconds, generation));
  }

  Future<void> _rafales(int secondes, int generation) async {
    var restant = secondes;
    var visible = true;
    while (restant > 0 && generation == _generation) {
      _poserTyping(visible ? TypingState.reel : TypingState.aucun);
      final pas = visible ? _rafaleVisible : _rafaleMasquee;
      final aAttendre = pas.inSeconds > restant ? restant : pas.inSeconds;
      await duree(Duration(seconds: aAttendre));
      restant -= aAttendre;
      visible = !visible;
    }
    if (generation == _generation) _poserTyping(TypingState.reel);
  }

  void _poserTyping(TypingState etat) {
    if (_typing == etat) return;
    _typing = etat;
    onChangement();
  }

  void _delivrer(ClientMessage m) {
    _typing = TypingState.aucun;
    // Un message `system` n'est pas une bulle : c'est un changement de présence,
    // sauf en fin de chapitre où l'appelant le sort du fil.
    if (m.contentType == ContentType.system) {
      _presence = m.body;
    } else if (m.sender == MessageSender.contact) {
      // Le retour « en ligne » n'est jamais annoncé par le serveur : on le
      // déduit de l'arrivée d'un message.
      _presence = null;
    }
    onMessage(m);
    onChangement();
  }

  /// Bouton de développement : délivre tout ce qui reste, sans attendre.
  void sauter() {
    _generation++;
    final restants = List<ClientMessage>.from(_restants);
    _restants.clear();
    for (final m in restants) {
      _delivrer(m);
    }
    _enCours = false;
    _typing = TypingState.aucun;
    onChangement();
    _fin?.complete();
  }

  /// Interrompt sans rien délivrer. Ce qui restait est dans [restants], à
  /// persister pour reprendre proprement après une fermeture d'app.
  void interrompre() {
    _generation++;
    _enCours = false;
    _typing = TypingState.aucun;
    onChangement();
    if (_fin?.isCompleted == false) _fin?.complete();
  }
}
