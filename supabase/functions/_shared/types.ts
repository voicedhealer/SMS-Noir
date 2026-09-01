// Types partagés du moteur narratif.
// Le contrat client (ce qui SORT des Edge Functions) est défini plus bas :
// il ne contient jamais next_node_id, effects ni conditions.

export type NodeKind = 'scripted' | 'ai_moment' | 'chapter_end'
export type ChoiceKind = 'reply' | 'ignore' | 'interaction'
export type ContentType = 'text' | 'image' | 'audio' | 'system' | 'separator'
export type Sender = 'contact' | 'player'
export type MessageSource = 'scripted' | 'player_choice' | 'player_free' | 'ai'

/** Variables de partie. Voir docs/LOGIQUE.md. */
export interface Variables {
  confiance: number
  lucidite: number
  indices: string[]
  refus: boolean
  branche_ch1: string | null
  /** Interactions déjà consommées — rend les gestes cachés non répétables. */
  interactions_faites?: string[]
  /** Codes des contacts dont l'identité a été révélée au joueur. */
  contacts_reveles?: string[]
  [k: string]: unknown
}

/** `nodes.effects` et `choices.effects`. */
export interface Effects {
  set?: Record<string, unknown>
  inc?: Record<string, number>
  /** Ajout à une liste, sans doublon. */
  append?: Record<string, string>
  /** Code de contact à révéler. */
  reveal_contact?: string
  /**
   * Change l'avatar d'un contact en cours d'histoire : `{"code": "chemin"}`.
   * Léna enverra une photo de profil plus tard — le mécanisme l'attend.
   */
  set_avatar?: Record<string, string>
  /**
   * Axe d'un micro-choix : `proteger`, `enquete` ou `raison`.
   *
   * **Le contenu ne porte aucun nombre.** Il déclare une posture, le moteur en
   * tire une valeur. C'est ce qui permettra de retoucher la formule au chapitre
   * 5 sans rouvrir une ligne de seed.
   */
  motif?: 'proteger' | 'enquete' | 'raison'
}

/** `choices.conditions`. Clés d'un même objet en ET. `{}` = toujours vrai. */
export interface Conditions {
  eq?: Record<string, unknown>
  gte?: Record<string, number>
  lte?: Record<string, number>
  contains?: Record<string, string>
  not_contains?: Record<string, string>
  count_gte?: Record<string, number>
}

/** Un élément d'`inline_response`. */
export interface InlineMessage {
  sender: Sender
  content_type: ContentType
  body?: string | null
  media_url?: string | null
  delay_seconds?: number
  typing_seconds?: number
}

// ---------------------------------------------------------------------------
// Contrat CLIENT — tout ce qui suit sort des Edge Functions
// ---------------------------------------------------------------------------

/** Un message à dérouler. `delay_seconds`/`typing_seconds` sont joués par le CLIENT. */
export interface ClientMessage {
  seq: number
  sender: Sender
  content_type: ContentType
  body: string | null
  media_url: string | null
  delay_seconds: number
  typing_seconds: number
  push_notification: boolean
  push_text: string | null
  /**
   * Directives de mise en scène pendant l'attente de CE message. Offsets en
   * secondes depuis le début de `delay_seconds`. Voir docs/LOGIQUE.md.
   */
  phantom_typing_at: number | null
  haptic_at: number | null
  /**
   * Renforcement sensoriel de CE message : bulle bordée de rouge (voir
   * DESIGN.md § L'effet de tension). Directive de mise en scène, de la même
   * famille que `phantom_typing_at` — **jamais une information de graphe**.
   * Le client ne sait pas de quel nœud vient une bulle, et n'a pas à le
   * savoir : il lui suffit de ce drapeau.
   */
  tension: boolean
  /**
   * Son d'ambiance à jouer EN BOUCLE à partir de ce message, et jusqu'au
   * premier message sans `tension`. Chemin signé relatif, comme `media_url`.
   * Renseigné sur le message déclencheur seul — jamais rejoué en relecture.
   */
  ambience_sound_url: string | null
}

