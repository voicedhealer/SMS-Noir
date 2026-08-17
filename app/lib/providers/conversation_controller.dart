import 'dart:async';
import '../screens/narration_screen.dart';
import 'reglages.dart';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../models/client_message.dart';
import '../models/game_state.dart';
import '../services/engine_api.dart';
import '../services/engine_exception.dart';
import '../services/fiction_clock.dart';
import '../services/musique_narrative.dart';
import '../services/local_store.dart';
import '../services/playback.dart';
import '../services/read_receipts.dart';
import '../services/sound_effects.dart';
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
    this.vu,
    this.nonLus = 0,
    this.intro,
    this.consentementRequis = false,
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

  /// `seq` du message du joueur qui porte le marqueur « Vu. », ou null.
  final int? vu;

  /// Séquence d'ouverture à jouer avant tout. Null = déjà vue, ou aucune.
  final IntroSequence? intro;

  /// L'écran de consentement doit s'afficher.
  final bool consentementRequis;
  final String? erreur;

  Conversation? get contact => conversations.isEmpty ? null : conversations.first;

  /// Lignes de l'écran noir, si le dernier message délivré est une narration.
  ///
  /// La narration tient tant que rien n'est arrivé derrière : c'est le message
  /// SUIVANT qui la referme, et son délai qui en donne la durée. Rien à
  /// synchroniser, donc rien à désynchroniser.
  List<({String texte, int a})> get narrationEnCours {
    if (fil.isEmpty) return const [];
    final dernier = fil.last;
    if (dernier.contentType != ContentType.narration) return const [];
    return NarrationScreen.decoder(dernier.body);
  }

  /// Le fil réunit-il plusieurs interlocuteurs ?
  ///
  /// Faux tant que le chapitre 3 n'existe pas — c'est là que Léna, Karim et le
  /// joueur se retrouvent dans le même fil. Le mécanisme est posé maintenant
  /// pour que le nom d'émetteur n'ait pas à être rétro-ajouté au moment où le
  /// groupe arrivera : il suffira que `conversations` en contienne plusieurs.
  bool get estGroupe => conversations.length > 1;

  /// Nom à afficher sous un message, en conversation de groupe.
  ///
  /// Nul pour le joueur : dans une messagerie, on ne voit jamais son propre nom
  /// sous ses propres messages.
  String? nomDe(ClientMessage m) {
    if (m.sender == MessageSender.player) return null;
    for (final c in conversations) {
      if (c.contactId == m.contactId) return c.displayName;
    }
    return null;
  }

  /// Messages reçus depuis la dernière ouverture de la conversation.
  /// C'est de l'état de présentation : le serveur ne sait pas ce que le joueur
  /// a regardé.
  final int nonLus;

  /// Dernier média du fil. C'est le seul dont le geste (zoom, réécoute) peut
  /// déclencher une interaction : les médias plus anciens appartiennent à des
  /// nœuds révolus.
  ClientMessage? get dernierMedia {
    for (final m in fil.reversed) {
      if (m.contentType == ContentType.image || m.contentType == ContentType.audio) return m;
    }
    return null;
  }

  /// Comment se déclenche l'interaction cachée de ce nœud.
  ///
  /// La règle se déduit du **contrat**, jamais du code de nœud : si le nœud
  /// courant a apporté un média, le geste est sur ce média (zoomer une photo,
  /// réécouter un vocal). Sinon, l'interaction est une chose que le joueur
  /// *dit*, et elle passe par le « + » discret.
  ///
  /// Au chapitre 1 : N10, N16, N21 -> geste sur la photo · N17 -> réécoute ·
  /// N8 et N13 -> « + ». Les six y sont, sans que le client connaisse le graphe.
  bool get interactionParGeste => (node?.interactions.isNotEmpty ?? false) && _noeudAApporteUnMedia;

  List<ClientChoice> get interactionsParlees =>
      _noeudAApporteUnMedia ? const [] : (node?.interactions ?? const []);

  bool get _noeudAApporteUnMedia {
    // Le média du nœud courant est forcément le dernier du fil : les messages
    // arrivent dans l'ordre et un nœud écrit les siens d'un bloc.
    final m = dernierMedia;
    if (m == null) return false;
    final apres = fil.skipWhile((x) => x.seq != m.seq).skip(1);
    // Rien d'autre qu'un texte de commentaire n'a suivi : on est encore dessus.
    return apres.every((x) => x.sender == MessageSender.contact);
  }

  /// Texte de l'écran de fin : le message `system` du nœud `chapter_end`.
  /// Il ne va jamais dans le fil.
  String? get texteFinDeChapitre {
    if (node?.kind != NodeKind.chapterEnd) return null;
    for (final m in fil.reversed) {
      if (m.contentType == ContentType.system) return m.body;
    }
    return null;
  }

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
    int? vu,
    int? nonLus,
    IntroSequence? intro,
    bool viderIntro = false,
    bool? consentementRequis,
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
        vu: vu ?? this.vu,
        nonLus: nonLus ?? this.nonLus,
        intro: viderIntro ? null : (intro ?? this.intro),
        consentementRequis: consentementRequis ?? this.consentementRequis,
        erreur: viderErreur ? null : (erreur ?? this.erreur),
      );
}

