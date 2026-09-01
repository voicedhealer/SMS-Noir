/// Projection cliente de l'état de jeu.
///
/// Ces modèles suivent le CONTRAT des Edge Functions, pas le schéma SQL : le
/// client ne voit qu'une projection filtrée. Rien ici ne porte de
/// `next_node_id`, d'`effects`, de `conditions` ni de variable de partie —
/// le serveur ne les envoie pas, et le client n'en a pas besoin.
library;

import 'client_message.dart';

enum ChoiceKind {
  reply,

  /// Bouton explicite, visuellement plus effacé. C'est un vrai choix,
  /// jamais un timeout.
  ignore,

  /// ⚠️ JAMAIS un bouton. Le `label` peut être un spoiler — au N17 il vaut
  /// « C'est quoi ce bruit derrière vous ? », soit l'indice lui-même.
  /// Voir DESIGN.md § Interactions cachées.
  interaction,
}

enum NodeKind { scripted, aiMoment, chapterEnd }

enum Declencheur {
  /// Sur le média lui-même : zoomer une photo, réécouter un vocal.
  geste,

  /// Une chose que le joueur DIT — présentée parmi les réponses.
  texte,
}

class ClientChoice {
  const ClientChoice({
    required this.id,
    required this.position,
    required this.label,
    required this.kind,
    this.declencheur,
  });

  final String id;
  final int position;
  final String label;
  final ChoiceKind kind;

  /// Interactions cachées seulement : comment le joueur la provoque.
  /// **Déclaré par le contenu**, jamais déduit de l'état du fil. Null ailleurs.
  final Declencheur? declencheur;

  factory ClientChoice.fromJson(Map<String, dynamic> json) => ClientChoice(
        id: json['id'] as String,
        position: (json['position'] as num).toInt(),
        label: json['label'] as String,
        kind: switch (json['kind']) {
          'ignore' => ChoiceKind.ignore,
          'interaction' => ChoiceKind.interaction,
          _ => ChoiceKind.reply,
        },
        declencheur: switch (json['declencheur']) {
          'geste' => Declencheur.geste,
          'texte' => Declencheur.texte,
          _ => null,
        },
      );
}

class Conversation {
  const Conversation({
    required this.contactId,
    required this.code,
    required this.displayName,
    required this.phoneNumber,
    required this.avatarUrl,
    required this.revealed,
  });

  final String contactId;

  /// Code stable (`lena`, `karim`…) — c'est lui que porte le geste
  /// d'enregistrement.
  final String code;

  /// Numéro affiché sur la carte d'enregistrement.
  final String? phoneNumber;

  /// Nom à afficher, déjà arbitré par le serveur : `display_name_initial`
  /// tant que le contact n'est pas révélé, puis `display_name`.
  final String displayName;
  final String? avatarUrl;

  /// Passe à true quand le contact a dévoilé son identité. La bascule est un
  /// micro-événement narratif, pas un détail technique.
  final bool revealed;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        contactId: json['contact_id'] as String,
        code: json['code'] as String? ?? '',
        displayName: json['display_name'] as String,
        phoneNumber: json['phone_number'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        revealed: json['revealed'] as bool? ?? false,
      );
}

class StoryNode {
  const StoryNode({
    required this.code,
    required this.kind,
    required this.choices,
    required this.awaitingInteraction,
    required this.canContinue,
    this.attendSaisie = false,
    this.aparte,
  });

  /// Label narratif (« N19 »). Sert au débogage et aux tests, **jamais** à
  /// piloter l'UI : le client ne connaît pas le graphe.
  final String code;
  final NodeKind kind;
  final List<ClientChoice> choices;

  /// Le nœud est en pause sur une interaction cachée : aucune réponse à
  /// donner. Le champ de saisie passe en mode continuation.
  final bool awaitingInteraction;

  /// `advance {continue:true}` est recevable sur ce nœud.
  final bool canContinue;

  /// Le nœud attend une réponse **écrite** : taper déclenche l'interaction
  /// disponible au lieu de faire avancer le nœud. Au N16, seulement après le
  /// micro-choix 🔍 — c'est le serveur qui en décide, le client ne connaît pas
  /// le graphe. Voir DESIGN.md § « Et vous ? ».
  final bool attendSaisie;

  /// Ligne de contexte discrète, générique — voir docs/LOGIQUE.md § L'aparté.
  /// Null = ce nœud n'en porte pas. C'est `ConversationState.aparteEnCours`
  /// qui décide QUAND l'afficher, pas ce champ brut.
  final String? aparte;

  /// Les seuls choix qui deviennent des boutons.
  List<ClientChoice> get replies =>
      choices.where((c) => c.kind != ChoiceKind.interaction).toList();

