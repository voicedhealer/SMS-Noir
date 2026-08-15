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
}

/** Un choix proposé. Aucune trace de sa cible ni de ses effets. */
export interface ClientChoice {
  id: string
  position: number
  label: string
  kind: ChoiceKind
}

export interface ClientConversation {
  contact_id: string
  /** Nom réel ou nom d'avant révélation, selon `contacts_reveles`. */
  display_name: string
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
}

export interface ChapterEndState {
  chapter_title: string
  next_chapter_title: string | null
  unlocked_at: string | null
  /** true quand le chapitre suivant n'a pas encore de contenu. */
  next_chapter_pending: boolean
}

export interface GetStateResponse {
  story: { slug: string; title: string }
  conversations: ClientConversation[]
  /** Historique complet, ordonné par seq. */
  history: (ClientMessage & { contact_id: string })[]
  node: ClientNode | null
  chapter_end: ChapterEndState | null
  /** Le nœud courant est un ai_moment : la saisie libre est ouverte (prompt 3). */
  ai_moment_pending: boolean
}

export interface AdvanceResponse {
  /** Messages produits par ce coup, à dérouler dans l'ordre. */
  new_messages: (ClientMessage & { contact_id: string })[]
  node: ClientNode | null
  conversations: ClientConversation[]
  chapter_end: ChapterEndState | null
  ai_moment_pending: boolean
  /** true si l'appel était un rejeu : rien n'a été réappliqué. */
  idempotent_replay: boolean
}