class ConversationController extends AsyncNotifier<ConversationState> {
  late final EngineApi _api = ref.read(engineApiProvider);
  late LocalStore _store;
  late PlaybackEngine _moteur;
  final _sons = SoundEffects();

  final List<ClientMessage> _fil = [];
  StoryNode? _node;
  List<Conversation> _conversations = const [];
  ChapterEnd? _chapterEnd;
  bool _verrouille = false;
  bool _termine = false;
  IntroSequence? _intro;

  /// Messages du nœud d'entrée, mis de côté le temps de l'intro.
  List<ClientMessage> _aJouerApresIntro = const [];

  int _nonLus = 0;

  /// `seq` du dernier message du joueur qu'elle a lu, d'après le moteur.
  int? _vuAnticipe;

  /// Une réponse de l'IA est en route. Le typing s'affiche pendant tout ce
  /// temps : sans lui, la latence réseau serait un blanc inexplicable — et une
  /// réponse instantanée trahirait la machine.
  bool _attenteIA = false;

  /// Le serveur réclame le consentement. L'écran s'affiche par-dessus le fil.
  bool _consentementRequis = false;

  /// Le message qu'on rejouera une fois le consentement donné.
  String? _messageEnAttente;

  /// Un déroulé est **imminent** : des messages sont en file, mais leurs timers
  /// n'ont pas encore démarré — typiquement pendant les 4 s de vide qui suivent
  /// l'intronisation. Sans ce drapeau, la zone de choix s'afficherait avant que
  /// Léna ait envoyé quoi que ce soit, puis disparaîtrait, puis reviendrait.
  bool _derouleImminent = false;
  Timer? _fallbackContinuation;