  /// Jamais rendues comme des boutons : elles se déclenchent par un geste
  /// (tap sur un média, réécoute, « + » discret).
  List<ClientChoice> get interactions =>
      choices.where((c) => c.kind == ChoiceKind.interaction).toList();

  factory StoryNode.fromJson(Map<String, dynamic> json) => StoryNode(
        code: json['code'] as String,
        kind: switch (json['kind']) {
          'ai_moment' => NodeKind.aiMoment,
          'chapter_end' => NodeKind.chapterEnd,
          _ => NodeKind.scripted,
        },
        choices: (json['choices'] as List<dynamic>? ?? const [])
            .map((c) => ClientChoice.fromJson(c as Map<String, dynamic>))
            .toList(),
        awaitingInteraction: json['awaiting_interaction'] as bool? ?? false,
        canContinue: json['can_continue'] as bool? ?? false,
        attendSaisie: json['attend_saisie'] as bool? ?? false,
        aparte: json['aparte'] as String?,
      );
}

/// Rythme de la révélation de fin de chapitre.
enum RevealMode {
  /// Le joueur avance phrase par phrase, en tapant « Je continue ».
  userPaced,

  /// Minuteur fixe entre les phrases. Plus utilisé au chapitre 1 ; gardé parce
  /// qu'un futur chapitre pourrait vouloir une fin qui défile toute seule.
  timed,
}

class ChapterEnd {
  const ChapterEnd({
    required this.chapterTitle,
    required this.nextChapterTitle,
    required this.unlockedAt,
    required this.nextChapterPending,
    this.revealMode = RevealMode.userPaced,
    this.nextChapterPosition,
    this.nextChapterUnlockDelayMinutes,
    this.nextChapterNotificationText,
    this.nextChapterTeaserText,
  });

  final String chapterTitle;

  /// Rythme de la révélation. `userPaced` par défaut : c'est la fonction même
  /// de cet écran que de laisser absorber.
  ///
  /// ⚠️ Propre au `chapter_end`. Un écran noir narratif reste minuté par son
  /// contenu — les deux mécaniques coexistent, aucune n'est le défaut de
  /// l'autre. Voir migration 20260901120000.
  final RevealMode revealMode;

  final String? nextChapterTitle;

  /// Pour composer « Chapitre N — titre » sans jamais coder N en dur.
  final int? nextChapterPosition;

  /// Purement décoratif côté client : seul le serveur débloque réellement.
  final DateTime? unlockedAt;

  /// Le chapitre suivant existe mais n'a pas encore de contenu.
  final bool nextChapterPending;

  /// Pour composer « Me prévenir dans Xh » sans jamais coder le délai en dur.
  final int? nextChapterUnlockDelayMinutes;

  /// Corps de la notification locale. Null = bouton « Me prévenir » inerte.
  final String? nextChapterNotificationText;

  /// Phrase d'accroche courte du chapitre suivant. Null = pas de ligne affichée.
  final String? nextChapterTeaserText;

  factory ChapterEnd.fromJson(Map<String, dynamic> json) => ChapterEnd(
        chapterTitle: json['chapter_title'] as String? ?? '',
        // Un mode inconnu (contenu d'un chapitre plus récent que l'app) se
        // dégrade en `userPaced` : le joueur garde la main, ce qui ne casse
        // jamais rien — un minuteur inattendu, si.
        revealMode: json['reveal_mode'] == 'timed'
            ? RevealMode.timed
            : RevealMode.userPaced,
        nextChapterTitle: json['next_chapter_title'] as String?,
        nextChapterPosition: json['next_chapter_position'] as int?,
        unlockedAt: json['unlocked_at'] == null
            ? null
            : DateTime.tryParse(json['unlocked_at'] as String)?.toLocal(),
        nextChapterPending: json['next_chapter_pending'] as bool? ?? false,
        nextChapterUnlockDelayMinutes: json['next_chapter_unlock_delay_minutes'] as int?,
        nextChapterNotificationText: json['next_chapter_notification_text'] as String?,
        nextChapterTeaserText: json['next_chapter_teaser_text'] as String?,
      );
}

/// Séquence d'ouverture, jouée une seule fois par le client.
class IntroSequence {
  const IntroSequence({required this.panels, required this.musicUrl,
      this.musiqueFin});

  /// Chaque panneau est une liste de lignes. Vide = pas d'intro.
  final List<List<String>> panels;

  /// Chemin signé relatif, ou null si la séquence est muette.
  final String? musicUrl;