/** Un choix proposé. Aucune trace de sa cible ni de ses effets. */
export interface ClientChoice {
  id: string
  position: number
  label: string
  kind: ChoiceKind
  /**
   * Interactions cachées seulement : comment le joueur la provoque.
   *
   * `geste` — sur le média lui-même (zoomer une photo, réécouter un vocal).
   * `texte` — une chose qu'il DIT, présentée parmi les réponses.
   *
   * **Déclaré par le contenu, jamais déduit par le client.** Il le devinait à
   * l'état du fil, ce qui faisait apparaître un bouton pour un zoom dès que le
   * joueur répondait à un micro-choix — et ne savait pas traiter le N8, qui
   * porte les deux natures. Null pour tout autre kind.
   */
  declencheur: 'geste' | 'texte' | null
}

export interface ClientConversation {
  contact_id: string
  /** Code stable (`lena`, `karim`…) — sert au geste d'enregistrement. */
  code: string
  /** Nom réel ou nom d'avant révélation, selon `contacts_reveles`. */
  display_name: string
  /** Numéro affiché sur la carte d'enregistrement. */
  phone_number: string | null
  avatar_url: string | null
  /** false tant que le contact n'a pas dévoilé son identité. */
  revealed: boolean
}

/**
 * Le nœud courant, filtré.
 *
 * Il ne porte PAS ses messages : ils ont déjà été écrits dans l'historique au
 * moment où le nœud a été atteint. `advance` les renvoie avec leurs délais dans
 * `new_messages` (le client joue les timers) ; `get-state` les rend via
 * `history` (rejeu instantané, pas de re-timing de ce qui a déjà été vu).
 */
export interface ClientNode {
  code: string
  kind: NodeKind
  /** Uniquement les choix dont les conditions sont remplies. */
  choices: ClientChoice[]
  /**
   * Le nœud est en pause sur une interaction cachée : aucun choix `reply`/`ignore`
   * n'est proposé. Le client doit offrir un moyen de continuer sans interagir
   * (`advance { continue: true }`) sans jamais signaler l'interaction disponible.
   */
  awaiting_interaction: boolean
  /**
   * true si le nœud peut être franchi par `advance { continue: true }`.
   * Sur un `ai_moment`, cela emprunte le fallback — le chemin prévu quand l'IA
   * est indisponible.
   */
  can_continue: boolean
  /**
   * Ligne de contexte discrète, générique (pas réservée aux ai_moment) — voir
   * docs/LOGIQUE.md § L'aparté. Le client décide QUAND l'afficher (ni
   * déroulé, ni typing) ; le serveur ne fait que transmettre le texte, ou
   * null si ce nœud n'en porte pas.
   */
  aparte: string | null
  /**
   * Le nœud attend une réponse **écrite** : taper dans le champ déclenche
   * l'interaction disponible au lieu de faire avancer le nœud, et le contenu
   * du texte n'est jamais examiné. Voir DESIGN.md § « Et vous ? ».
   */
  attend_saisie: boolean
}

export interface ChapterEndState {
  /**
   * Rythme de la révélation : `user_paced` (défaut) laisse le joueur avancer
   * phrase par phrase, `timed` rétablirait un minuteur.
   *
   * ⚠️ Propre au `chapter_end`. Les écrans noirs narratifs restent minutés par
   * leur contenu (décalages dans le `body`, durée = délai du message suivant) —
   * ne pas confondre les deux mécaniques au chapitre 3.
   */
  reveal_mode: 'timed' | 'user_paced'

