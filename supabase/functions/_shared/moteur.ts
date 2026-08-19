// Accès base + parcours du graphe. Partagé par get-state et advance.
// Référence : docs/LOGIQUE.md § Cycle de vie d'un nœud.

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2'
import {
  appliquerEffects,
  appliquerPlafonds,
  avatarDe,
  evaluerConditions,
  nomAffiche,
  normaliserVariables,
  VARIABLES_INITIALES,
} from './engine.ts'
import type {
  ChapterEndState,
  ClientChoice,
  ClientConversation,
  ClientMessage,
  ClientNode,
  Variables,
} from './types.ts'

export const STORY_SLUG = 'numero-inconnu'

/** Garde-fou : une chaîne de transitions automatiques ne doit jamais boucler. */
const MAX_ENCHAINEMENTS = 50

export class ErreurMoteur extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message)
  }
}

/** Client service_role — contourne la RLS. Ne quitte JAMAIS le serveur. */
export function clientAdmin(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL')
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!url || !key) {
    throw new ErreurMoteur(500, 'config_manquante', 'SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY absents')
  }
  return createClient(url, key, { auth: { persistSession: false } })
}

/** Identifie l'appelant à partir de son JWT. */
export async function utilisateurCourant(req: Request): Promise<string> {
  const authorization = req.headers.get('Authorization')
  if (!authorization) throw new ErreurMoteur(401, 'non_authentifie', 'En-tête Authorization absent')

  const url = Deno.env.get('SUPABASE_URL')!
  const anon = Deno.env.get('SUPABASE_ANON_KEY')!
  const client = createClient(url, anon, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  })
  const { data, error } = await client.auth.getUser()
  if (error || !data.user) throw new ErreurMoteur(401, 'non_authentifie', 'Jeton invalide')
  return data.user.id
}

// ---------------------------------------------------------------------------
// Types internes (contenu narratif — ne sortent jamais tels quels)
// ---------------------------------------------------------------------------

interface NoeudBrut {
  id: string
  code: string
  kind: 'scripted' | 'ai_moment' | 'chapter_end'
  next_node_id: string | null
  ai_fallback_node_id: string | null
  ai_system_prompt: string | null
  ai_max_exchanges: number | null
  effects: Record<string, unknown>
  chapter_id: string
}

interface ChoixBrut {
  id: string
  node_id: string
  position: number
  label: string
  kind: 'reply' | 'ignore' | 'interaction'
  next_node_id: string | null
  inline_response: unknown
  effects: Record<string, unknown>
  conditions: Record<string, unknown>
}

export interface Progression {
  id: string
  user_id: string
  story_id: string
  current_node_id: string | null
  variables: Variables
  chapter_unlocked_at: string | null
  last_choice_id: string | null
  last_choice_seq: number | null
  /** Position dans le moment IA courant. Tenue par le serveur, jamais ailleurs. */
  ai_exchanges: number
  ai_consent_at: string | null
  ai_consent_refuse: boolean
}

const CHAMPS_NOEUD = 'id, code, kind, next_node_id, ai_fallback_node_id, '
  + 'ai_system_prompt, ai_max_exchanges, effects, chapter_id'
const CHAMPS_PROGRESSION = 'id, user_id, story_id, current_node_id, variables, '
  + 'chapter_unlocked_at, last_choice_id, last_choice_seq, ai_exchanges, '
  + 'ai_consent_at, ai_consent_refuse, node_cursor, node_gate'

const CHAMPS_CHOIX =
  'id, node_id, position, label, kind, next_node_id, inline_response, effects, conditions, '
  + 'after_position'

// ---------------------------------------------------------------------------
// Chargements
// ---------------------------------------------------------------------------

