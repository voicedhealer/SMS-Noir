#!/usr/bin/env bash
# Lance l'app contre le Supabase local.
#
# Aucune clé n'est écrite dans le repo : elles sont lues à la volée depuis
# `supabase status`. Seule la clé PUBLISHABLE entre dans l'app — la clé de
# service ne quitte jamais le serveur.
#
# Usage :
#   supabase start && supabase functions serve &
#   app/tool/run_local.sh [-d <device>]
set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$RACINE"

if ! supabase status >/dev/null 2>&1; then
  echo "Supabase local n'est pas démarré. Lancer : supabase start" >&2
  exit 1
fi

eval "$(supabase status -o env | sed 's/^/export /')"

if [ -z "${PUBLISHABLE_KEY:-}" ]; then
  echo "PUBLISHABLE_KEY introuvable dans 'supabase status -o env'." >&2
  exit 1
fi

echo "API      : ${API_URL}"
echo "Appareil : ${*:-défaut}"
echo "(l'émulateur Android bascule seul sur 10.0.2.2 — voir lib/config/env.dart)"

cd "$RACINE/app"
exec flutter run \
  --dart-define=SUPABASE_URL="${API_URL}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${PUBLISHABLE_KEY}" \
  "$@"