  chapter_title: string
  next_chapter_title: string | null
  /** Pour composer « Chapitre N — titre » sans jamais coder N en dur. */
  next_chapter_position: number | null
  unlocked_at: string | null
  /** true quand le chapitre suivant n'a pas encore de contenu. */
  next_chapter_pending: boolean
  /**
   * Délai de déblocage du chapitre SUIVANT, en minutes — pour que le client
   * compose « Me prévenir dans Xh » sans jamais coder ce chiffre en dur.
   * Null si le chapitre suivant n'existe pas.
   */
  next_chapter_unlock_delay_minutes: number | null
  /** Corps de la notification locale. Null = bouton « Me prévenir » inerte. */
  next_chapter_notification_text: string | null
  /** Phrase d'accroche courte du chapitre suivant. Null = pas de ligne affichée. */
  next_chapter_teaser_text: string | null
}

/** Séquence d'ouverture, jouée une seule fois par le client. */
export interface IntroSequence {
  panels: { lines: string[] }[]
  music_url: string | null
}

/** Effets sonores de l'histoire. Chemins signés, ou null si silencieux. */
export interface SoundPack {
  received: string | null
  sent: string | null
  /** Frappe. Jamais joué sur le typing fantôme — c'est le client qui arbitre. */
  typing: string | null
}

/** Une ligne du carnet : un indice trouvé, et ce qu'on en a noté. */
export interface Clue {
  code: string
  texte: string
}

export interface GetStateResponse {
  story: { slug: string; title: string; tagline: string | null; cover_url: string | null }
  /** Sons de message. Le client décide quand les jouer, jamais le serveur. */
  sounds: SoundPack
  /** Panneaux d'intronisation. `panels` vide = pas d'intro pour cette histoire. */
  intro: IntroSequence
  /**
   * Messages produits par CET appel — c'est-à-dire ceux du nœud d'entrée, à la
   * toute première visite. Ils portent leurs délais et doivent être **joués**,
   * pas rendus d'un bloc : sinon le tout premier message de l'histoire
   * apparaîtrait sans attente ni typing. Vide aux appels suivants.
   */
  new_messages: (ClientMessage & { contact_id: string })[]
  conversations: ClientConversation[]
  /** Déjà vu, à rendre d'un bloc. N'inclut jamais `new_messages`. */
  history: (ClientMessage & { contact_id: string })[]
  node: ClientNode | null
  chapter_end: ChapterEndState | null
  /**
   * Le carnet — indices déjà trouvés, dans l'ordre de découverte.
   *
   * Vide tant que le joueur n'a rien trouvé, **jamais un compteur** : pas de
   * « 3/6 », pas d'emplacement pour un indice manquant. Le carnet documente
   * l'enquête, il ne mesure pas la progression.
   */
  clues: Clue[]
  /** Le nœud courant est un ai_moment : la saisie libre est ouverte (prompt 3). */
  ai_moment_pending: boolean
  /**
   * Le joueur a déjà répondu (accepté ou refusé) au consentement IA — carte
   * d'entrée, avant l'intronisation. `false` tant qu'aucune décision n'existe
   * en base : c'est ce qui fait réafficher la carte d'entrée, jamais un état
   * local qui ne prouverait rien.
   */
  ai_consent_decided: boolean
}

export interface AdvanceResponse {
  /** Messages produits par ce coup, à dérouler dans l'ordre. */
  new_messages: (ClientMessage & { contact_id: string })[]
  node: ClientNode | null
  conversations: ClientConversation[]
  chapter_end: ChapterEndState | null
  /**
   * Le carnet, tel qu'il est APRÈS ce coup.
   *
   * Renvoyé ici et pas seulement par `get-state` parce que c'est `advance` qui
   * accorde les indices (`effects.append.indices`) : sans lui, le carnet
   * n'apprendrait la trouvaille qu'au prochain démarrage de l'app, et le
   * joueur qui l'ouvre juste après avoir zoomé le verrait vide.
   *
   * Même projection, mêmes règles : les indices trouvés seulement, dans
   * l'ordre de découverte, jamais un compteur.
   */
  clues: Clue[]
  ai_moment_pending: boolean
  /** true si l'appel était un rejeu : rien n'a été réappliqué. */
  idempotent_replay: boolean
}
