// get-state — état complet du joueur.
//
// Entrée  : POST {}  (l'identité vient du JWT)
// Sortie  : GetStateResponse (voir _shared/types.ts et docs/LOGIQUE.md)
//
// Crée la progression à la première visite, entre dans le nœud d'entrée et
// déroule sa chaîne. Ne renvoie JAMAIS next_node_id, effects, conditions, ni
// les choix dont les conditions ne sont pas remplies.

import { servir, json } from '../_shared/http.ts'
import {
  chargerHistoire,
  chargerNoeud,
  chargerOuCreerProgression,
  clientAdmin,
  conversations,
  etatFinDeChapitre,
  etatNoeud,
  historique,
  utilisateurCourant,
} from '../_shared/moteur.ts'
import type { GetStateResponse } from '../_shared/types.ts'

Deno.serve(servir(async (req) => {
  const userId = await utilisateurCourant(req)
  const db = clientAdmin()

  const histoire = await chargerHistoire(db)
  const { progression } = await chargerOuCreerProgression(db, userId, histoire.id)

  const noeud = progression.current_node_id
    ? await chargerNoeud(db, progression.current_node_id)
    : null

  const reponse: GetStateResponse = {
    story: { slug: histoire.slug, title: histoire.title },
    conversations: await conversations(db, progression.id, histoire.id, progression.variables),
    history: await historique(db, progression.id),
    node: await etatNoeud(db, progression.current_node_id, progression.variables),
    chapter_end: await etatFinDeChapitre(db, progression, noeud?.code ?? null, noeud?.kind ?? null),
    // Le nœud courant est le moment IA : la saisie libre s'ouvre (exécution au prompt 3).
    ai_moment_pending: noeud?.kind === 'ai_moment',
  }

  return json(reponse)
}))
