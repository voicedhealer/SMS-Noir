// Cœur du moteur : application des effects, évaluation des conditions.
// Aucune dépendance à Supabase — testable seul.
// Référence : docs/LOGIQUE.md.

import type { Conditions, Effects, Variables } from './types.ts'

/** Bornes des variables numériques. */
const BORNES: Record<string, { min: number; max: number }> = {
  confiance: { min: 0, max: 10 },
  lucidite: { min: 0, max: 5 },
  enquete: { min: 0, max: 10 },
}

/**
 * La grammaire des trois axes — protéger · enquêter · raisonner.
 *
 * Chaque micro-choix déclare un axe, jamais un nombre. Ce qui compte n'est pas
 * combien de fois le joueur a choisi « raisonner », mais **quelle part** de ses
 * micro-choix c'était : quelqu'un qui raisonne aux trois quarts doit finir au
 * même endroit qu'il en ait vu vingt ou soixante.
 *
 * C'est aussi ce qui règle le vrai problème des effets fixes : avec un `+0.5`
 * par choix, un raisonneur saturait `lucidite` à mi-chapitre et tous ses choix
 * suivants devenaient inertes. Avec une proportion, **aucun choix n'est jamais
 * inerte** — un « protéger » tardif fait baisser la part « raisonner ».
 *
 * Voir docs/LOGIQUE.md § La grammaire des trois axes.
 */
const AXES = { proteger: 'confiance', enquete: 'enquete', raison: 'lucidite' } as const

const EST_UN_AXE = new Set<string>(Object.values(AXES))

/**
 * Ce que la posture peut apporter, au maximum, à chaque variable.
 *
 * `enquete` prend toute sa plage : elle n'a aucun effet structurel, elle EST la
 * posture. `confiance` et `lucidite` gardent leurs effets structurels, déjà
 * équilibrés sur les six chapitres — la posture n'y est qu'un modificateur.
 */
const AMPLITUDE: Record<string, number> = { confiance: 3, enquete: 10, lucidite: 3 }

/** Décompte des micro-choix, par axe. */
export interface Micro {
  n: number
  proteger: number
  enquete: number
  raison: number
}

function micro(vars: Variables): Micro {
  const m = (vars.micro ?? {}) as Partial<Micro>
  return { n: m.n ?? 0, proteger: m.proteger ?? 0, enquete: m.enquete ?? 0, raison: m.raison ?? 0 }
}

function structurel(vars: Variables, cle: string): number {
  const s = (vars.structurel ?? {}) as Record<string, number>
  return typeof s[cle] === 'number' ? s[cle] : 0
}

/**
 * Part d'un axe dans les micro-choix, lissée, ramenée sur 0–1.
 *
 * Le `+1 / +3` est un lissage de Laplace : sans lui, le tout PREMIER
 * micro-choix donnerait 100 % à son axe et ferait bondir la variable d'un coup.
 * On part donc du neutre — un tiers par axe, soit un apport nul — et on
 * converge vers la vraie proportion à mesure que le motif se dessine.
 */
function partDeMotif(vars: Variables, axe: keyof typeof AXES): number {
  const m = micro(vars)
  const part = (m[axe] + 1) / (m.n + 3)
  const NEUTRE = 1 / 3
  // Jamais négatif : « raisonner n'est jamais puni » (règle 1 de la grammaire).
  // Un joueur qui ne protège jamais ne PERD pas de confiance, il n'en gagne
  // simplement pas par la posture. Le punir lui apprendrait à ne plus douter,
  // et il raterait la fin cachée.
  return Math.max(0, (part - NEUTRE) / (1 - NEUTRE))
}

/**
 * Plafond de `confiance` quand le joueur a refusé d'aider (bible §6).
 *
 * RÈGLE PERMANENTE DU MOTEUR, PAS UN EFFECT. Elle s'applique à chaque gain de
 * confiance tant que `refus` est vrai — y compris aux gains des chapitres
 * suivants et à celui du moment IA. L'encoder dans les `effects` du contenu
 * obligerait à la répéter partout : une ligne oubliée et la règle tombe en
 * silence. Voir docs/LOGIQUE.md § refus : deux mécanismes à ne pas confondre.
 */
