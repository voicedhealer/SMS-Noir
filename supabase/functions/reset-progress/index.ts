// reset-progress — efface la partie du joueur.
//
// Entrée : POST {}   Sortie : { ok: true }
//
// Supprime `player_progress`, ce qui cascade sur `player_messages` et sur
// `detail_perso`. Le joueur repart de zéro : nœud d'entrée, variables
// initiales, et l'intronisation se rejoue.
//
// C'est aussi la base du bouton « réinitialiser l'histoire » exigé par le RGPD
// (bible §9) : effacement des saisies libres à la demande. Pour l'instant elle
// n'est appelée que par l'outil de développement du client.

import { json, servir } from '../_shared/http.ts'
import {
  chargerHistoire,
  clientAdmin,
  ErreurMoteur,
  utilisateurCourant,
} from '../_shared/moteur.ts'

Deno.serve(servir(async (req) => {
  const userId = await utilisateurCourant(req)
  const db = clientAdmin()
  const histoire = await chargerHistoire(db)

  const { error } = await db
    .from('player_progress')
    .delete()
    .eq('user_id', userId)
    .eq('story_id', histoire.id)
  if (error) throw new ErreurMoteur(500, 'erreur_base', error.message)

  return json({ ok: true })
}))