export async function chargerHistoire(db: SupabaseClient) {
  const { data, error } = await db
    .from('stories')
    .select('id, slug, title, tagline, intro_panels, intro_music_url, '
      + 'narration_music_url, chapter_end_music_url, '
      + 'sound_received_url, sound_sent_url, sound_typing_url')
    .eq('slug', STORY_SLUG).single()
  if (error || !data) throw new ErreurMoteur(500, 'histoire_absente', `Histoire « ${STORY_SLUG} » introuvable`)
  return data
}

export async function chargerNoeud(db: SupabaseClient, id: string): Promise<NoeudBrut> {
  const { data, error } = await db.from('nodes').select(CHAMPS_NOEUD).eq('id', id).single()
  if (error || !data) throw new ErreurMoteur(500, 'noeud_introuvable', `Nœud ${id} introuvable`)
  return data as NoeudBrut
}

async function chargerChoix(db: SupabaseClient, nodeId: string): Promise<ChoixBrut[]> {
  const { data, error } = await db
    .from('choices').select(CHAMPS_CHOIX).eq('node_id', nodeId).order('position')
  if (error) throw new ErreurMoteur(500, 'erreur_base', error.message)
  return (data ?? []) as ChoixBrut[]
}

/**
 * Progression du joueur, créée à la première visite.
 * La création positionne le nœud d'entrée et déroule sa chaîne.
 */
export async function chargerOuCreerProgression(
  db: SupabaseClient,
  userId: string,
  storyId: string,
): Promise<{ progression: Progression; messagesInitiaux: MessageEcrit[] }> {
  const { data: existante } = await db
    .from('player_progress')
    .select(CHAMPS_PROGRESSION)
    .eq('user_id', userId).eq('story_id', storyId).maybeSingle()

  if (existante) {
    return {
      progression: { ...existante, variables: normaliserVariables(existante.variables) } as Progression,
      messagesInitiaux: [],
    }
  }

  const { data: chapitre, error: eChap } = await db
    .from('chapters').select('id, entry_node_id')
    .eq('story_id', storyId).eq('position', 1).single()
  if (eChap || !chapitre?.entry_node_id) {
    throw new ErreurMoteur(500, 'chapitre_incomplet', 'Le chapitre 1 n\'a pas de nœud d\'entrée')
  }

  const { data: creee, error } = await db
    .from('player_progress')
    .insert({ user_id: userId, story_id: storyId, variables: VARIABLES_INITIALES })
    .select(CHAMPS_PROGRESSION)
    .single()
  if (error || !creee) throw new ErreurMoteur(500, 'creation_impossible', error?.message ?? 'échec')

  const progression = { ...creee, variables: normaliserVariables(creee.variables) } as Progression

  // Première visite : on entre dans le nœud d'entrée et on déroule sa chaîne.
  const resultat = await entrerDansNoeud(db, progression, chapitre.entry_node_id)
  return { progression: resultat.progression, messagesInitiaux: resultat.messages }
}

// ---------------------------------------------------------------------------
// Écriture des messages
// ---------------------------------------------------------------------------

export interface MessageEcrit extends ClientMessage {
  contact_id: string
}

interface AEcrire {
  contact_id: string
  sender: 'contact' | 'player'
  content_type: string
  body: string | null
  media_url: string | null
  source: string
  delay_seconds: number
  typing_seconds: number
  push_notification: boolean
  push_text: string | null
  phantom_typing_at: number | null
  haptic_at: number | null
}

/**
 * Écrit des messages dans l'historique et les renvoie avec leurs délais.
 *
 * player_messages ne stocke ni délai ni typing : ce sont des instructions de
 * lecture, valables une seule fois. L'historique se rejoue instantanément.
 */
