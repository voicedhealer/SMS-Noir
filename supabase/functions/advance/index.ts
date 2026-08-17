// advance — le joueur agit.
//
// Entrée : POST { choice_id: uuid }   applique un choix
//          POST { continue: true }    franchit une transition automatique
//                                     (nœud en pause sur interaction, ou nœud
//                                      sans choix que le joueur veut quitter)
// Sortie : AdvanceResponse (voir _shared/types.ts)
//
// Séquence : valider -> écrire le message joueur -> appliquer les effects du
// choix -> entrer dans le nœud suivant (qui applique SES effects et déroule la
// chaîne). Voir docs/LOGIQUE.md § Cycle de vie d'un nœud.

import type { SupabaseClient } from 'jsr:@supabase/supabase-js@2'
import { json, servir } from '../_shared/http.ts'
import {
  appliquerEffects,
  appliquerPlafonds,
  chargerChoix,
  chargerHistoire,
  chargerNoeud,
  chargerOuCreerProgression,
  clientAdmin,
  contactDuNoeud,
  conversations,
  ecrireInlineResponse,
  ecrireMessageJoueur,
  entrerDansNoeud,
  poursuivreDansNoeud,
  ErreurMoteur,
  etatFinDeChapitre,
  etatNoeud,
  evaluerConditions,
  type MessageEcrit,
  type Progression,
  signerMedias,
  utilisateurCourant,
} from '../_shared/moteur.ts'
import type { AdvanceResponse } from '../_shared/types.ts'

Deno.serve(servir(async (req) => {
  const userId = await utilisateurCourant(req)
  const db = clientAdmin()

  const corps = await req.json().catch(() => ({})) as { choice_id?: string; continue?: boolean }
  if (!corps.choice_id && corps.continue !== true) {
    throw new ErreurMoteur(400, 'requete_invalide', 'choice_id ou continue attendu')
  }

  const histoire = await chargerHistoire(db)
  const { progression: initiale } = await chargerOuCreerProgression(db, userId, histoire.id)

  if (!initiale.current_node_id) {
    throw new ErreurMoteur(409, 'progression_corrompue', 'Aucun nœud courant')
  }
  const noeudCourant = await chargerNoeud(db, initiale.current_node_id)

  const resultat = corps.continue === true
    ? await franchirTransition(db, initiale, noeudCourant)
    : await appliquerChoix(db, initiale, noeudCourant, corps.choice_id!)

  const { progression, messages, rejeu } = resultat
  const noeudFinal = progression.current_node_id
    ? await chargerNoeud(db, progression.current_node_id)
    : null

  const reponse: AdvanceResponse = {
    new_messages: messages,
    node: await etatNoeud(db, progression.current_node_id, progression.variables, progression.node_gate),
    conversations: await conversations(db, progression.id, histoire.id, progression.variables),
    chapter_end: await etatFinDeChapitre(db, progression, noeudFinal?.code ?? null, noeudFinal?.kind ?? null),
    ai_moment_pending: noeudFinal?.kind === 'ai_moment',
    idempotent_replay: rejeu,
  }
  return json(reponse)
}))

interface Resultat {
  progression: Progression
  messages: MessageEcrit[]
  rejeu: boolean
}

interface NoeudCourant {
  id: string
  kind: 'scripted' | 'ai_moment' | 'chapter_end'
  next_node_id: string | null
  ai_fallback_node_id: string | null
}

// ---------------------------------------------------------------------------

/** `continue: true` — franchir la transition automatique du nœud courant. */
async function franchirTransition(
  db: SupabaseClient,
  progression: Progression,
  noeud: NoeudCourant,
): Promise<Resultat> {
  const choix = await chargerChoix(db, noeud.id)
  const reponses = choix.filter(
    (c) => c.kind !== 'interaction' &&
      (c.after_position ?? null) === (progression.node_gate ?? null) &&
      evaluerConditions(progression.variables, c.conditions),
  )
  // Un nœud qui propose des réponses ne se franchit pas tout seul : le joueur doit choisir.
  if (reponses.length > 0) {
    throw new ErreurMoteur(409, 'choix_attendu', 'Ce nœud attend un choix, pas une continuation')
  }

  // Un ai_moment se franchit par son fallback. C'est le chemin prévu quand l'IA
  // est indisponible ; le joueur y perd seulement le gain de confiance du N9.
  // L'exécution IA elle-même arrive au prompt 3.
  const suite = noeud.kind === 'ai_moment' ? noeud.ai_fallback_node_id : noeud.next_node_id
  if (!suite) {
    throw new ErreurMoteur(409, 'sans_suite', 'Ce nœud n\'a pas de transition automatique')
  }

  const { progression: apres, messages } = await entrerDansNoeud(db, progression, suite)
  return { progression: apres, messages, rejeu: false }
}

