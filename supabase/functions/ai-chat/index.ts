// ai-chat — le moment de saisie libre du N9.
//
// Entrée : POST { message: string }
//          POST { consent: true | false }   (réponse à l'écran de consentement)
//
// **Le mode dégradé prime sur la fonctionnalité.** Clé absente, API en erreur,
// timeout, quota atteint, JSON illisible : Léna raccroche en personnage et
// l'histoire repart au fallback (`ai_fallback_node_id`). Jamais de message
// d'erreur technique, jamais de blocage.
//
// Le consentement refusé est un cas à part, pas une panne : si le nœud
// désigne un équivalent scripté (`ai_refus_node_id`), on y entre directement
// — pas de raccrochage générique, l'équivalent porte sa propre ouverture et
// sa propre clôture. Voir docs/LOGIQUE.md § Le moment IA et
// § Le refus de consentement à un moment IA.

import { json, servir } from '../_shared/http.ts'
import {
  appliquerEffects,
  appliquerPlafonds,
  chargerHistoire,
  chargerNoeud,
  chargerOuCreerProgression,
  clientAdmin,
  contactDuNoeud,
  conversations,
  ecrireMessageJoueur,
  entrerDansNoeud,
  ErreurMoteur,
  etatFinDeChapitre,
  etatNoeud,
  type MessageEcrit,
  type Progression,
  utilisateurCourant,
} from '../_shared/moteur.ts'
import { EFFETS_TONALITE, filtrerDetail, sortDuCadre } from '../_shared/ai_garde_fous.ts'
import {
  type Echange,
  ErreurFournisseur,
  type FournisseurIA,
  fournisseur as choisirFournisseur,
} from '../_shared/ai_provider.ts'

/** Quota par joueur et par jour, toutes histoires confondues. */
const QUOTA_QUOTIDIEN = 50

/**
 * Ses répliques de sortie. Elles restent en personnage, toujours.
 *
 * Deux variantes pour le raccrochage normal, choisies par `raccrochage()`
 * selon `refus` — pas de branchement tu/vous pour `COUPURE`, hors du
 * périmètre demandé (hostilité/hors-cadre, pas la clôture normale).
 */
const RACCROCHAGE_TU =
  'Tu as raison. Je crois que je vais aller me coucher, essayer de dormir un peu. ' +
  'Envoie-moi un message demain si tu veux, pour savoir comment ça va de mon côté. Merci encore.'
const RACCROCHAGE_VOUS =
  'Vous avez raison. Je crois que je vais aller me coucher, essayer de dormir un peu. ' +
  'Envoyez-moi un message demain si vous voulez, pour savoir comment ça va de mon côté. Merci encore.'
const COUPURE = 'Ok. Laisse tomber. Je rentre.'

/** Choisit la variante tu/vous du raccrochage selon la variable `refus`. */
function raccrochage(variables: Progression['variables']): string {
  return variables.refus === true ? RACCROCHAGE_VOUS : RACCROCHAGE_TU
}