async function ecrire(db: SupabaseClient, progressId: string, lignes: AEcrire[]): Promise<MessageEcrit[]> {
  if (lignes.length === 0) return []
  const { data, error } = await db
    .from('player_messages')
    .insert(lignes.map((l) => ({
      progress_id: progressId,
      contact_id: l.contact_id,
      sender: l.sender,
      content_type: l.content_type,
      body: l.body,
      media_url: l.media_url,
      source: l.source,
    })))
    .select('seq, contact_id, sender, content_type, body, media_url')
  if (error) throw new ErreurMoteur(500, 'ecriture_impossible', error.message)

  const inseres = (data ?? []).sort((a, b) => Number(a.seq) - Number(b.seq))
  return inseres.map((ligne, i) => ({
    seq: Number(ligne.seq),
    contact_id: ligne.contact_id,
    sender: ligne.sender,
    content_type: ligne.content_type,
    body: ligne.body,
    media_url: ligne.media_url,
    delay_seconds: lignes[i].delay_seconds,
    typing_seconds: lignes[i].typing_seconds,
    push_notification: lignes[i].push_notification,
    push_text: lignes[i].push_text,
    phantom_typing_at: lignes[i].phantom_typing_at,
    haptic_at: lignes[i].haptic_at,
  }))
}

export async function ecrireMessageJoueur(
  db: SupabaseClient,
  progressId: string,
  contactId: string,
  texte: string,
  source: 'player_choice' | 'player_free',
): Promise<MessageEcrit[]> {
  return await ecrire(db, progressId, [{
    contact_id: contactId, sender: 'player', content_type: 'text', body: texte,
    media_url: null, source, delay_seconds: 0, typing_seconds: 0,
    push_notification: false, push_text: null,
    phantom_typing_at: null, haptic_at: null,
  }])
}

/** Joue une `inline_response` : elle ne change pas de nœud. */
export async function ecrireInlineResponse(
  db: SupabaseClient,
  progressId: string,
  contactParDefaut: string,
  inline: unknown,
): Promise<MessageEcrit[]> {
  if (!Array.isArray(inline)) return []
  const lignes: AEcrire[] = inline.map((m) => ({
    contact_id: contactParDefaut,
    sender: m.sender === 'player' ? 'player' : 'contact',
    content_type: m.content_type ?? 'text',
    body: m.body ?? null,
    media_url: m.media_url ?? null,
    source: m.sender === 'player' ? 'player_choice' : 'scripted',
    delay_seconds: m.delay_seconds ?? 0,
    typing_seconds: m.typing_seconds ?? 0,
    push_notification: false,
    push_text: null,
    phantom_typing_at: null,
    haptic_at: null,
  }))
  return await ecrire(db, progressId, lignes)
}

// ---------------------------------------------------------------------------
// Parcours du graphe
// ---------------------------------------------------------------------------

/** Le nœud propose-t-il au moins une interaction encore disponible ? */
// Les trois helpers ci-dessous ne regardent que les choix de FIN de nœud
// (`after_position` nul). Ceux qui portent une position sont des pauses
// intermédiaires : ils ont déjà été joués, ou ils le seront plus loin dans le
// déroulé — les compter ici arrêterait le nœud avant l'heure.

async function interactionDisponible(
  db: SupabaseClient, nodeId: string, vars: Variables,
): Promise<boolean> {
  const choix = await chargerChoix(db, nodeId)
  return choix.some((c) =>
    c.after_position === null && c.kind === 'interaction' && evaluerConditions(vars, c.conditions))
}

async function aDesReponses(db: SupabaseClient, nodeId: string, vars: Variables): Promise<boolean> {
  const choix = await chargerChoix(db, nodeId)
  return choix.some((c) =>
    c.after_position === null && c.kind !== 'interaction' && evaluerConditions(vars, c.conditions))
}

/**
 * Prochaine pause du nœud : la plus petite `after_position` encore devant nous.
 *
 * `null` = plus aucune pause, le nœud peut se dérouler jusqu'au bout.
 */
async function prochainePause(
  db: SupabaseClient, nodeId: string, vars: Variables, curseur: number,
): Promise<number | null> {
  const positions = (await chargerChoix(db, nodeId))
    .filter((c) =>
      c.after_position !== null && c.after_position >= curseur &&
      evaluerConditions(vars, c.conditions))
    .map((c) => c.after_position as number)
  return positions.length ? Math.min(...positions) : null
}