/** Applique un choix : validations, effects, écriture, transition. */
async function appliquerChoix(
  db: SupabaseClient,
  progression: Progression,
  noeud: NoeudCourant,
  choiceId: string,
): Promise<Resultat> {
  // --- Idempotence -----------------------------------------------------
  // Rejeu du même choix (retransmission réseau) : on ne réapplique rien et on
  // renvoie à l'identique les messages produits la première fois. Sans ça, le
  // second appel serait rejeté — le choix n'appartient plus au nœud courant.
  if (progression.last_choice_id === choiceId) {
    return { progression, messages: await messagesDuDernierCoup(db, progression), rejeu: true }
  }

  // --- Validations -----------------------------------------------------
  const choixDuNoeud = await chargerChoix(db, noeud.id)
  const choix = choixDuNoeud.find((c) => c.id === choiceId)
  if (!choix) {
    // Le choix existe peut-être ailleurs dans le graphe : même réponse dans les
    // deux cas, pour ne rien révéler de sa structure.
    throw new ErreurMoteur(403, 'choix_invalide', 'Ce choix n\'appartient pas au nœud courant')
  }
  if (!evaluerConditions(progression.variables, choix.conditions)) {
    throw new ErreurMoteur(403, 'choix_verrouille', 'Les conditions de ce choix ne sont pas remplies')
  }
  // Le choix doit appartenir à la pause OUVERTE, pas à une autre du même nœud.
  // Sans ce garde-fou, un client pourrait rejouer un micro-choix déjà passé ou
  // sauter par-dessus la suite du nœud.
  if ((choix.after_position ?? null) !== (progression.node_gate ?? null)) {
    throw new ErreurMoteur(403, 'choix_hors_pause', 'Ce choix n\'est pas ouvert en ce moment')
  }

  const contact = await contactDuNoeud(db, noeud.id)
  const messages: MessageEcrit[] = []

  // --- Message du joueur -----------------------------------------------
  // « Ignorer » n'écrit rien : le joueur n'a rien dit, il avance quand même.
  // Une interaction non plus : sa réplique, s'il y en a une, est dans l'inline_response.
  if (choix.kind === 'reply' || choix.kind === 'micro') {
    messages.push(
      ...await ecrireMessageJoueur(db, progression.id, contact, choix.label, 'player_choice'),
    )
  }

  // --- Effects du choix -------------------------------------------------
  const vars = appliquerPlafonds(appliquerEffects(progression.variables, choix.effects))
  let courante: Progression = { ...progression, variables: vars }

  if (choix.next_node_id) {
    // Transition : le nœud atteint appliquera SES propres effects (refus, reveal_contact).
    const apres = await entrerDansNoeud(db, courante, choix.next_node_id)
    courante = apres.progression
    messages.push(...apres.messages)
  } else if (choix.kind === 'micro') {
    // Micro-choix : la variante de réplique de Léna, puis le nœud REPREND là
    // où la pause l'avait arrêté. Le nœud ne change pas, mais le déroulé
    // continue — c'est ce qui distingue un micro-choix d'une interaction.
    messages.push(...await signerMedias(
      db, await ecrireInlineResponse(db, progression.id, contact, choix.inline_response)))
    const { error } = await db.from('player_progress')
      .update({ variables: vars }).eq('id', progression.id)
    if (error) throw new ErreurMoteur(500, 'maj_impossible', error.message)

    const apres = await poursuivreDansNoeud(db, courante)
    courante = apres.progression
    messages.push(...apres.messages)
  } else {
    // Interaction sur place : le nœud courant ne change pas.
    messages.push(...await signerMedias(
      db, await ecrireInlineResponse(db, progression.id, contact, choix.inline_response)))
    const { error } = await db.from('player_progress')
      .update({ variables: vars }).eq('id', progression.id)
    if (error) throw new ErreurMoteur(500, 'maj_impossible', error.message)

    // Plus aucune interaction disponible, aucune réponse à donner, et le nœud
    // enchaîne tout seul : on poursuit, sinon le joueur resterait bloqué.
    //
    // On ne compte que les choix de FIN de nœud. Les micro-choix du même nœud
    // sont derrière nous — leur pause est refermée — et les compter ici
    // laisserait le joueur bloqué sur un nœud qui n'a plus rien à offrir.
    const encoreOuverts = choixDuNoeud.filter((c) =>
      c.after_position === null && evaluerConditions(vars, c.conditions))
    if (encoreOuverts.length === 0 && noeud.next_node_id) {
      const apres = await entrerDansNoeud(db, courante, noeud.next_node_id)
      courante = apres.progression
      messages.push(...apres.messages)
    }
  }

  // --- Trace d'idempotence ---------------------------------------------
  const premierSeq = messages[0]?.seq ?? null
  const { error } = await db.from('player_progress')
    .update({ last_choice_id: choiceId, last_choice_seq: premierSeq })
    .eq('id', progression.id)
  if (error) throw new ErreurMoteur(500, 'maj_impossible', error.message)

  return {
    progression: { ...courante, last_choice_id: choiceId, last_choice_seq: premierSeq },
    messages,
    rejeu: false,
  }
}

/** Rejoue la réponse du dernier coup, à partir de son curseur `last_choice_seq`. */
async function messagesDuDernierCoup(
  db: SupabaseClient,
  progression: Progression,
): Promise<MessageEcrit[]> {
  if (progression.last_choice_seq == null) return []
  const { data, error } = await db
    .from('player_messages')
    .select('seq, contact_id, sender, content_type, body, media_url')
    .eq('progress_id', progression.id)
    .gte('seq', progression.last_choice_seq)
    .order('seq')
  if (error) throw new ErreurMoteur(500, 'erreur_base', error.message)

  const messages = (data ?? []).map((m) => ({
    seq: Number(m.seq),
    contact_id: m.contact_id,
    sender: m.sender,
    content_type: m.content_type,
    body: m.body,
    media_url: m.media_url,
    // Rejeu : les délais ont déjà été joués au premier appel.
    delay_seconds: 0,
    typing_seconds: 0,
    push_notification: false,
    push_text: null,
    phantom_typing_at: null,
    haptic_at: null,
  }))
  return await signerMedias(db, messages)
}
