import { ErreurMoteur } from './moteur.ts'

export const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export function json(corps: unknown, status = 200): Response {
  return new Response(JSON.stringify(corps), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

export function erreur(e: unknown): Response {
  if (e instanceof ErreurMoteur) {
    return json({ error: { code: e.code, message: e.message } }, e.status)
  }
  console.error('Erreur inattendue :', e)
  return json({ error: { code: 'erreur_interne', message: 'Erreur interne' } }, 500)
}

/** Enveloppe commune : CORS, méthode, erreurs typées. */
export function servir(handler: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
    if (req.method !== 'POST') {
      return json({ error: { code: 'methode_invalide', message: 'POST attendu' } }, 405)
    }
    try {
      return await handler(req)
    } catch (e) {
      return erreur(e)
    }
  }
}