  /// L'autre segment du morceau — l'écran de fin. Porté par l'intro parce
  /// qu'il vient du même enregistrement et se charge au même moment ; il ne
  /// sert pas au même écran.
  ///
  /// La musique des écrans noirs n'est PAS ici : chacun porte la sienne sur le
  /// `media_url` de son message — voir [NarrationScreen].
  final String? musiqueFin;

  bool get estVide => panels.isEmpty;

  factory IntroSequence.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const IntroSequence(panels: [], musicUrl: null);
    return IntroSequence(
      panels: (json['panels'] as List<dynamic>? ?? const [])
          .map((p) => ((p as Map<String, dynamic>)['lines'] as List<dynamic>? ?? const [])
              .map((l) => l as String)
              .toList())
          .toList(),
      musicUrl: json['music_url'] as String?,
      musiqueFin: json['chapter_end_music_url'] as String?,
    );
  }
}

/// Effets sonores de l'histoire. Chemins signés relatifs, ou null.
class SoundPack {
  const SoundPack({this.received, this.sent, this.typing});
  final String? received;
  final String? sent;

  /// Frappe. Jamais joué sur le typing fantôme.
  final String? typing;

  factory SoundPack.fromJson(Map<String, dynamic>? json) => SoundPack(
        received: json?['received'] as String?,
        sent: json?['sent'] as String?,
        typing: json?['typing'] as String?,
      );
}

/// Réponse d'`ai-chat`.
class AiTurn {
  const AiTurn({
    required this.consentRequired,
    required this.newMessages,
    required this.node,
    required this.conversations,
    required this.chapterEnd,
    required this.aiMomentPending,
    required this.exchangesLeft,
  });

  /// Le serveur réclame le consentement avant tout traitement.
  final bool consentRequired;
  final List<ClientMessage> newMessages;
  final StoryNode? node;
  final List<Conversation> conversations;
  final ChapterEnd? chapterEnd;

  /// false = elle a raccroché, l'histoire est repartie au fallback.
  final bool aiMomentPending;
  final int exchangesLeft;

  factory AiTurn.fromJson(Map<String, dynamic> json) => AiTurn(
        consentRequired: json['consent_required'] as bool? ?? false,
        newMessages: (json['new_messages'] as List<dynamic>? ?? const [])
            .map((m) => ClientMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        node: json['node'] == null
            ? null
            : StoryNode.fromJson(json['node'] as Map<String, dynamic>),
        conversations: (json['conversations'] as List<dynamic>? ?? const [])
            .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
            .toList(),
        chapterEnd: json['chapter_end'] == null
            ? null
            : ChapterEnd.fromJson(json['chapter_end'] as Map<String, dynamic>),
        aiMomentPending: json['ai_moment_pending'] as bool? ?? false,
        exchangesLeft: (json['exchanges_left'] as num?)?.toInt() ?? 0,
      );
}

/// Réponse de `get-state`.
class GameState {
  const GameState({
    required this.storySlug,
    required this.storyTitle,
    required this.storyTagline,
    required this.storyCoverUrl,
    required this.intro,
    required this.sounds,
    required this.newMessages,
    required this.conversations,
    required this.history,
    required this.node,
    required this.chapterEnd,
    required this.aiMomentPending,
    required this.aiConsentDecided,
    required this.clues,
  });

  final String storySlug;
  final String storyTitle;

  /// Accroche de l'histoire (« 22h47. Un SMS... »), affichée sur la carte
  /// d'entrée. Null si l'histoire n'en porte pas.
  final String? storyTagline;

  /// Chemin signé relatif de l'image de couverture de l'écran d'entrée. Null
  /// si l'histoire n'en porte pas encore (le cartouche de repli s'applique).
  final String? storyCoverUrl;
  final IntroSequence intro;
  final SoundPack sounds;

  /// Messages écrits par CET appel — le nœud d'entrée, à la première visite.
  /// Ils portent leurs délais et doivent être **joués**, jamais versés dans
  /// l'historique : sinon le premier message de l'histoire arriverait sans
  /// attente ni typing. Vide aux appels suivants.
  final List<ClientMessage> newMessages;
  final List<Conversation> conversations;

  /// Historique complet, ordonné par `seq`, délais à 0 : il se rejoue d'un bloc.
  final List<ClientMessage> history;
  final StoryNode? node;
  final ChapterEnd? chapterEnd;
  final bool aiMomentPending;

  /// Le joueur a déjà répondu (accepté ou refusé) au consentement IA —
  /// carte d'entrée, avant l'intronisation. `false` tant qu'aucune décision
  /// n'existe en base : c'est ce qui fait réafficher la carte d'entrée,
  /// jamais un état local qui ne prouverait rien.
  final bool aiConsentDecided;

