#!/usr/bin/env bash
# Téléverse les médias du chapitre 1 dans le bucket `media` et remplace les
# placeholder:// en base.
#
# Usage :
#   1. déposer les fichiers dans media/ (voir les noms attendus ci-dessous)
#   2. supabase start
#   3. scripts/upload-media.sh
#
# Idempotent : réexécutable autant de fois qu'on veut (upsert + update).
# Les fichiers absents sont signalés et laissent leur placeholder en place, ce
# qui permet de les livrer un par un.
set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOSSIER="$RACINE/media"
BUCKET="media"

cd "$RACINE"
eval "$(supabase status -o env | sed 's/^/export /')"

# Nom de base attendu dans media/, sans extension.
# Le placeholder correspondant en base est toujours « placeholder://<base> ».
MEDIAS=(
  photo-N10-recepisse
  photo-N16-plaque
  photo-N21-porte-cles
  audio-N17-reperage
)

trouver() { # cherche le fichier quelle que soit son extension
  local base="$1"
  for f in "$DOSSIER/$base".*; do
    [ -e "$f" ] && { echo "$f"; return 0; }
  done
  return 1
}

mime() {
  case "${1##*.}" in
    jpg|jpeg) echo image/jpeg ;;
    png)      echo image/png ;;
    webp)     echo image/webp ;;
    mp3)      echo audio/mpeg ;;
    m4a|mp4)  echo audio/mp4 ;;
    aac)      echo audio/aac ;;
    wav)      echo audio/wav ;;
    *)        echo application/octet-stream ;;
  esac
}

sql() { docker exec -i "supabase_db_${PWD##*/}" psql -U postgres -d postgres -qAt -c "$1"; }

mkdir -p "$DOSSIER"
echo "=============================================================================="
echo "  MÉDIAS DU CHAPITRE 1 — bucket « $BUCKET »"
echo "=============================================================================="

manquants=0
for base in "${MEDIAS[@]}"; do
  placeholder="placeholder://$base"

  if ! fichier="$(trouver "$base")"; then
    printf "  ⏳ %-28s absent de media/ — placeholder conservé\n" "$base"
    manquants=$((manquants + 1))
    continue
  fi

  objet="$base.${fichier##*.}"
  type="$(mime "$fichier")"

  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    "$API_URL/storage/v1/object/$BUCKET/$objet" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "Content-Type: $type" \
    -H "x-upsert: true" \
    --data-binary "@$fichier")

  if [ "$code" != "200" ] && [ "$code" != "201" ]; then
    printf "  ❌ %-28s téléversement refusé (HTTP %s)\n" "$base" "$code"
    exit 1
  fi

  sql "update messages set media_url = '$objet' where media_url = '$placeholder' or media_url = '$objet';" >/dev/null
  taille=$(du -h "$fichier" | cut -f1 | tr -d ' ')
  printf "  ✅ %-28s → %s  (%s, %s)\n" "$base" "$objet" "$type" "$taille"
done

echo
echo "── état en base ──"
sql "select '  '||n.code||'#'||m.position||'  '||rpad(m.content_type,6)||'  '||m.media_url
     from messages m join nodes n on n.id = m.node_id
     where m.media_url is not null order by m.media_url;"

restants=$(sql "select count(*) from messages where media_url like 'placeholder://%';")
echo
if [ "$restants" -gt 0 ]; then
  echo "  ⚠️  $restants média(s) encore en placeholder — l'app affichera le cartouche de repli."
else
  echo "  ✅ Tous les médias sont en place."
fi
[ "$manquants" -gt 0 ] && exit 0 || exit 0
