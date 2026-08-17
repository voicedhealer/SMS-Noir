#!/usr/bin/env bash
# Téléverse les médias du chapitre 1 dans le bucket `media` et remplace les
# placeholder:// en base.
#
# Usage :
#   1. déposer les fichiers dans media/ (voir les noms attendus ci-dessous)
#   2. supabase start
#   3. scripts/upload-media.sh
#
# Sur le projet HÉBERGÉ (après `supabase link`) :
#   DISTANT=1 scripts/upload-media.sh
#
# Le seed remet des `placeholder://` : ce script est donc à rejouer après
# chaque `db reset` local ET après chaque `db push --include-seed` distant.
#
# Idempotent : réexécutable autant de fois qu'on veut (upsert + update).
# Les fichiers absents sont signalés et laissent leur placeholder en place, ce
# qui permet de les livrer un par un.
set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOSSIER="$RACINE/media"
BUCKET="media"

cd "$RACINE"

# En local, tout vient de `supabase status`. En distant, des clés du projet lié.
# Aucun secret n'est écrit nulle part : ils ne vivent que dans ce shell.
DISTANT="${DISTANT:-}"
if [ -n "$DISTANT" ]; then
  REF=$(supabase projects list -o json 2>/dev/null \
        | python3 -c 'import json,sys
d = json.load(sys.stdin)
print(next(p["ref"] for p in (d["projects"] if isinstance(d, dict) else d) if p["linked"]))')
  API_URL="https://$REF.supabase.co"
  SERVICE_ROLE_KEY=$(supabase projects api-keys --project-ref "$REF" -o json \
        | python3 -c 'import json,sys;print(next(k["api_key"] for k in json.load(sys.stdin) if k["name"]=="service_role"))')
  echo "  → projet distant $REF"
else
  eval "$(supabase status -o env | sed 's/^/export /')"
fi

# Nom de base attendu dans media/, sans extension.
# Le placeholder correspondant en base est toujours « placeholder://<base> ».
MEDIAS=(
  photo-N10-recepisse
  photo-N16-plaque
  photo-N21-porte-cles
  audio-N17-reperage
)

# La musique d'intronisation n'est pas rattachée à un nœud : elle vit sur
# l'histoire (stories.intro_music_url). Tout fichier de media/ dont le nom ne
# correspond à aucun nœud et qui est un audio est traité comme tel.
MUSIQUE_INTRO="intro-music" 

# Cherche le fichier correspondant à un média.
#
# Tolérant sur le nommage : on accepte le nom canonique, mais aussi n'importe
# quel fichier dont le nom contient le code du nœud (« N10 — le mail de la
# police.png »). C'est ainsi qu'on nomme naturellement en produisant, et c'est
# le code de nœud qui identifie sans ambiguïté.
trouver() {
  local base="$1"
  local code="${base#*-}"; code="${code%%-*}"   # photo-N10-recepisse -> N10
  [ "$base" = "$MUSIQUE_INTRO" ] && code='@@aucun@@'
  local f

  for f in "$DOSSIER/$base".*; do
    [ -e "$f" ] && { echo "$f"; return 0; }
  done
  for f in "$DOSSIER"/*; do
    [ -e "$f" ] || continue
    case "$f" in *.md) continue;; esac
    case "$(basename "$f")" in
      *"$code"*) echo "$f"; return 0 ;;
    esac
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

# Écritures en base.
#
# En local on passe par psql. En distant il n'y a pas de client psql sous la
# main, mais on n'en a pas besoin : les seules écritures sont des UPDATE sur
# une égalité, ce que PostgREST fait très bien avec la clé de service.
rest() {  # rest <méthode> <chemin+filtre> [corps json]
  curl -s -X "$1" "$API_URL/rest/v1/$2" \
    -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H 'Content-Type: application/json' ${3:+-d "$3"}
}

sql() { docker exec -i "supabase_db_${PWD##*/}" psql -U postgres -d postgres -qAt -c "$1"; }

# Rattache un objet téléversé au message qui le porte.
poser_media() {  # poser_media <placeholder> <objet>
  if [ -n "$DISTANT" ]; then
    rest PATCH "messages?or=(media_url.eq.$1,media_url.eq.$2)" "{\"media_url\":\"$2\"}" >/dev/null
  else
    sql "update messages set media_url = '$2' where media_url = '$1' or media_url = '$2';" >/dev/null
  fi
}

# Pose une colonne de `stories` (musique d'intro, sons de messagerie).
poser_story() {  # poser_story <colonne> <objet>
  if [ -n "$DISTANT" ]; then
    rest PATCH "stories?slug=eq.numero-inconnu" "{\"$1\":\"$2\"}" >/dev/null
  else
    sql "update stories set $1 = '$2' where slug = 'numero-inconnu';" >/dev/null
  fi
}

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

  poser_media "$placeholder" "$objet"
  taille=$(du -h "$fichier" | cut -f1 | tr -d ' ')
  printf "  ✅ %-28s → %s  (%s, %s)\n" "$base" "$objet" "$type" "$taille"
done

# --- Sons de message --------------------------------------------------------
# Repérés par mot-clé dans le nom : « reception » / « recu » et « envoi ».
sonner() { # $1 = motif, $2 = colonne, $3 = libellé
  local f trouve=""
  for f in "$DOSSIER"/*; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      *.mp3|*.m4a|*.aac|*.wav) ;;
      *) continue;;
    esac
    case "$(basename "$f" | tr 'A-Z' 'a-z')" in
      *$1*) trouve="$f"; break;;
    esac
  done
  if [ -z "$trouve" ]; then
    printf "  ⏳ %-28s absent — %s restera silencieux\n" "($1)" "$3"
    return
  fi
  local objet="son-$1.${trouve##*.}"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    "$API_URL/storage/v1/object/$BUCKET/$objet" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "Content-Type: $(mime "$trouve")" -H "x-upsert: true" \
    --data-binary "@$trouve")
  if [ "$code" = "200" ] || [ "$code" = "201" ]; then
    poser_story "$2" "$objet"
    printf "  ✅ %-28s → %s  (%s)\n" "$(basename "$trouve")" "$objet" "$3"
  else
    printf "  ❌ %-28s téléversement refusé (HTTP %s)\n" "$(basename "$trouve")" "$code"
  fi
}

sonner reception sound_received_url "son de réception"
sonner envoi     sound_sent_url     "son d'envoi"
sonner frappe    sound_typing_url   "son de frappe"

# --- Musique d'intronisation ------------------------------------------------
# Repérée par élimination : un audio de media/ qui n'appartient à aucun nœud.
musique=""
for f in "$DOSSIER"/*; do
  [ -e "$f" ] || continue
  nom="$(basename "$f")"
  case "$nom" in *.md) continue;; esac
  case "$nom" in *.mp3|*.m4a|*.aac|*.wav) ;; *) continue;; esac
  case "$nom" in *N17*|*audio-N*) continue;; esac
  # Les sons de message ne sont pas la musique d'intro.
  case "$(echo "$nom" | tr 'A-Z' 'a-z')" in *reception*|*envoi*|*frappe*|*son-*) continue;; esac
  musique="$f"; break
done

# Les TROIS segments musicaux, désignés par un mot-clé du nom de fichier.
#
# Le repérage « premier fichier audio venu » ne tenait plus : il y a désormais
# trois morceaux issus du même enregistrement, et rien dans leur en-tête ne dit
# lequel va où. On les nomme.
for triplet in "intro:intro_music_url:intro-music" \
               "60-sec:narration_music_url:narration-music" \
               "clap-de-fin:chapter_end_music_url:fin-music"; do
  motif="${triplet%%:*}"; reste="${triplet#*:}"
  colonne="${reste%%:*}"; base="${reste#*:}"

  fichier=""
  for f in "$DOSSIER"/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in *"$motif"*) fichier="$f"; break;; esac
  done

  if [ -z "$fichier" ]; then
    printf "  ⏳ %-28s absent — écran muet\n" "($motif)"
    continue
  fi

  objet="$base.${fichier##*.}"
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    "$API_URL/storage/v1/object/$BUCKET/$objet" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "Content-Type: $(mime "$fichier")" -H "x-upsert: true" \
    --data-binary "@$fichier")
  if [ "$code" = "200" ] || [ "$code" = "201" ]; then
    poser_story "$colonne" "$objet"
    printf "  ✅ %-28s → %s\n" "$(basename "$fichier")" "$objet"
  else
    printf "  ❌ %-28s téléversement refusé (HTTP %s)\n" "$(basename "$fichier")" "$code"
  fi
done

echo
echo "── état en base ──"
if [ -n "$DISTANT" ]; then
  rest GET "messages?media_url=not.is.null&select=media_url,content_type,position,nodes(code)&order=media_url" \
    | python3 -c 'import json,sys
for m in json.load(sys.stdin):
    print("  %s#%s  %-6s  %s" % (m["nodes"]["code"], m["position"], m["content_type"], m["media_url"]))'
  rest GET "stories?slug=eq.numero-inconnu&select=intro_music_url,narration_music_url,chapter_end_music_url,sound_received_url,sound_sent_url,sound_typing_url" \
    | python3 -c 'import json,sys
s = json.load(sys.stdin)[0]
print("  musique intro=%s  N19=%s  fin=%s" % (
      s["intro_music_url"] or "(aucune)", s["narration_music_url"] or "(aucune)",
      s["chapter_end_music_url"] or "(aucune)"))
print("  sons    recu=%s  envoi=%s  frappe=%s" % (s["sound_received_url"] or "(aucun)",
      s["sound_sent_url"] or "(aucun)", s["sound_typing_url"] or "(aucun)"))'
  restants=$(rest GET "messages?media_url=like.placeholder://*&select=media_url" \
    | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')
else
  sql "select '  '||n.code||'#'||m.position||'  '||rpad(m.content_type,6)||'  '||m.media_url
       from messages m join nodes n on n.id = m.node_id
       where m.media_url is not null order by m.media_url;"
  sql "select '  musique intro='||coalesce(intro_music_url,'(aucune)')
       ||'  N19='||coalesce(narration_music_url,'(aucune)')
       ||'  fin='||coalesce(chapter_end_music_url,'(aucune)')
       from stories where slug='numero-inconnu';"
  sql "select '  sons    reçu='||coalesce(sound_received_url,'(aucun)')||'  envoi='||coalesce(sound_sent_url,'(aucun)')||'  frappe='||coalesce(sound_typing_url,'(aucun)') from stories where slug='numero-inconnu';"
  restants=$(sql "select count(*) from messages where media_url like 'placeholder://%';")
fi
echo
if [ "$restants" -gt 0 ]; then
  echo "  ⚠️  $restants média(s) encore en placeholder — l'app affichera le cartouche de repli."
else
  echo "  ✅ Tous les médias sont en place."
fi
[ "$manquants" -gt 0 ] && exit 0 || exit 0
