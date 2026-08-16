// reveal-contact — le joueur enregistre un contact.
//
// Entrée : POST { contact_code: 'lena' }   Sortie : { conversations: [...] }
//
// **Ce n'est pas un choix narratif.** Aucun nœud ne bouge, aucune variable de
// jeu n'est touchée : on ajoute simplement le contact à `contacts_reveles`,
// exactement ce que faisait l'effect `reveal_contact`. Le geste remplace
// l'automatisme, il ne le double pas.
//
// Garde-fou : on n'accepte que les contacts dont une carte d'enregistrement a
// DÉJÀ été délivrée au joueur. Sans lui, un client modifié pourrait nommer le
// suspect du chapitre 4 avant de l'avoir rencontré — un spoiler gratuit dans
// une architecture qui en interdit partout ailleurs.

import { json, servir } from '../_shared/http.ts'
import {
  appliquerEffects,
  chargerHistoire,
  chargerOuCreerProgression,
  clientAdmin,
  conversations,
  ErreurMoteur,
  utilisateurCourant,
} from '../_shared/moteur.ts'

Deno.serve(servir(async (req) => {
  const userId = await utilisateurCourant(req)
  const db = clientAdmin()

  const corps = await req.json().catch(() => ({})) as { contact_code?: string }
  const code = corps.contact_code
  if (!code) throw new ErreurMoteur(400, 'requete_invalide', 'contact_code attendu')

  const histoire = await chargerHistoire(db)
  const { progression } = await chargerOuCreerProgression(db, userId, histoire.id)

  const { data: contact } = await db
    .from('contacts').select('id, code')
    .eq('story_id', histoire.id).eq('code', code).maybeSingle()
  if (!contact) throw new ErreurMoteur(403, 'contact_inconnu', 'Contact introuvable')

  // La carte a-t-elle été délivrée ? C'est la seule preuve que le joueur a
  // bien rencontré ce contact.
  const { count } = await db
    .from('player_messages')
    .select('id', { count: 'exact', head: true })
    .eq('progress_id', progression.id)
    .eq('contact_id', contact.id)
    .eq('content_type', 'contact_card')
  if (!count) {
    throw new ErreurMoteur(403, 'carte_absente', 'Aucune carte reçue pour ce contact')
  }

  const variables = appliquerEffects(progression.variables, { reveal_contact: code })
  const { error } = await db
    .from('player_progress').update({ variables }).eq('id', progression.id)
  if (error) throw new ErreurMoteur(500, 'maj_impossible', error.message)

  return json({
    conversations: await conversations(db, progression.id, histoire.id, variables),
  })
}))