/**
 * Entre dans un nœud et déroule la chaîne des transitions automatiques.
 *
 * S'arrête sur :
 *   • un nœud qui propose des choix reply/ignore      -> on attend le joueur
 *   • un nœud avec une interaction encore disponible  -> RÈGLE D'ARRÊT SUR INTERACTION
 *     (sans elle, les interactions cachées des nœuds auto-enchaînés — N13, N16,
 *      N21 — seraient traversées avant que le joueur ait pu agir)
 *   • un ai_moment    -> saisie libre (prompt 3)
 *   • un chapter_end  -> pose chapter_unlocked_at
 */
export function entrerDansNoeud(
  db: SupabaseClient,
  progression: Progression,
  nodeId: string,
): Promise<{ progression: Progression; messages: MessageEcrit[] }> {
  return derouler(db, progression, nodeId, 0)
}

async function derouler(
  db: SupabaseClient,
  progression: Progression,
  nodeId: string,
  curseurInitial: number,
): Promise<{ progression: Progression; messages: MessageEcrit[] }> {
  let vars = progression.variables
  let courant: string | null = nodeId
  let unlockedAt = progression.chapter_unlocked_at
  let curseur = curseurInitial
  let pauseOuverte: number | null = null
  const messages: MessageEcrit[] = []

  for (let i = 0; courant && i < MAX_ENCHAINEMENTS; i++) {
    const noeud: NoeudBrut = await chargerNoeud(db, courant)

    // Effets portés par le nœud lui-même : refus (N11), reveal_contact (N5, N7).
    // Sautés sur une REPRISE en cours de nœud : on n'y entre pas deux fois.
    if (!(i === 0 && curseurInitial > 0)) {
      vars = appliquerPlafonds(appliquerEffects(vars, noeud.effects))
    }

    // On ne délivre que jusqu'à la prochaine pause : au-delà, des choix
    // attendent le joueur au milieu du nœud.
    const pause = await prochainePause(db, noeud.id, vars, curseur)
    const lot = await ecrireMessagesDuNoeud(
      db, progression.id, noeud.id, vars, curseur, pause ?? Number.MAX_SAFE_INTEGER)
    messages.push(...lot.messages)

    if (pause !== null) {
      curseur = pause + 1
      pauseOuverte = pause
      break
    }
    // Tous les messages du nœud sont sortis. Le curseur passe DERRIÈRE la
    // dernière position : sinon une pause déjà jouée se rouvrirait au tour
    // suivant, et le joueur revivrait le même micro-choix.
    curseur = lot.finPosition + 1

    if (noeud.kind === 'ai_moment') {
      // On entre dans un moment IA : le décompte repart de zéro. Sans ça, un
      // second moment hériterait des échanges du premier.
      await db.from('player_progress').update({ ai_exchanges: 0 }).eq('id', progression.id)
      break
    }
    if (noeud.kind === 'chapter_end') {
      unlockedAt = await calculerDeblocage(db, progression.story_id, noeud.chapter_id)
      break
    }
    if (await aDesReponses(db, noeud.id, vars)) break
    if (await interactionDisponible(db, noeud.id, vars)) break
    if (!noeud.next_node_id) break

    courant = noeud.next_node_id
    curseur = 0 // nouveau nœud, nouveau déroulé
  }

  const { error } = await db.from('player_progress')
    .update({
      current_node_id: courant,
      variables: vars,
      chapter_unlocked_at: unlockedAt,
      node_cursor: curseur,
      node_gate: pauseOuverte,
    })
    .eq('id', progression.id)
  if (error) throw new ErreurMoteur(500, 'maj_impossible', error.message)

  return {
    progression: {
      ...progression,
      current_node_id: courant,
      variables: vars,
      chapter_unlocked_at: unlockedAt,
      node_cursor: curseur,
      node_gate: pauseOuverte,
    },
    messages: await signerMedias(db, messages),
  }
}