const PLAFOND_CONFIANCE_SI_REFUS = 6

export const VARIABLES_INITIALES: Variables = {
  confiance: 3,
  lucidite: 0,
  enquete: 0,
  indices: [],
  refus: false,
  branche_ch1: null,
  interactions_faites: [],
  contacts_reveles: [],
  micro: { n: 0, proteger: 0, enquete: 0, raison: 0 },
  structurel: { confiance: 3, lucidite: 0 },
}

function clamp(valeur: number, min: number, max: number): number {
  return Math.min(Math.max(valeur, min), max)
}

function plafond(cle: string, vars: Variables): number {
  const borne = BORNES[cle]
  if (!borne) return Number.MAX_SAFE_INTEGER
  if (cle === 'confiance' && vars.refus === true) {
    return Math.min(borne.max, PLAFOND_CONFIANCE_SI_REFUS)
  }
  return borne.max
}

function listeDe(vars: Variables, cle: string): string[] {
  const v = vars[cle]
  return Array.isArray(v) ? (v as string[]) : []
}

/**
 * Applique un bloc d'effects et renvoie de NOUVELLES variables.
 * Ne mute jamais l'entrée.
 */
export function appliquerEffects(vars: Variables, effects: Effects | null): Variables {
  if (!effects) return vars
  const out: Variables = {
    ...vars,
    indices: [...listeDe(vars, 'indices')],
    interactions_faites: [...listeDe(vars, 'interactions_faites')],
    contacts_reveles: [...listeDe(vars, 'contacts_reveles')],
  }

  // `set` d'abord : poser refus=true doit plafonner les `inc` du MÊME bloc.
  for (const [cle, valeur] of Object.entries(effects.set ?? {})) {
    out[cle] = valeur
  }

  for (const [cle, delta] of Object.entries(effects.inc ?? {})) {
    if (EST_UN_AXE.has(cle)) {
      // Les gains des choix STRUCTURANTS s'accumulent à part. Sans ça, la part
      // de posture — qui se recalcule à chaque micro-choix — se cumulerait à
      // elle-même et la variable dériverait à chaque tour.
      const s = { ...(out.structurel as Record<string, number> ?? {}) }
      s[cle] = (s[cle] ?? 0) + delta
      out.structurel = s
      continue
    }
    const courant = typeof out[cle] === 'number' ? (out[cle] as number) : 0
    const borne = BORNES[cle]
    out[cle] = clamp(courant + delta, borne?.min ?? Number.MIN_SAFE_INTEGER, plafond(cle, out))
  }

  // Un micro-choix ne déclare qu'une posture. Le nombre, c'est l'affaire du
  // moteur — voir deriverAxes().
  if (effects.motif) {
    const m = micro(out)
    out.micro = { ...m, n: m.n + 1, [effects.motif]: m[effects.motif] + 1 }
  }

  for (const [cle, valeur] of Object.entries(effects.append ?? {})) {
    const liste = Array.isArray(out[cle]) ? (out[cle] as string[]) : []
    if (!liste.includes(valeur)) out[cle] = [...liste, valeur]
    else out[cle] = liste
  }

  if (effects.set_avatar) {
    const avatars = { ...(out.avatars as Record<string, string> | undefined ?? {}) }
    for (const [code, chemin] of Object.entries(effects.set_avatar)) {
      avatars[code] = chemin
    }
    out.avatars = avatars
  }

  if (effects.reveal_contact) {
    const revele = out.contacts_reveles ?? []
    if (!revele.includes(effects.reveal_contact)) {
      out.contacts_reveles = [...revele, effects.reveal_contact]
    }
  }

  // Toujours en dernier, et jamais laissé à l'appelant : une dérivation oubliée
  // sur un seul chemin, et la posture du joueur cesserait silencieusement de
  // compter.
  return deriverAxes(out)
}

