// Appel au modèle de langage, isolé derrière une interface.
//
// Rien d'autre dans le code ne sait qui est le fournisseur : changer de modèle
// ou de maison est une affaire de constantes et d'une implémentation.

/** Ce qu'on demande au modèle de renvoyer. Rien d'autre ne sera lu. */
export interface ReponseIA {
  reponse: string
  tonalite: 'sincere' | 'evasif' | 'hostile'
  detail: {
    categorie: 'prenom' | 'ville' | 'metier' | 'animal' | 'aucun'
    valeur: string | null
  }
}

export interface Echange {
  role: 'system' | 'user' | 'assistant'
  content: string
}

export interface ResultatIA {
  contenu: ReponseIA
  tokensEntree: number
  tokensSortie: number
}

export interface FournisseurIA {
  readonly nom: string
  readonly disponible: boolean
  repondre(messages: Echange[]): Promise<ResultatIA>
}

export class ErreurFournisseur extends Error {}

/**
 * Schéma imposé au décodage.
 *
 * `json_schema` avec `strict: true` **contraint** la génération à la forme
 * attendue, là où l'ancien `json_object` se contentait de demander poliment du
 * JSON. Sur un moment qui doit rester en personnage et ne rien inventer, la
 * différence n'est pas cosmétique.
 */
const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['reponse', 'tonalite', 'detail'],
  properties: {
    reponse: { type: 'string' },
    tonalite: { type: 'string', enum: ['sincere', 'evasif', 'hostile'] },
    detail: {
      type: 'object',
      additionalProperties: false,
      required: ['categorie', 'valeur'],
      properties: {
        categorie: {
          type: 'string',
          enum: ['prenom', 'ville', 'metier', 'animal', 'aucun'],
        },
        valeur: { type: ['string', 'null'] },
      },
    },
  },
}

/**
 * Fournisseur simulé, pour les tests.
 *
 * ⚠️ **Uniquement quand `AI_PROVIDER=stub`.** Jamais actif en production : la
 * variable n'existe que dans l'environnement de test.
 *
 * Il lit une directive glissée dans le dernier message du joueur —
 * `##STUB## {json}` — et la renvoie telle quelle. Ce détour permet d'exercer la
 * VRAIE fonction (quota, filtres, décompte, raccrochage) sans dépendre d'un
 * modèle, et sans redémarrer le serveur entre chaque cas.
 *
 * `##ERREUR##` simule une panne du fournisseur, `##BRUT## …` une réponse
 * malformée : ce sont les deux chemins de mode dégradé.
 */
export class FournisseurSimule implements FournisseurIA {
  readonly nom = 'stub'
  readonly disponible = true

  repondre(messages: Echange[]): Promise<ResultatIA> {
    const dernier = [...messages].reverse().find((m) => m.role === 'user')?.content ?? ''

    if (dernier.includes('##ERREUR##')) {
      return Promise.reject(new ErreurFournisseur('panne simulée'))
    }
    const brut = dernier.match(/##BRUT##\s*([\s\S]*)$/)
    if (brut) {
      return Promise.resolve({ contenu: analyser(brut[1]), tokensEntree: 1, tokensSortie: 1 })
    }
    const directive = dernier.match(/##STUB##\s*([\s\S]*)$/)
    const charge = directive
      ? directive[1]
      : JSON.stringify({
          reponse: 'Ok.',
          tonalite: 'evasif',
          detail: { categorie: 'aucun', valeur: null },
        })
    return Promise.resolve({ contenu: analyser(charge), tokensEntree: 10, tokensSortie: 5 })
  }
}

/** Le fournisseur en service. Simulé uniquement si l'environnement le demande. */
export function fournisseur(): FournisseurIA {
  return Deno.env.get('AI_PROVIDER') === 'stub' ? new FournisseurSimule() : new Mistral()
}

export class Mistral implements FournisseurIA {
  readonly nom = 'mistral'

  /**
   * Version **épinglée**, pas un alias `-latest`.
   *
   * Mistral déconseille les alias en production : ils changent de modèle sous
   * les pieds. Ici, un changement de comportement du modèle changerait la voix
   * de Léna sans prévenir. Surchargeable par `MISTRAL_MODEL` pour tester une
   * autre version sans redéployer.
   */
  private readonly modele = Deno.env.get('MISTRAL_MODEL') ?? 'mistral-small-2603'
  private readonly cle = Deno.env.get('MISTRAL_API_KEY') ?? ''

  /** Léna écrit court : deux phrases, jamais plus. */
  private readonly maxTokens = 160

  /** Court : au-delà, mieux vaut raccrocher en personnage qu'attendre. */
  private readonly timeout = 12_000

  get disponible(): boolean {
    return this.cle.length > 0
  }

  async repondre(messages: Echange[]): Promise<ResultatIA> {
    if (!this.disponible) throw new ErreurFournisseur('MISTRAL_API_KEY absente')

    const controleur = new AbortController()
    const minuteur = setTimeout(() => controleur.abort(), this.timeout)
    try {
      const reponse = await fetch('https://api.mistral.ai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.cle}`,
        },
        signal: controleur.signal,
        body: JSON.stringify({
          model: this.modele,
          messages,
          max_tokens: this.maxTokens,
          temperature: 0.8, // elle a une voix, pas un ton neutre
          response_format: {
            type: 'json_schema',
            json_schema: { name: 'reponse_lena', strict: true, schema: SCHEMA },
          },
        }),
      })

      if (!reponse.ok) {
        throw new ErreurFournisseur(`HTTP ${reponse.status} ${await reponse.text()}`)
      }
      const json = await reponse.json()
      const brut = json?.choices?.[0]?.message?.content
      if (typeof brut !== 'string') throw new ErreurFournisseur('Réponse vide')

      return {
        contenu: analyser(brut),
        tokensEntree: json?.usage?.prompt_tokens ?? 0,
        tokensSortie: json?.usage?.completion_tokens ?? 0,
      }
    } catch (e) {
      if (e instanceof ErreurFournisseur) throw e
      throw new ErreurFournisseur(String(e))
    } finally {
      clearTimeout(minuteur)
    }
  }
}

/**
 * Analyse la réponse du modèle.
 *
 * `strict: true` devrait suffire, mais on ne fait pas reposer la scène sur la
 * bonne volonté d'un fournisseur : on retire les éventuelles clôtures Markdown
 * et on valide chaque champ. Un JSON illisible lève, et l'appelant raccroche
 * en personnage.
 */
export function analyser(brut: string): ReponseIA {
  let texte = brut.trim()
  const fence = texte.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/)
  if (fence) texte = fence[1].trim()

  let json: Record<string, unknown>
  try {
    json = JSON.parse(texte)
  } catch {
    throw new ErreurFournisseur('JSON illisible')
  }

  const reponse = typeof json.reponse === 'string' ? json.reponse.trim() : ''
  if (!reponse) throw new ErreurFournisseur('Réponse absente')

  const tonalite = json.tonalite
  const detail = (json.detail ?? {}) as Record<string, unknown>
  const categorie = detail.categorie

  return {
    reponse,
    // Une tonalité inconnue est traitée comme évasive : jamais comme sincère,
    // qui est la seule à faire gagner de la confiance.
    tonalite: tonalite === 'sincere' || tonalite === 'hostile' ? tonalite : 'evasif',
    detail: {
      categorie: ['prenom', 'ville', 'metier', 'animal'].includes(categorie as string)
        ? (categorie as ReponseIA['detail']['categorie'])
        : 'aucun',
      valeur: typeof detail.valeur === 'string' ? detail.valeur.trim() : null,
    },
  }
}
