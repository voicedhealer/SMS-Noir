// Cœur du moteur : application des effects, évaluation des conditions.
// Aucune dépendance à Supabase — testable seul.
// Référence : docs/LOGIQUE.md.

import type { Conditions, Effects, Variables } from './types.ts'

/** Bornes des variables numériques du chapitre 1. */
const BORNES: Record<string, { min: number; max: number }> = {
  confiance: { min: 0, max: 10 },
  lucidite: { min: 0, max: 5 },
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
  indices: [],
  refus: false,
  branche_ch1: null,
  interactions_faites: [],
  contacts_reveles: [],
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
    const courant = typeof out[cle] === 'number' ? (out[cle] as number) : 0
    const borne = BORNES[cle]
    out[cle] = clamp(courant + delta, borne?.min ?? Number.MIN_SAFE_INTEGER, plafond(cle, out))
  }

  for (const [cle, valeur] of Object.entries(effects.append ?? {})) {
    const liste = Array.isArray(out[cle]) ? (out[cle] as string[]) : []
    if (!liste.includes(valeur)) out[cle] = [...liste, valeur]
    else out[cle] = liste
  }

  if (effects.reveal_contact) {
    const revele = out.contacts_reveles ?? []
    if (!revele.includes(effects.reveal_contact)) {
      out.contacts_reveles = [...revele, effects.reveal_contact]
    }
  }

  return out
}

/**
 * Re-applique le plafond de confiance sur des variables existantes.
 * Filet de sécurité : `refus` peut être posé par un nœud APRÈS que la
 * confiance a dépassé 6 sur un chemin antérieur.
 */
export function appliquerPlafonds(vars: Variables): Variables {
  const out = { ...vars }
  if (typeof out.confiance === 'number') {
    out.confiance = clamp(out.confiance, BORNES.confiance.min, plafond('confiance', out))
  }
  if (typeof out.lucidite === 'number') {
    out.lucidite = clamp(out.lucidite, BORNES.lucidite.min, BORNES.lucidite.max)
  }
  return out
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