/**
 * Recalcule les trois variables d'axe : part structurelle + part de posture.
 *
 * Idempotente, et c'est essentiel — elle est appelée après chaque effect ET par
 * appliquerPlafonds. Elle ne lit jamais la valeur publique, seulement
 * `structurel` et `micro`, donc la rejouer deux fois ne change rien.
 */
export function deriverAxes(vars: Variables): Variables {
  const out: Variables = { ...vars }
  for (const [axe, cle] of Object.entries(AXES) as [keyof typeof AXES, string][]) {
    const apport = Math.round(AMPLITUDE[cle] * partDeMotif(out, axe))
    const borne = BORNES[cle]
    out[cle] = clamp(structurel(out, cle) + apport, borne.min, plafond(cle, out))
  }
  return out
}

/**
 * Recalcule tous les invariants sur des variables existantes.
 *
 * Filet de sécurité à deux titres : `refus` peut être posé par un nœud APRÈS
 * que la confiance a dépassé 6 sur un chemin antérieur, et la part de posture
 * doit suivre le décompte des micro-choix quoi qu'il arrive. Le nom est resté
 * — il est appelé depuis les Edge Functions — mais il délègue tout.
 */
export function appliquerPlafonds(vars: Variables): Variables {
  return deriverAxes(vars)
}

/** Évalue un bloc de conditions. `{}` ou null = vrai. Clés en ET. */
export function evaluerConditions(vars: Variables, conditions: Conditions | null): boolean {
  if (!conditions) return true

  for (const [cle, attendu] of Object.entries(conditions.eq ?? {})) {
    if (vars[cle] !== attendu) return false
  }
  for (const [cle, seuil] of Object.entries(conditions.gte ?? {})) {
    if (typeof vars[cle] !== 'number' || (vars[cle] as number) < seuil) return false
  }
  for (const [cle, seuil] of Object.entries(conditions.lte ?? {})) {
    if (typeof vars[cle] !== 'number' || (vars[cle] as number) > seuil) return false
  }
  for (const [cle, valeur] of Object.entries(conditions.contains ?? {})) {
    if (!listeDe(vars, cle).includes(valeur)) return false
  }
  for (const [cle, valeur] of Object.entries(conditions.not_contains ?? {})) {
    if (listeDe(vars, cle).includes(valeur)) return false
  }
  for (const [cle, seuil] of Object.entries(conditions.count_gte ?? {})) {
    if (listeDe(vars, cle).length < seuil) return false
  }
  return true
}

/** Normalise des variables venues de la base (clés manquantes des vieilles parties). */
export function normaliserVariables(brut: unknown): Variables {
  const v = (brut ?? {}) as Partial<Variables>
  return {
    ...VARIABLES_INITIALES,
    ...v,
    indices: Array.isArray(v.indices) ? v.indices : [],
    interactions_faites: Array.isArray(v.interactions_faites) ? v.interactions_faites : [],
    contacts_reveles: Array.isArray(v.contacts_reveles) ? v.contacts_reveles : [],
  }
}

/** Avatar courant d'un contact : celui posé par un effect, sinon celui du contenu. */
export function avatarDe(
  contact: { code: string; avatar_url: string | null },
  vars: Variables,
): string | null {
  const avatars = vars.avatars as Record<string, string> | undefined
  return avatars?.[contact.code] ?? contact.avatar_url
}

/** Nom à afficher pour un contact, selon qu'il a été révélé ou non. */
export function nomAffiche(
  contact: { code: string; display_name: string; display_name_initial: string | null },
  vars: Variables,
): { display_name: string; revealed: boolean } {
  const revele = (vars.contacts_reveles ?? []).includes(contact.code)
  return {
    display_name: revele
      ? contact.display_name
      : (contact.display_name_initial ?? contact.display_name),
    // Un contact sans display_name_initial est connu dès le départ.
    revealed: revele || contact.display_name_initial === null,
  }
}