Deno.serve(servir(async (req) => {
  const userId = await utilisateurCourant(req)
  const db = clientAdmin()
  const corps = await req.json().catch(() => ({})) as {
    message?: string
    consent?: boolean
  }

  const histoire = await chargerHistoire(db)
  const { progression } = await chargerOuCreerProgression(db, userId, histoire.id)

  // --- Consentement ---------------------------------------------------------
  // Indépendant du nœud courant : demandé depuis la carte d'entrée, AVANT
  // l'intronisation, pas seulement à la première saisie libre du N9. Doit
  // donc pouvoir s'enregistrer alors que le joueur est encore au nœud
  // d'entrée (N1) — avant tout `ai_moment`. Le repli ci-dessous
  // (`!progression.ai_consent_at` -> `consent_required`) reste en place pour
  // une progression antérieure à cette carte, mais ne devrait plus se
  // déclencher en usage normal.
  if (corps.consent !== undefined) {
    return json(await enregistrerConsentement(db, progression, histoire.id, corps.consent))
  }

  if (!progression.current_node_id) {
    throw new ErreurMoteur(409, 'progression_corrompue', 'Aucun nœud courant')
  }

  const noeud = await chargerNoeud(db, progression.current_node_id)
  if (noeud.kind !== 'ai_moment') {
    throw new ErreurMoteur(409, 'pas_un_moment_ia', 'Le nœud courant n\'attend pas de saisie libre')
  }

  if (progression.ai_consent_refuse) {
    // Il a dit non : on ne redemande pas, et il n'est pas pénalisé.
    //
    // Chemin de repli seulement : `derouler()` détourne normalement une
    // progression dont le consentement est déjà refusé AVANT même d'exposer
    // ce composer (voir moteur.ts, la branche ai_moment de derouler), donc ce
    // code ne devrait plus s'exécuter en usage normal. Gardé pour une
    // progression antérieure à ce mécanisme. Distinct d'une panne technique :
    // si un équivalent scripté existe, on y entre directement (pas de
    // réplique de raccrochage, l'équivalent porte sa propre ouverture) ;
    // sinon, comportement historique inchangé.
    if (noeud.ai_refus_node_id) {
      return json(await entrerNoeudEtRepondre(db, progression, histoire.id, noeud.ai_refus_node_id))
    }
    return json(await raccrocher(db, progression, histoire.id, noeud, raccrochage(progression.variables)))
  }
  if (!progression.ai_consent_at) {
    return json({ consent_required: true })
  }

  const message = (corps.message ?? '').trim()
  if (!message) throw new ErreurMoteur(400, 'requete_invalide', 'message attendu')
  if (message.length > 500) {
    throw new ErreurMoteur(400, 'message_trop_long', 'Message trop long')
  }

  const contact = await contactDuNoeud(db, noeud.id)
  // Ce qu'il écrit s'affiche toujours, quoi qu'il arrive ensuite.
  const messagesJoueur = await ecrireMessageJoueur(
    db, progression.id, contact, message, 'player_free')

  // --- Pré-filtre : une injection n'atteint jamais le modèle ---------------
  if (sortDuCadre(message)) {
    console.log('[ai-chat] hors cadre détecté côté serveur')
    return json(await raccrocher(db, progression, histoire.id, noeud, COUPURE, messagesJoueur))
  }

  // --- Quota --------------------------------------------------------------
  const usage = await lireUsage(db, userId)
  if (usage.exchanges >= QUOTA_QUOTIDIEN) {
    console.log('[ai-chat] quota quotidien atteint')
    return json(await raccrocher(
      db, progression, histoire.id, noeud, raccrochage(progression.variables), messagesJoueur))
  }

  // --- Appel du modèle ----------------------------------------------------
  const fournisseur: FournisseurIA = choisirFournisseur()
  const maxEchanges = noeud.ai_max_exchanges ?? 4
  const numero = progression.ai_exchanges + 1

  let resultat
  try {
    resultat = await fournisseur.repondre(
      await construireEchange(db, progression, noeud, contact, numero, maxEchanges))
  } catch (e) {
    // Clé absente, API en erreur, timeout, JSON illisible : elle raccroche.
    console.error('[ai-chat] fournisseur indisponible :', String(e))
    if (!(e instanceof ErreurFournisseur)) throw e
    return json(await raccrocher(
      db, progression, histoire.id, noeud, raccrochage(progression.variables), messagesJoueur))
  }

  const { contenu, tokensEntree, tokensSortie } = resultat
  await comptabiliser(db, userId, tokensEntree, tokensSortie)
  console.log(`[ai-chat] échange ${numero}/${maxEchanges} · ${contenu.tonalite} · ` +
    `${tokensEntree}+${tokensSortie} tokens`)

  // --- Effets, appliqués par le SERVEUR -----------------------------------
  let variables = appliquerPlafonds(
    appliquerEffects(progression.variables, EFFETS_TONALITE[contenu.tonalite]))

  const detail = filtrerDetail(contenu.detail)
  if (detail.motifRejet) console.log(`[ai-chat] detail_perso rejeté (${detail.motifRejet})`)

  const courante: Progression = { ...progression, variables }
  const messages = [...messagesJoueur]

  // Sa réponse s'affiche même si elle raccroche juste après.
  messages.push(...await ecrireReplique(db, progression.id, contact, contenu.reponse))

  // --- Suite ou raccrochage ------------------------------------------------
  const hostile = contenu.tonalite === 'hostile'
  const dernier = numero >= maxEchanges

  if (hostile || dernier) {
    return json(await raccrocher(
      db, courante, histoire.id, noeud, hostile ? COUPURE : raccrochage(variables), messages,
      detail.valeur, variables))
  }

  await db.from('player_progress').update({
    variables,
    ai_exchanges: numero,
    ...(detail.valeur ? { detail_perso: detail.valeur } : {}),
  }).eq('id', progression.id)

  return json({
    new_messages: messages,
    node: await etatNoeud(db, progression.current_node_id, variables, progression.node_gate),
    conversations: await conversations(db, progression.id, histoire.id, variables),
    chapter_end: null,
    ai_moment_pending: true,
    exchanges_left: maxEchanges - numero,
  })
}))