  @override
  Future<ConversationState> build() async {
    // ⚠️ `build()` peut être rejoué sur la MÊME instance (réinitialisation via
    // `invalidateSelf`). Riverpod exécute alors le `onDispose` du build
    // précédent — qui pose `_termine` — puis rappelle `build`. Sans cette
    // remise à zéro, le verrou reste fermé pour toujours : plus aucune
    // publication d'état ne passe, et l'intronisation rejouée débouchait sur
    // une conversation vide où Léna ne parlait jamais.
    _termine = false;
    _derouleImminent = false;
    _verrouille = false;
    _nonLus = 0;
    _vuAnticipe = null;

    await ref.watch(authPreteProvider.future);
    _store = await ref.watch(localStoreProvider.future);

    _moteur = PlaybackEngine(
      onMessage: (m) {
        _fil.add(m);
        // Seule la LIVRAISON sonne. L'historique restitué à la réouverture
        // n'passe pas par ici — pas de rafale de bips au retour dans l'app.
        // Et le typing fantôme ne délivre aucun message : il reste muet, ce qui
        // est tout l'enjeu (un bip ferait croire à un message reçu).
        // Trois étages : fichier, son système, puis vibration. Si rien n'a
        // sonné — Android sans fichier, ou mode silencieux — un message reçu
        // vibre légèrement, comme dans une vraie messagerie.
        //
        // La vibration passe par le MÊME point que le son, donc elle hérite des
        // quatre interdits de SoundEffects.pour() par construction : pas de
        // séparateur, pas de système, pas de carte, pas de décoratif. Et rien
        // pendant le silence du N19, sans condition supplémentaire à tenir.
        final effet = SoundEffects.pour(m);
        final reglages = ref.read(reglagesProvider);
        // Sons coupés dans les Réglages : c'est exactement le même chemin que
        // le mode silencieux du téléphone, donc la vibration prend le relais.
        final aSonne = reglages.sons && _sons.jouer(effet);
        if (!aSonne && reglages.vibrations && effet == EffetSonore.reception) {
          HapticFeedback.lightImpact();
        }
        if (m.sender == MessageSender.contact && m.contentType != ContentType.system) {
          _nonLus++;
        }
        unawaited(_store.poserCurseur(m.seq));
      },
      onChangement: _publier,
      onVibration: () => HapticFeedback.mediumImpact(),
      // Uniquement le typing RÉEL — le moteur ne signale jamais le fantôme.
      onTypingReel: () => _sons.jouer(EffetSonore.frappe),
      // Elle lit avant de taper : le marqueur « Vu. » descend maintenant, pas
      // à l'arrivée de sa réponse.
      onLecture: _marquerLuParElle,
    );
    // Le déroulé s'arrête quand le joueur n'est plus là, et reprend quand il
    // revient. Aucun bouton : ce serait un objet de jeu. C'est aussi le
    // comportement attendu d'une messagerie — les messages arrivent quand on
    // regarde.
    //
    // ⚠️ Si le joueur reste dans l'app sans pouvoir suivre, on ne fait RIEN.
    // Il remontera le fil, comme avec de vrais SMS.
    final cycleDeVie = AppLifecycleListener(
      onPause: _mettreEnPause,
      onResume: _reprendre,
    );

    ref.onDispose(() {
      cycleDeVie.dispose();
      _sons.dispose();
      // Riverpod interdit de toucher à `state` pendant un cycle de vie : on
      // coupe la publication AVANT d'interrompre le moteur.
      _termine = true;
      _fallbackContinuation?.cancel();
      _moteur.interrompre();
      // Ce qui n'a pas été joué reprendra avec ses délais à la réouverture.
      unawaited(_store.poserEnAttente(_moteur.restants));
    });

    final etat = await _api.getState();
    unawaited(_sons.precharger(
      reception: _absolue(etat.sounds.received),
      envoi: _absolue(etat.sounds.sent),
      frappe: _absolue(etat.sounds.typing),
    ));
    _appliquerEtat(etat);
    return _etat();
  }

  String? _absolue(String? chemin) =>
      chemin == null ? null : '${Env.supabaseUrl}$chemin';

  void _appliquerEtat(GameState etat) {
    _node = etat.node;
    _conversations = etat.conversations;
    _chapterEnd = etat.chapterEnd;

    // Intro : jouée une seule fois, avant tout le reste.
    _intro = (!etat.intro.estVide && !_store.introVue) ? etat.intro : null;
    _aJouerApresIntro = const [];

    // L'historique se rejoue d'un bloc : le déjà-vu n'a pas de timers.
    final enAttente = _store.enAttente;
    final aRejouer = enAttente.map((m) => m.seq).toSet();
    _fil
      ..clear()
      ..addAll(etat.history.where((m) => !aRejouer.contains(m.seq)));

    _reintercalerDecoratifs();

    // Ce qui n'avait pas été joué reprend avec ses délais — mais JAMAIS
    // pendant l'intronisation.
    //
    // ⚠️ Le lancer derrière l'écran d'intro serait pire qu'inutile : à la fin
    // de la séquence, `introTerminee` appellerait `jouer` à son tour, ce qui
    // incrémente la génération du moteur et **annule le déroulé en cours**.
    // Les messages restaient en base et disparaissaient du fil.
    final aJouerMaintenant = enAttente.isNotEmpty ? enAttente : etat.newMessages;
    if (aJouerMaintenant.isEmpty) return;
    if (_intro != null) {
      _aJouerApresIntro = aJouerMaintenant;
    } else {
      unawaited(_jouer(aJouerMaintenant));
    }
  }