  /// Le carnet — les indices déjà trouvés, dans l'ordre de découverte. Vide
  /// tant que rien n'a été trouvé, **jamais un compteur** : le serveur
  /// n'envoie que les trouvés, donc rien ici ne dit ce qui manque.
  final List<Clue> clues;

  factory GameState.fromJson(Map<String, dynamic> json) {
    final story = json['story'] as Map<String, dynamic>? ?? const {};
    return GameState(
      storySlug: story['slug'] as String? ?? '',
      storyTitle: story['title'] as String? ?? '',
      storyTagline: story['tagline'] as String?,
      storyCoverUrl: story['cover_url'] as String?,
      intro: IntroSequence.fromJson(json['intro'] as Map<String, dynamic>?),
      sounds: SoundPack.fromJson(json['sounds'] as Map<String, dynamic>?),
      newMessages: (json['new_messages'] as List<dynamic>? ?? const [])
          .map((m) => ClientMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      conversations: (json['conversations'] as List<dynamic>? ?? const [])
          .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
          .toList(),
      history: (json['history'] as List<dynamic>? ?? const [])
          .map((m) => ClientMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      node: json['node'] == null
          ? null
          : StoryNode.fromJson(json['node'] as Map<String, dynamic>),
      chapterEnd: json['chapter_end'] == null
          ? null
          : ChapterEnd.fromJson(json['chapter_end'] as Map<String, dynamic>),
      aiMomentPending: json['ai_moment_pending'] as bool? ?? false,
      aiConsentDecided: json['ai_consent_decided'] as bool? ?? false,
      clues: Clue.listeDe(json['clues']),
    );
  }
}

/// Une note du carnet : un indice DÉJÀ TROUVÉ, avec son texte.
///
/// Le serveur n'envoie que les trouvés — le client ne peut donc pas déduire ce
/// qu'il reste à chercher, même en lisant la réponse brute. Le [code] ne sert
/// qu'à identifier la note ; il n'est jamais montré au joueur.
class Clue {
  const Clue({required this.code, required this.texte});

  final String code;
  final String texte;

  factory Clue.fromJson(Map<String, dynamic> json) => Clue(
        code: json['code'] as String? ?? '',
        texte: json['texte'] as String? ?? '',
      );

  /// Un code sans texte ne s'affiche pas : le serveur le filtre déjà, et le
  /// client ne rattrape pas un contenu manquant par une ligne vide.
  ///
  /// Une charge illisible donne un carnet vide plutôt qu'une exception — même
  /// principe que `NarrationScreen.decoder` : un contenu abîmé ne doit jamais
  /// empêcher de jouer, et le carnet est un écran de lecture facultatif.
  static List<Clue> listeDe(dynamic brut) {
    if (brut is! List) return const [];
    return [
      for (final c in brut)
        if (c is Map<String, dynamic> && (c['texte'] as String? ?? '').isNotEmpty)
          Clue.fromJson(c),
    ];
  }
}

/// Réponse d'`advance`.
class AdvanceResult {
  const AdvanceResult({
    required this.newMessages,
    required this.node,
    required this.conversations,
    required this.chapterEnd,
    required this.aiMomentPending,
    required this.idempotentReplay,
    required this.clues,
  });

  /// À dérouler AVEC leurs délais. Sur un rejeu, les délais valent 0.
  final List<ClientMessage> newMessages;
  final StoryNode? node;
  final List<Conversation> conversations;
  final ChapterEnd? chapterEnd;
  final bool aiMomentPending;

  /// L'appel était une retransmission : rien n'a été réappliqué côté serveur.
  final bool idempotentReplay;

  /// Le carnet APRÈS ce coup — c'est `advance` qui accorde les indices, donc
  /// c'est lui qui doit le dire. Sans ça, un joueur qui ouvre le carnet juste
  /// après un zoom le verrait encore vide.
  final List<Clue> clues;

  factory AdvanceResult.fromJson(Map<String, dynamic> json) => AdvanceResult(
        newMessages: (json['new_messages'] as List<dynamic>? ?? const [])
            .map((m) => ClientMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        node: json['node'] == null
            ? null
            : StoryNode.fromJson(json['node'] as Map<String, dynamic>),
        conversations: (json['conversations'] as List<dynamic>? ?? const [])
            .map((c) => Conversation.fromJson(c as Map<String, dynamic>))
            .toList(),
        chapterEnd: json['chapter_end'] == null
            ? null
            : ChapterEnd.fromJson(json['chapter_end'] as Map<String, dynamic>),
        aiMomentPending: json['ai_moment_pending'] as bool? ?? false,
        idempotentReplay: json['idempotent_replay'] as bool? ?? false,
        clues: Clue.listeDe(json['clues']),
      );
}
