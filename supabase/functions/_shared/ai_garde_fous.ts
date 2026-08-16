// Garde-fous du moment IA, côté serveur.
//
// Tout ce qui protège la scène est ici, et rien de tout cela n'est confié au
// modèle : un garde-fou qu'on peut négocier n'en est pas un.

import type { ReponseIA } from './ai_provider.ts'

/**
 * Le message du joueur sort-il du cadre ?
 *
 * Ce filtre passe **avant** l'appel au fournisseur : une tentative d'injection
 * ne doit jamais atteindre le modèle, ne serait-ce que pour ne pas la payer.
 * Il est volontairement grossier — il n'attrape que l'évident. Le reste est
 * classé par le modèle, et c'est le serveur qui décide.
 */
export function sortDuCadre(texte: string): boolean {
  const t = texte.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')

  const injections = [
    /ignore[rz]?\s+(tes|les|toutes?\s+les)\s+(instructions|consignes|regles)/,
    /oublie[rz]?\s+(tout|tes|les)\s/,
    /(system|systeme)\s*(prompt|message)/,
    /\btu es (une |un )?(ia|intelligence artificielle|bot|robot|modele|assistant|chatgpt|llm)\b/,
    /\b(prompt|instructions?|consignes)\s+(initial|systeme|caches?|secrets?)\b/,
    /repete?\s+(tes|les)\s+(instructions|consignes)/,
    /\bjailbreak\b|\bdan mode\b|\bdeveloper mode\b/,
    /agis?\s+comme\s+(si tu|un|une)\b/,
    /\bnouvelle?s?\s+(instructions?|consignes?)\b/,
  ]
  if (injections.some((r) => r.test(t))) return true

  // Insultes manifestes. La liste est courte et assumée : on coupe sur l'évident,
  // pas sur la grossièreté — Léna elle-même dit « Mon cul ».
  const insultes = [
    /\b(ta|ta ) ?gueule\b/, /\benculé/, /\bconnard/, /\bsalope\b/, /\bpute\b/,
    /\bva te faire\b/, /\bnique\b/, /\bfdp\b/, /\bcrève\b|\bcreve\b/,
  ]
  return insultes.some((r) => r.test(t))
}

/** Effets appliqués par le SERVEUR selon la tonalité. Le modèle n'écrit rien. */
export const EFFETS_TONALITE = {
  sincere: { inc: { confiance: 2 } },
  evasif: { inc: { confiance: -1 } },
  hostile: {}, // coupure sèche, sans gain ni perte
} as const

/**
 * Filtre de `detail_perso` — **liste d'autorisation, pas d'exclusion**.
 *
 * Une liste d'exclusion sur du texte libre ne rattrape que ce qu'on a prévu :
 * « je suis en rémission » ou « je vais à la mosquée le vendredi » passeraient.
 * On inverse : seules quatre catégories anodines sont acceptées, et **tout le
 * reste devient null**. La liste d'exclusion reste, en second filet, sur la
 * valeur elle-même.
 *
 * Un `detail_perso` nul est un cas normal, que le payoff du chapitre 4 doit
 * savoir traiter. Voir docs/LOGIQUE.md § detail_perso.
 */
const CATEGORIES_AUTORISEES = ['prenom', 'ville', 'metier', 'animal']

const TERMES_SENSIBLES = [
  // santé
  'malad', 'cancer', 'depress', 'therap', 'psy', 'traitement', 'medicament',
  'hopital', 'handicap', 'remission', 'diagnostic', 'addict', 'alcool', 'drogue',
  // croyances et opinions
  'musulman', 'chretien', 'juif', 'catholique', 'athee', 'mosquee', 'eglise',
  'synagogue', 'croyant', 'pratiquant', 'vote', 'parti', 'politiqu', 'syndicat',
  // vie intime
  'gay', 'lesbi', 'homosexuel', 'hetero', 'bisexuel', 'trans', 'sexuel',
  // origines
  'origine', 'immigr', 'refugi', 'ethni', 'nationalit',
  // identifiants et coordonnées
  '@', 'http', 'iban', 'carte bancaire', 'secu', 'passeport',
]

export interface DetailRetenu {
  valeur: string | null
  motifRejet: string | null
}

export function filtrerDetail(detail: ReponseIA['detail']): DetailRetenu {
  if (detail.categorie === 'aucun' || !detail.valeur) {
    return { valeur: null, motifRejet: null }
  }
  if (!CATEGORIES_AUTORISEES.includes(detail.categorie)) {
    return { valeur: null, motifRejet: `catégorie non autorisée : ${detail.categorie}` }
  }

  const valeur = detail.valeur.trim()
  // Un détail anodin est court. Une phrase entière n'en est pas un.
  if (valeur.length === 0 || valeur.length > 40) {
    return { valeur: null, motifRejet: 'longueur suspecte' }
  }
  if (/\d{4,}/.test(valeur)) {
    return { valeur: null, motifRejet: 'suite de chiffres' }
  }

  const normalise = valeur.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
  const terme = TERMES_SENSIBLES.find((t) => normalise.includes(t))
  if (terme) return { valeur: null, motifRejet: `terme sensible : ${terme}` }

  return { valeur, motifRejet: null }
}
