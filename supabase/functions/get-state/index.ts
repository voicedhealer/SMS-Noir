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
  carnet,
  chargerOuCreerProgression,
  clientAdmin,
  conversations,
  etatFinDeChapitre,
  etatNoeud,
  historique,
  signerObjet,
  utilisateurCourant,
} from '../_shared/moteur.ts'
import type { GetStateResponse } from '../_shared/types.ts'

Deno.serve(servir(async (req) => {
  const userId = await utilisateurCourant(req)
  const db = clientAdmin()

  const histoire = await chargerHistoire(db)
  const { progression, messagesInitiaux } = await chargerOuCreerProgression(db, userId, histoire.id)

  // Les messages écrits à l'instant (nœud d'entrée, première visite) doivent
  // être JOUÉS avec leurs délais, pas versés dans l'historique : sans ça, le
  // tout premier message de l'histoire apparaîtrait sans attente ni typing.
  const seqsAJouer = new Set(messagesInitiaux.map((m) => m.seq))

  const noeud = progression.current_node_id
    ? await chargerNoeud(db, progression.current_node_id)
    : null

  const reponse: GetStateResponse = {
    story: {
      slug: histoire.slug,
      title: histoire.title,
      tagline: histoire.tagline ?? null,
      cover_url: await signerObjet(db, histoire.cover_url),
    },
    intro: {
      panels: (histoire.intro_panels ?? []) as { lines: string[] }[],
      music_url: await signerObjet(db, histoire.intro_music_url),
      // Les deux autres segments du MÊME morceau, signés au même moment parce
      // qu'ils se chargent ensemble — même s'ils servent à d'autres écrans.
      narration_music_url: await signerObjet(db, histoire.narration_music_url),
      chapter_end_music_url: await signerObjet(db, histoire.chapter_end_music_url),
    },
    sounds: {
      received: await signerObjet(db, histoire.sound_received_url),
      sent: await signerObjet(db, histoire.sound_sent_url),
      typing: await signerObjet(db, histoire.sound_typing_url),
    },
    new_messages: messagesInitiaux,
    conversations: await conversations(db, progression.id, histoire.id, progression.variables),
    history: (await historique(db, progression.id)).filter((m) => !seqsAJouer.has(m.seq)),
    node: await etatNoeud(db, progression.current_node_id, progression.variables, progression.node_gate),
    chapter_end: await etatFinDeChapitre(db, progression, noeud?.code ?? null, noeud?.kind ?? null),
    clues: await carnet(db, histoire.id, progression.variables),
    // Le nœud courant est le moment IA : la saisie libre s'ouvre (exécution au prompt 3).
    ai_moment_pending: noeud?.kind === 'ai_moment',
    // Carte d'entrée (avant l'intronisation) : tant que ni l'un ni l'autre
    // n'est vrai, aucune décision n'a été prise, en base.
    ai_consent_decided: Boolean(progression.ai_consent_at) || progression.ai_consent_refuse === true,
  }

  return json(reponse)
}))
