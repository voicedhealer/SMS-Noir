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
#
# Appareil Android réel en USB (pas un émulateur) : `127.0.0.1` ne désigne ni
# l'appareil ni la machine hôte, contrairement à l'émulateur (10.0.2.2, géré
# tout seul par lib/config/env.dart). Poser le tunnel, puis ajouter
# --dart-define=ADB_REVERSE=true en argument :
#   adb reverse tcp:54321 tcp:54321
#   app/tool/run_local.sh -d <device> --dart-define=ADB_REVERSE=true
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