/**
 * Reprend le déroulé du nœud courant, là où une pause l'avait arrêté.
 *
 * Appelée après un micro-choix : le joueur a répondu, la suite des messages
 * peut sortir. Même code que l'entrée dans un nœud, à ceci près qu'on ne
 * réapplique pas les effects du nœud — on n'y entre pas une seconde fois.
 */
export function poursuivreDansNoeud(
  db: SupabaseClient,
  progression: Progression,
): Promise<{ progression: Progression; messages: MessageEcrit[] }> {
  if (!progression.current_node_id) {
    throw new ErreurMoteur(409, 'progression_corrompue', 'Aucun nœud courant')
  }
  return derouler(db, progression, progression.current_node_id, progression.node_cursor ?? 0)
}

/**
 * Délivre les messages d'un nœud entre deux positions, bornes comprises.
 *
 * Renvoie aussi la dernière position vue, y compris quand la tranche est vide :
 * l'appelant en a besoin pour poser le curseur derrière la fin du nœud.
 */
async function ecrireMessagesDuNoeud(
  db: SupabaseClient, progressId: string, nodeId: string, vars: Variables,
  depuis = 0, jusqua = Number.MAX_SAFE_INTEGER,
): Promise<{ messages: MessageEcrit[]; finPosition: number }> {
  const { data, error } = await db
    .from('messages')
    .select('position, contact_id, content_type, body, media_url, delay_seconds, typing_seconds, push_notification, push_text, phantom_typing_at, haptic_at, conditions')
    .eq('node_id', nodeId).order('position')
  if (error) throw new ErreurMoteur(500, 'erreur_base', error.message)

  const tous = data ?? []
  // La DERNIÈRE position du nœud, condition ou pas : c'est un repère de
  // curseur, pas un index — un message qui ne passe pas sa condition ne doit
  // pas raccourcir la portée du nœud pour autant.
  const finPosition = tous.length ? Number(tous[tous.length - 1].position) : depuis - 1
  const tranche = tous.filter((m) =>
    m.position >= depuis && m.position <= jusqua && evaluerConditions(vars, m.conditions))

  const messages = await ecrire(db, progressId, tranche.map((m) => ({
    contact_id: m.contact_id,
    sender: 'contact' as const,
    content_type: m.content_type,
    body: m.body,
    media_url: m.media_url,
    source: 'scripted',
    delay_seconds: m.delay_seconds,
    typing_seconds: m.typing_seconds,
    push_notification: m.push_notification,
    push_text: m.push_text,
    phantom_typing_at: m.phantom_typing_at,
    haptic_at: m.haptic_at,
  })))
  return { messages, finPosition }
}

/** chapter_unlocked_at = now() + délai du chapitre SUIVANT (stub compris). */
async function calculerDeblocage(
  db: SupabaseClient, storyId: string, chapterId: string,
): Promise<string | null> {
  const { data: actuel } = await db
    .from('chapters').select('position').eq('id', chapterId).single()
  if (!actuel) return null

  const { data: suivant } = await db
    .from('chapters').select('unlock_delay_minutes')
    .eq('story_id', storyId).eq('position', actuel.position + 1).maybeSingle()

  const minutes = suivant?.unlock_delay_minutes ?? 0
  return new Date(Date.now() + minutes * 60_000).toISOString()
}

// ---------------------------------------------------------------------------
// Construction de la réponse client (filtrage anti-spoiler)
// ---------------------------------------------------------------------------

/**
 * Le nœud courant tel que le client a le droit de le voir.
 * Ne sortent jamais : next_node_id, effects, conditions, ni les choix verrouillés.
 */
