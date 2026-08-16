#!/usr/bin/env bash
# Lance ou installe l'app contre le Supabase HÉBERGÉ (projet lié).
#
# Différence avec run_local.sh : plus besoin que le Mac tourne. L'app parle à
# api.supabase.co en HTTPS, donc elle marche en 4G, dans le lit, dans le métro
# — ce qui est le seul endroit où un thriller par SMS se teste vraiment.
#
# Aucune clé n'est écrite dans le repo : elles sont lues à la volée depuis le
# projet lié. Seule la clé PUBLISHABLE entre dans l'app.
#
# Usage :
#   app/tool/run_remote.sh                 # lance sur l'appareil branché
#   app/tool/run_remote.sh --apk           # fabrique un APK à installer
#   app/tool/run_remote.sh -d <appareil>   # choisit l'appareil
#
# Prérequis : supabase link --project-ref <ref>
set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$RACINE"

REF=$(supabase projects list -o json 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
lies = [p["ref"] for p in (d["projects"] if isinstance(d, dict) else d) if p["linked"]]
print(lies[0] if lies else "")')

if [ -z "$REF" ]; then
  echo "Aucun projet lié. Lancer : supabase link --project-ref <ref>" >&2
  exit 1
fi

CLE=$(supabase projects api-keys --project-ref "$REF" -o json | python3 -c '
import json, sys
k = json.load(sys.stdin)
pub = [x["api_key"] for x in k if x.get("type") == "publishable"]
# Repli sur la cle anon historique pour un projet non migre.
print(pub[0] if pub else next(x["api_key"] for x in k if x["name"] == "anon"))')

URL="https://$REF.supabase.co"
echo "API      : $URL"
echo "Appareil : ${*:-défaut}"

cd "$RACINE/app"

if [ "${1:-}" = "--apk" ]; then
  # APK de debug : installable et jouable sans le Mac, et il garde les outils
  # (bouton ↻ pour tout rejouer, skip du déroulé, skip de l'intro).
  flutter build apk --debug \
    --dart-define=SUPABASE_URL="$URL" \
    --dart-define=SUPABASE_PUBLISHABLE_KEY="$CLE"
  echo
  echo "APK : $RACINE/app/build/app/outputs/flutter-apk/app-debug.apk"
  echo "Installation : adb install -r <ce chemin>"
  exit 0
fi

exec flutter run \
  --dart-define=SUPABASE_URL="$URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$CLE" \
  "$@"
