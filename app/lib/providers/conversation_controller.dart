import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/client_message.dart';
import '../models/game_state.dart';
import '../services/engine_api.dart';
import '../services/engine_exception.dart';
import '../services/fiction_clock.dart';
import '../services/local_store.dart';
import '../services/playback.dart';
import '../widgets/composer.dart';
import 'session_providers.dart';

final localStoreProvider = FutureProvider<LocalStore>((ref) async {
  final joueur = await ref.watch(authPreteProvider.future);
  return LocalStore.ouvrir(joueur);
});

/// État affichable de la conversation.
class ConversationState {
  const ConversationState({
    required this.fil,
    required this.node,
    required this.conversations,
    required this.chapterEnd,
    required this.typing,
    required this.presence,
    required this.enDeroule,
    required this.mode,
    required this.heures,
    this.erreur,
  });

  final List<ClientMessage> fil;
  final StoryNode? node;
  final List<Conversation> conversations;
  final ChapterEnd? chapterEnd;
  final TypingState typing;

  /// Libellé de présence, tel que le serveur l'a envoyé. Null = en ligne.
  final String? presence;
  final bool enDeroule;
  final ComposerMode mode;

  /// Heure **de fiction** par `seq`. Jamais l'horloge système.
  final Map<int, int> heures;
  final String? erreur;

  Conversation? get contact => conversations.isEmpty ? null : conversations.first;

  /// Le sous-titre de l'en-tête. Priorité au typing : c'est ce que fait une
  /// vraie messagerie.
  String get sousTitre {
    if (typing != TypingState.aucun) return 'en train d\'écrire…';
    return presence ?? 'en ligne';
  }

  ConversationState copier({
    List<ClientMessage>? fil,
    StoryNode? node,
    bool viderNode = false,
    List<Conversation>? conversations,
    ChapterEnd? chapterEnd,
    TypingState? typing,
    String? presence,
    bool viderPresence = false,
    bool? enDeroule,
    ComposerMode? mode,
    Map<int, int>? heures,
    String? erreur,
    bool viderErreur = false,
  }) =>
      ConversationState(
        fil: fil ?? this.fil,
        node: viderNode ? null : (node ?? this.node),
        conversations: conversations ?? this.conversations,
        chapterEnd: chapterEnd ?? this.chapterEnd,
        typing: typing ?? this.typing,
        presence: viderPresence ? null : (presence ?? this.presence),
        enDeroule: enDeroule ?? this.enDeroule,
        mode: mode ?? this.mode,
        heures: heures ?? this.heures,
        erreur: viderErreur ? null : (erreur ?? this.erreur),
      );
}

class ConversationController extends AsyncNotifier<ConversationState> {
  late final EngineApi _api = ref.read(engineApiProvider);
  late LocalStore _store;
  late PlaybackEngine _moteur;

  final List<ClientMessage> _fil = [];
  StoryNode? _node;
  List<Conversation> _conversations = const [];
  ChapterEnd? _chapterEnd;
  bool _verrouille = false;
  bool _termine = false;
  Timer? _fallbackContinuation;

  @override
  Future<ConversationState> build() async {
    await ref.watch(authPreteProvider.future);
    _store = await ref.watch(localStoreProvider.future);

    _moteur = PlaybackEngine(
      onMessage: (m) {
        _fil.add(m);
        unawaited(_store.poserCurseur(m.seq));
      },
      onChangement: _publier,
      onVibration: () => HapticFeedback.mediumImpact(),
    );
    ref.onDispose(() {
      // Riverpod interdit de toucher à `state` pendant un cycle de vie : on
      // coupe la publication AVANT d'interrompre le moteur.
      _termine = true;
      _fallbackContinuation?.cancel();
      _moteur.interrompre();
      // Ce qui n'a pas été joué reprendra avec ses délais à la réouverture.
      unawaited(_store.poserEnAttente(_moteur.restants));
    });

    final etat = await _api.getState();
    _appliquerEtat(etat);
    return _etat();
  }

  void _appliquerEtat(GameState etat) {
    _node = etat.node;
    _conversations = etat.conversations;
    _chapterEnd = etat.chapterEnd;

    // L'historique se rejoue d'un bloc : le déjà-vu n'a pas de timers.
    final enAttente = _store.enAttente;
    final aRejouer = enAttente.map((m) => m.seq).toSet();
    _fil
      ..clear()
      ..addAll(etat.history.where((m) => !aRejouer.contains(m.seq)));

    _reintercalerDecoratifs();

    // Ce qui n'avait pas été joué avant la fermeture reprend avec ses délais.
    if (enAttente.isNotEmpty) {
      unawaited(_moteur.jouer(enAttente));
    }
  }