export async function etatNoeud(
  db: SupabaseClient, nodeId: string | null, vars: Variables, pauseCourante: number | null = null,
): Promise<ClientNode | null> {
  if (!nodeId) return null
  const noeud = await chargerNoeud(db, nodeId)
  const tous = await chargerChoix(db, nodeId)

  // Seule la pause où le déroulé s'est arrêté est ouverte. Les autres sont
  // derrière nous ou devant. `after_position` nul = les choix de fin de nœud.
  const ouverts = tous.filter((c) =>
    c.after_position === pauseCourante && evaluerConditions(vars, c.conditions))

  // ⚠️ `micro` est renvoyé comme `reply`. Le client ne doit JAMAIS pouvoir
  // distinguer un choix qui ramifie d'un choix qui n'enregistre qu'une posture
  // — s'il le pouvait, le joueur saurait quels moments comptent, et la
  // grammaire des trois axes ne mesurerait plus rien de sincère.
  const visible = (c: ChoixBrut): ClientChoice => ({
    id: c.id,
    position: c.position,
    label: c.label,
    kind: c.kind === 'micro' ? 'reply' : c.kind,
  })

  const reponses = ouverts.filter((c) => c.kind !== 'interaction').map(visible)
  const interactions = ouverts.filter((c) => c.kind === 'interaction').map(visible)

  return {
    code: noeud.code,
    kind: noeud.kind,
    choices: [...reponses, ...interactions],
    awaiting_interaction: reponses.length === 0 && interactions.length > 0,
    can_continue: reponses.length === 0 && pauseCourante === null &&
      (noeud.kind === 'ai_moment' ? noeud.ai_fallback_node_id !== null : noeud.next_node_id !== null),
  }
}

/** Conversations du joueur : dérivées des contacts déjà croisés dans l'historique. */
export async function conversations(
  db: SupabaseClient, progressId: string, storyId: string, vars: Variables,
): Promise<ClientConversation[]> {
  const { data: vus } = await db
    .from('player_messages').select('contact_id').eq('progress_id', progressId)
  const ids = [...new Set((vus ?? []).map((v) => v.contact_id))]
  if (ids.length === 0) return []

  const { data: contacts } = await db
    .from('contacts')
    .select('id, code, display_name, display_name_initial, avatar_url, phone_number')
    .eq('story_id', storyId).in('id', ids)

  const signes = await Promise.all((contacts ?? []).map(async (c) => {
    const { display_name, revealed } = nomAffiche(c, vars)
    return {
      contact_id: c.id,
      code: c.code,
      display_name,
      phone_number: c.phone_number,
      avatar_url: await signerObjet(db, avatarDe(c, vars)),
      revealed,
    }
  }))
  return signes
}

export async function etatFinDeChapitre(
  db: SupabaseClient, progression: Progression, nodeCode: string | null, kind: string | null,
): Promise<ChapterEndState | null> {
  if (kind !== 'chapter_end' || !progression.current_node_id) return null

  const noeud = await chargerNoeud(db, progression.current_node_id)
  const { data: actuel } = await db
    .from('chapters').select('position, title').eq('id', noeud.chapter_id).single()
  const { data: suivant } = await db
    .from('chapters').select('title, entry_node_id')
    .eq('story_id', progression.story_id).eq('position', (actuel?.position ?? 1) + 1).maybeSingle()

  return {
    chapter_title: actuel?.title ?? '',
    next_chapter_title: suivant?.title ?? null,
    unlocked_at: progression.chapter_unlocked_at,
    // Le chapitre suivant existe (stub) mais n'a pas encore de contenu.
    next_chapter_pending: suivant != null && suivant.entry_node_id == null,
  }
}

/**
 * Contact du fil dans lequel se déroule un nœud.
 * C'est le locuteur de ses messages — au ch. 1 toujours Léna, mais dès le ch. 3
 * un nœud pourra appartenir au fil de Karim ou du suspect.
 */
export async function contactDuNoeud(db: SupabaseClient, nodeId: string): Promise<string> {
  const { data } = await db
    .from('messages').select('contact_id').eq('node_id', nodeId).order('position').limit(1).maybeSingle()
  if (data?.contact_id) return data.contact_id
  throw new ErreurMoteur(500, 'fil_indetermine', `Le nœud ${nodeId} n'a aucun message : fil inconnu`)
}