// ---------------------------------------------------------------------------

/**
 * Le contexte envoyé au modèle.
 *
 * Le prompt de la base est **générique** ; l'état de la partie est injecté ici,
 * dans un second message système. Le vouvoiement et le décompte sont de
 * l'état, pas du contenu — et le décompte n'est jamais laissé au modèle.
 */
async function construireEchange(
  // deno-lint-ignore no-explicit-any
  db: any,
  progression: Progression,
  noeud: { id: string; ai_system_prompt: string | null },
  contactId: string,
  numero: number,
  maxEchanges: number,
): Promise<Echange[]> {
  const refus = progression.variables.refus === true
  const etat = [
    refus
      ? 'Cet inconnu a refusé de t\'aider ce soir. Tu le VOUVOIES, et tu restes plus réservée.'
      : 'Cet inconnu t\'a aidée ce soir. Tu le tutoies.',
    `C'est le message ${numero} sur ${maxEchanges} de cet échange.`,
    numero >= maxEchanges - 1
      ? 'L\'échange touche à sa fin : commence à te détacher, sans le dire.'
      : '',
  ].filter(Boolean).join('\n')

  // L'historique de CE moment seulement : elle ne relit pas toute la soirée.
  const { data } = await db
    .from('player_messages')
    .select('sender, body, source')
    .eq('progress_id', progression.id)
    .eq('contact_id', contactId)
    .in('source', ['player_free', 'ai'])
    .order('seq')
    .limit(12)

  return [
    { role: 'system', content: noeud.ai_system_prompt ?? '' },
    { role: 'system', content: etat },
    ...(data ?? []).map((m: { sender: string; body: string }) => ({
      role: m.sender === 'player' ? ('user' as const) : ('assistant' as const),
      content: m.body ?? '',
    })),
  ]
}

/** Écrit une réplique de Léna dans le fil. */
async function ecrireReplique(
  // deno-lint-ignore no-explicit-any
  db: any,
  progressId: string,
  contactId: string,
  texte: string,
): Promise<MessageEcrit[]> {
  const { data } = await db.from('player_messages').insert({
    progress_id: progressId,
    contact_id: contactId,
    sender: 'contact',
    content_type: 'text',
    body: texte,
    source: 'ai',
  }).select('seq, contact_id, sender, content_type, body, media_url')

  return (data ?? []).map((m: Record<string, unknown>) => ({
    seq: Number(m.seq),
    contact_id: m.contact_id as string,
    sender: 'contact' as const,
    content_type: 'text' as const,
    body: m.body as string,
    media_url: null,
    // Un délai crédible : une réponse instantanée trahirait la machine.
    delay_seconds: 2,
    typing_seconds: 2,
    push_notification: false,
    push_text: null,
    phantom_typing_at: null,
    haptic_at: null,
  }))
}

/** Elle raccroche et l'histoire repart au fallback. */
async function raccrocher(
  // deno-lint-ignore no-explicit-any
  db: any,
  progression: Progression,
  storyId: string,
  noeud: { id: string; ai_fallback_node_id: string | null },
  replique: string,
  dejaEcrits: MessageEcrit[] = [],
  detailPerso: string | null = null,
  variables = progression.variables,
) {
  const contact = await contactDuNoeud(db, noeud.id)
  const messages = [...dejaEcrits, ...await ecrireReplique(db, progression.id, contact, replique)]

  const suite = noeud.ai_fallback_node_id
  if (!suite) throw new ErreurMoteur(409, 'sans_suite', 'Le moment IA n\'a pas de fallback')

  return entrerNoeudEtRepondre(
    db, { ...progression, variables }, storyId, suite, messages, detailPerso, variables)
}