  /// Les messages décoratifs n'existent que localement : on les replace à leur
  /// ancre pour qu'ils gardent leur position dans le fil.
  void _reintercalerDecoratifs() {
    for (final d in _store.decoratifs) {
      final index = _fil.lastIndexWhere((m) => m.seq <= d.seq);
      _fil.insert(index + 1, d);
    }
  }

  ConversationState _etat() => ConversationState(
        fil: List.unmodifiable(_fil),
        node: _node,
        conversations: _conversations,
        chapterEnd: _chapterEnd,
        typing: _moteur.typing,
        presence: _moteur.presence,
        enDeroule: _moteur.enCours,
        mode: _mode(),
        heures: FictionClock.horaires(_fil),
      );

  /// Le mode se déduit entièrement du contrat : le client ne connaît pas le graphe.
  ComposerMode _mode() {
    final n = _node;
    if (n == null) return ComposerMode.decorative;
    if (n.kind == NodeKind.aiMoment) return ComposerMode.aiInput;
    if (n.replies.isEmpty && n.canContinue) return ComposerMode.continuation;
    return ComposerMode.decorative;
  }

  void _publier() {
    if (_termine) return;
    state = AsyncData(_etat());
    _armerFallbackContinuation();
  }

  /// Pour le joueur qui n'écrit rien et ne touche à rien. Toute action remet le
  /// compteur à zéro — voir DESIGN.md § Le geste de continuation.
  void _armerFallbackContinuation() {
    _fallbackContinuation?.cancel();
    if (_moteur.enCours || _mode() != ComposerMode.continuation) return;
    final aUnMedia = _fil.isNotEmpty &&
        _fil.last.contentType != ContentType.text &&
        _fil.last.contentType != ContentType.separator;
    _fallbackContinuation = Timer(
      Duration(seconds: aUnMedia ? 30 : 25),
      () { if (!_termine) state = AsyncData(_etat().copier()); },
    );
  }

  /// Toute action du joueur repousse l'affordance de continuation.
  void signalerActivite() => _armerFallbackContinuation();

  // --- Actions --------------------------------------------------------------

  Future<void> choisir(String choiceId) async {
    if (_verrouille || _moteur.enCours) return;
    _verrouille = true;
    _publier();
    try {
      final r = await _api.advanceChoice(choiceId);
      await _appliquerAvance(r);
    } on EngineException catch (e) {
      await _traiter(e);
    } finally {
      _verrouille = false;
      _publier();
    }
  }

  Future<void> continuer() async {
    if (_verrouille || _moteur.enCours) return;
    _verrouille = true;
    try {
      final r = await _api.advanceContinue();
      await _appliquerAvance(r);
    } on EngineException catch (e) {
      await _traiter(e);
    } finally {
      _verrouille = false;
      _publier();
    }
  }

  /// Envoi depuis le champ de saisie. Le mode décide de ce qui se passe.
  Future<void> envoyerTexte(String texte) async {
    final contactId = _conversations.firstOrNull?.contactId;
    if (contactId == null) return;

    // Le texte s'affiche toujours — décoratif, local, jamais délivré.
    final decoratif = ClientMessage.decorative(
      contactId: contactId,
      texte: texte,
      ancreSeq: _fil.isEmpty ? 0 : _fil.last.seq,
    );
    _fil.add(decoratif);
    await _store.ajouterDecoratif(decoratif);
    _publier();

    // En mode continuation, écrire est le geste qui fait avancer.
    if (_mode() == ComposerMode.continuation) await continuer();
  }

  Future<void> _appliquerAvance(AdvanceResult r) async {
    _node = r.node;
    _conversations = r.conversations;
    _chapterEnd = r.chapterEnd;
    await _store.poserEnAttente(r.newMessages);
    await _moteur.jouer(r.newMessages);
    await _store.poserEnAttente(const []);
  }

  /// Une erreur que l'état local ne peut pas résoudre : on resynchronise.
  /// `get-state` fait toujours foi.
  Future<void> _traiter(EngineException e) async {
    if (e.exigeResynchronisation) {
      final etat = await _api.getState();
      _appliquerEtat(etat);
      return;
    }
    state = AsyncData(_etat().copier(erreur: e.message));
  }

  /// Outil de développement : délivre tout ce qui reste sans attendre.
  void sauterLeDeroule() {
    _moteur.sauter();
    unawaited(_store.poserEnAttente(const []));
  }
}

final conversationProvider =
    AsyncNotifierProvider<ConversationController, ConversationState>(
        ConversationController.new);