/**
 * Transforme les chemins d'objets en URLs signées.
 *
 * Le bucket est privé : `messages.media_url` contient un chemin
 * (« photo-N16-plaque.jpg »), pas une URL. On ne signe que les médias des
 * messages que le joueur a **déjà reçus** — le contenu à venir reste
 * inatteignable, comme le reste du graphe.
 *
 * Les placeholders (`placeholder://…`) traversent tels quels : le client sait
 * les reconnaître et affiche un cartouche de repli.
 */
async function signerMedias<T extends { media_url: string | null }>(
  db: SupabaseClient,
  messages: T[],
): Promise<T[]> {
  const chemins = [...new Set(
    messages
      .map((m) => m.media_url)
      .filter((u): u is string => !!u && !u.startsWith('placeholder://')),
  )]
  if (chemins.length === 0) return messages

  const { data, error } = await db.storage
    .from('media')
    .createSignedUrls(chemins, DUREE_URL_SIGNEE)
  if (error) {
    // Un média illisible ne doit pas faire tomber toute la conversation :
    // le client retombera sur son cartouche de repli.
    console.error('Signature des médias impossible :', error.message)
    return messages
  }

  // On ne renvoie que le CHEMIN signé, pas une URL absolue : à l'intérieur du
  // réseau Docker, Supabase se signe lui-même sur « http://kong:8000 », un
  // hôte que ni un téléphone ni un émulateur ne sait résoudre. Le client
  // préfixe avec sa propre base — ce qui règle aussi, gratuitement, le cas de
  // l'émulateur Android et de son 10.0.2.2.
  const parChemin = new Map(
    (data ?? [])
      .filter((d) => d.signedUrl)
      .map((d) => [d.path ?? '', relativiser(d.signedUrl!)]),
  )
  return messages.map((m) =>
    m.media_url && parChemin.has(m.media_url)
      ? { ...m, media_url: parChemin.get(m.media_url)! }
      : m
  )
}

/** « http://kong:8000/storage/v1/… » -> « /storage/v1/… ». */
function relativiser(url: string): string {
  const i = url.indexOf('/storage/v1/')
  return i === -1 ? url : url.slice(i)
}

/** Signe un objet du bucket média, s'il est renseigné. */
export async function signerObjet(
  db: SupabaseClient,
  chemin: string | null,
): Promise<string | null> {
  if (!chemin) return null
  const { data } = await db.storage.from('media').createSignedUrl(chemin, DUREE_URL_SIGNEE)
  return data?.signedUrl ? relativiser(data.signedUrl) : null
}

/** Assez long pour une session de jeu, assez court pour ne pas circuler. */
const DUREE_URL_SIGNEE = 60 * 60 * 6 // 6 h

export async function historique(
  db: SupabaseClient, progressId: string,
): Promise<MessageEcrit[]> {
  const { data, error } = await db
    .from('player_messages')
    .select('seq, contact_id, sender, content_type, body, media_url')
    .eq('progress_id', progressId).order('seq')
  if (error) throw new ErreurMoteur(500, 'erreur_base', error.message)

  // L'historique se rejoue instantanément : pas de re-timing de ce qui a déjà été vu.
  const messages = (data ?? []).map((m) => ({
    seq: Number(m.seq),
    contact_id: m.contact_id,
    sender: m.sender,
    content_type: m.content_type,
    body: m.body,
    media_url: m.media_url,
    delay_seconds: 0,
    typing_seconds: 0,
    push_notification: false,
    push_text: null,
    phantom_typing_at: null,
    haptic_at: null,
  }))
  return await signerMedias(db, messages)
}

export { chargerChoix, signerMedias, evaluerConditions, appliquerEffects, appliquerPlafonds }