/**
 * Quitte le moment IA en entrant dans un nœud — fallback technique ou
 * équivalent scripté d'un refus, même mécanique. Pose `ai_exchanges: 0` et
 * construit la réponse `ai-chat` (le contrat est le même dans les deux cas :
 * `ai_moment_pending: false`, la suite est un déroulé normal).
 */
async function entrerNoeudEtRepondre(
  // deno-lint-ignore no-explicit-any
  db: any,
  progression: Progression,
  storyId: string,
  nodeId: string,
  dejaEcrits: MessageEcrit[] = [],
  detailPerso: string | null = null,
  variables = progression.variables,
) {
  await db.from('player_progress').update({
    variables,
    ai_exchanges: 0, // remis à zéro : on quitte le moment
    ...(detailPerso ? { detail_perso: detailPerso } : {}),
  }).eq('id', progression.id)

  const apres = await entrerDansNoeud(db, progression, nodeId)
  const messages = [...dejaEcrits, ...apres.messages]

  const noeudFinal = apres.progression.current_node_id
    ? await chargerNoeud(db, apres.progression.current_node_id)
    : null

  return {
    new_messages: messages,
    node: await etatNoeud(db, apres.progression.current_node_id, apres.progression.variables, apres.progression.node_gate),
    conversations: await conversations(db, progression.id, storyId, apres.progression.variables),
    chapter_end: await etatFinDeChapitre(
      db, apres.progression, noeudFinal?.code ?? null, noeudFinal?.kind ?? null),
    ai_moment_pending: false,
    exchanges_left: 0,
  }
}

/**
 * Écrit la décision et rend la main.
 *
 * Le nœud courant n'est plus forcément un ai_moment : le consentement se
 * demande maintenant depuis la carte d'entrée, AVANT l'intronisation — le
 * joueur n'a alors encore rien commencé (nœud d'entrée). Mais le chemin de
 * repli existe toujours (progression antérieure à cette carte, ou saisie
 * directement au N9) : refuser alors qu'un moment IA attend une réponse
 * raccroche immédiatement, comme n'importe quelle sortie de cadre du moment —
 * il n'y a qu'à la carte d'entrée que « refuser » ne referme rien, puisque
 * rien n'est encore ouvert.
 */
async function enregistrerConsentement(
  // deno-lint-ignore no-explicit-any
  db: any,
  progression: Progression,
  storyId: string,
  accepte: boolean,
) {
  await db.from('player_progress').update(
    accepte
      ? { ai_consent_at: new Date().toISOString(), ai_consent_refuse: false }
      : { ai_consent_refuse: true },
  ).eq('id', progression.id)

  const noeud = progression.current_node_id
    ? await chargerNoeud(db, progression.current_node_id)
    : null

  if (!accepte && noeud?.kind === 'ai_moment') {
    return raccrocher(db, progression, storyId, noeud, raccrochage(progression.variables))
  }

  return {
    new_messages: [],
    node: await etatNoeud(db, progression.current_node_id, progression.variables, progression.node_gate),
    conversations: await conversations(db, progression.id, storyId, progression.variables),
    chapter_end: null,
    ai_moment_pending: noeud?.kind === 'ai_moment',
    exchanges_left: noeud?.kind === 'ai_moment' ? (noeud.ai_max_exchanges ?? 4) : 0,
  }
}

// deno-lint-ignore no-explicit-any
async function lireUsage(db: any, userId: string): Promise<{ exchanges: number }> {
  const { data } = await db
    .from('ai_usage').select('exchanges')
    .eq('user_id', userId).eq('day', new Date().toISOString().slice(0, 10)).maybeSingle()
  return { exchanges: data?.exchanges ?? 0 }
}

/** Un échange consommé, et son coût. */
async function comptabiliser(
  // deno-lint-ignore no-explicit-any
  db: any,
  userId: string,
  tokensEntree: number,
  tokensSortie: number,
) {
  const jour = new Date().toISOString().slice(0, 10)
  const { data } = await db
    .from('ai_usage').select('exchanges, tokens_in, tokens_out')
    .eq('user_id', userId).eq('day', jour).maybeSingle()

  await db.from('ai_usage').upsert({
    user_id: userId,
    day: jour,
    exchanges: (data?.exchanges ?? 0) + 1,
    tokens_in: (data?.tokens_in ?? 0) + tokensEntree,
    tokens_out: (data?.tokens_out ?? 0) + tokensSortie,
  })
}