  /// Déroule une salve en tenant la zone de choix masquée du début à la fin.
  ///
  /// Le drapeau est posé **avant** le premier timer, pas au premier message :
  /// entre les deux il peut s'écouler plusieurs secondes — les 4 s de vide de
  /// l'intronisation, ou simplement le délai du premier message.
  Future<void> _jouer(List<ClientMessage> messages) async {
    _derouleImminent = true;
    try {
      await _moteur.jouer(messages);
    } finally {
      _derouleImminent = false;
      if (!_termine) _publier();
    }
  }

  /// Appelé quand la séquence d'ouverture est terminée.
  ///
  /// **Les 4 secondes de vide qui suivent ne sont pas négociables** : c'est le
  /// calme qui rend l'intrusion violente. Ne pas les réduire pour « fluidifier ».
  static const silenceApresIntro = Duration(seconds: 4);

  Future<void> introTerminee() async {
    final aJouer = _aJouerApresIntro;
    _aJouerApresIntro = const [];
    _intro = null;

    // ⚠️ Posé AVANT le moindre `await`. L'écran de conversation est poussé dans
    // la foulée : s'il se construit pendant qu'on attend l'écriture du drapeau
    // « intro vue », il voit encore un état sans déroulé en cours et affiche
    // les réponses — avant que Léna ait dit un mot.
    _derouleImminent = aJouer.isNotEmpty;
    _publier();

    await _store.marquerIntroVue();
    if (aJouer.isEmpty) return;

    await Future<void>.delayed(silenceApresIntro);
    if (_termine) return;
    await _jouer(aJouer);
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
        typing: _attenteIA ? TypingState.reel : _moteur.typing,
        presence: _moteur.presence,
        enDeroule: _moteur.enCours || _derouleImminent,
        mode: _mode(),
        heures: FictionClock.horaires(_fil),
        vu: ReadReceipts.marqueur(_fil, _vuAnticipe),
        consentementRequis: _consentementRequis,
        nonLus: _nonLus,
        intro: _intro,
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

  // --- Cycle de vie de l'application ----------------------------------------

  /// L'app passe en arrière-plan : on gèle le déroulé au message en cours.
  ///
  /// Ce qui restait est persisté avec ses délais — c'est la file en attente de
  /// D4. Le message dont l'attente était entamée repart de son début à la
  /// reprise : on ne mémorise pas la fraction écoulée, et c'est volontaire.
  /// Reprendre à 3 secondes d'un silence de 90 en supprimerait tout l'effet.
  void _mettreEnPause() {
    if (!_moteur.enCours) return;
    final restants = _moteur.restants;
    _moteur.interrompre();
    _derouleImminent = restants.isNotEmpty;
    unawaited(_store.poserEnAttente(restants));
    _publier();
  }

  /// L'app revient au premier plan : on reprend là où on s'était arrêté.
  void _reprendre() {
    final restants = _store.enAttente;
    if (restants.isEmpty || _moteur.enCours) return;
    unawaited(_jouer(restants));
  }

  /// Toute action du joueur repousse l'affordance de continuation.
  void signalerActivite() => _armerFallbackContinuation();

  /// Le joueur enregistre le contact du fil.
  ///
  /// Ce geste **remplace** l'ancien effect automatique : c'est lui qui révèle
  /// l'identité. S'il ne le fait jamais, le nœud de fin de chapitre s'en charge
  /// — un geste facultatif ne bloque pas l'histoire.
  Future<void> enregistrerContact() async {
    final code = _conversations.firstOrNull?.code;
    if (code == null || (_conversations.first.revealed)) return;
    try {
      _conversations = await _api.revealContact(code);
      _publier();
    } on EngineException catch (e) {
      await _traiter(e);
    }
  }

  /// Elle vient de prendre connaissance du fil.
  void _marquerLuParElle() {
    for (final m in _fil.reversed) {
      if (m.sender != MessageSender.player) continue;
      if (_vuAnticipe == null || m.seq > _vuAnticipe!) {
        _vuAnticipe = m.seq;
        _publier();
      }
      return;
    }
  }

  /// Le joueur ouvre la conversation : tout est lu.
  void marquerLu() {
    if (_nonLus == 0) return;
    _nonLus = 0;
    _publier();
  }

  /// Déclenche l'interaction cachée du nœud courant, s'il en reste une.
  ///
  /// Appelée par un **geste** — zoom sur une photo, réécoute d'un vocal — ou
  /// par le « + ». Silencieuse s'il n'y a rien : le joueur qui zoome sur une
  /// vieille photo ne doit rien remarquer.
  Future<void> declencherInteraction([String? choiceId]) async {
    final id = choiceId ?? _node?.interactions.firstOrNull?.id;
    if (id == null) return;
    await choisir(id);
  }

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

  // --- Moment IA ------------------------------------------------------------

  /// Saisie libre du N9. Le texte part vraiment, contrairement au mode décoratif.
  Future<void> envoyerAuMomentIA(String texte) async {
    if (_verrouille || _attenteIA) return;
    final contactId = _conversations.firstOrNull?.contactId;
    if (contactId == null) return;

    // Sa réplique s'affiche tout de suite : dans une messagerie, ce qu'on
    // envoie apparaît avant que l'autre ait lu. Le serveur la réécrira avec son
    // vrai `seq`, on retire alors la version locale.
    final provisoire = ClientMessage.decorative(
      contactId: contactId, texte: texte, ancreSeq: _fil.isEmpty ? 0 : _fil.last.seq);
    _fil.add(provisoire);
    _attenteIA = true;
    _publier();

    try {
      final tour = await _api.aiChat(message: texte);
      _fil.remove(provisoire);
      if (tour.consentRequired) {
        // Le serveur n'a rien traité : on demande, puis on rejouera ce message.
        _messageEnAttente = texte;
        _consentementRequis = true;
        return;
      }
      await _appliquerTourIA(tour);
    } on EngineException catch (e) {
      _fil.remove(provisoire);
      await _traiter(e);
    } finally {
      _attenteIA = false;
      _publier();
    }
  }

  /// Réponse à l'écran de consentement. Un refus ne pénalise pas : le serveur
  /// fait raccrocher Léna et l'histoire repart.
  Future<void> repondreConsentement(bool accepte) async {
    _consentementRequis = false;
    final aRejouer = _messageEnAttente;
    _messageEnAttente = null;
    _attenteIA = true;
    _publier();
    try {
      final tour = await _api.aiChat(consent: accepte);
      await _appliquerTourIA(tour);
      if (accepte && aRejouer != null) {
        _attenteIA = false;
        await envoyerAuMomentIA(aRejouer);
        return;
      }
    } on EngineException catch (e) {
      await _traiter(e);
    } finally {
      _attenteIA = false;
      _publier();
    }
  }

  Future<void> _appliquerTourIA(AiTurn tour) async {
    _node = tour.node;
    if (tour.conversations.isNotEmpty) _conversations = tour.conversations;
    _chapterEnd = tour.chapterEnd;
    if (tour.newMessages.isEmpty) return;
    // Le typing du réseau s'arrête ici ; celui du déroulé prend le relais.
    _attenteIA = false;
    await _jouer(tour.newMessages);
  }

  Future<void> _appliquerAvance(AdvanceResult r) async {
    _node = r.node;
    _conversations = r.conversations;
    _chapterEnd = r.chapterEnd;
    await _store.poserEnAttente(r.newMessages);
    await _jouer(r.newMessages);
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

  /// Efface la partie et la mémoire locale : le joueur repart du tout début,
  /// intronisation comprise. Outil de développement.
  Future<void> reinitialiser() async {
    // Une intro va rejouer : on part d'un état sonore propre. `demarrer` coupe
    // déjà la précédente, mais ne rien laisser tourner pendant l'aller-retour
    // réseau évite toute superposition.
    await MusiqueNarrative.instance.arreter();
    _moteur.interrompre();
    await _api.resetProgress();
    await _store.effacerTout();
    ref.invalidateSelf();
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
