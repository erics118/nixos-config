#!/usr/bin/env bash
# thin client for the eriz.cc api. the server owns all validation; this only
# relays what it says.
set -euo pipefail

die() {
  echo "error: $*" >&2
  exit 1
}

# both are shelled out to on every call, jq also parses every response
for tool in jq curl; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is required but not found on PATH"
done

# load the access service token from XDG config
creds="${XDG_CONFIG_HOME:-$HOME/.config}/eriz/credentials"
[[ -f $creds ]] || die "missing $creds (holds the cloudflare access service token; see credentials.example)"
source "$creds"

BASE="${ERIZ_BASE:-https://eriz.cc}"

# url-encode, so a slug or file name with a space or a slash survives the trip
enc() {
  jq -rn --arg s "$1" '$s|@uri'
}

# splits argv into ARGS (the positionals) and FLAG (1 when the command's single
# optional flag was given). a flag spelled with a trailing '=' takes a value,
# which lands in VALUE; that is the whole difference, so the other commands pass
# their bare flag as before. an unknown flag or the wrong number of positionals
# is a usage error rather than something to drop silently.
parse_args() {
  local flag=$1 min=$2 max=$3 use=$4
  shift 4

  ARGS=()
  FLAG=0
  VALUE=""
  local arg opts_done=0
  for arg in "$@"; do
    # a literal '--' ends option parsing, so a path starting with '--' is safe
    if ((opts_done)); then
      ARGS+=("$arg")
      continue
    fi
    if [[ $arg == -- ]]; then
      opts_done=1
      continue
    fi
    if [[ -n $flag && $flag == *= && $arg == "$flag"* ]]; then
      FLAG=1
      VALUE=${arg#"$flag"}
      continue
    fi
    case $arg in
    "$flag") FLAG=1 ;;
    --*) die "unknown option $arg"$'\n'"usage: $use" ;;
    *) ARGS+=("$arg") ;;
    esac
  done

  if ((${#ARGS[@]} < min || ${#ARGS[@]} > max)); then die "usage: $use"; fi
}

# writes the response body to stdout and dies on anything that is not 2xx.
# curl does not follow redirects by default, so access's login redirect shows up
# as a 3xx here instead of html we would try to parse as json.
api() {
  local method=$1 path=$2
  shift 2

  if [[ -z ${CF_ACCESS_CLIENT_ID:-} || -z ${CF_ACCESS_CLIENT_SECRET:-} ]]; then
    die "set CF_ACCESS_CLIENT_ID and CF_ACCESS_CLIENT_SECRET to a cloudflare access service token"
  fi

  local response status body message
  response=$(
    curl -sS -X "$method" "$BASE$path" \
      -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
      -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET" \
      -w $'\n%{http_code}' "$@"
  )
  status=${response##*$'\n'}
  body=${response%$'\n'*}

  case $status in
  2*) printf '%s' "$body" ;;
  3*)
    die "cloudflare access rejected the service token. the access app needs a policy whose action is Service Auth (not Allow) including this token."
    ;;
  *)
    message=$(jq -r '.error // empty' <<<"$body" 2>/dev/null) || message=""
    die "${message:-$status}"
    ;;
  esac
}

cmd_link() {
  local use="eriz link <url> [slug] [--force]"
  parse_args --force 1 2 "$use" "$@"

  local body
  body=$(jq -n --arg url "${ARGS[0]}" '{url: $url}')
  if [[ -n ${ARGS[1]:-} ]]; then body=$(jq --arg slug "${ARGS[1]}" '.slug = $slug' <<<"$body"); fi
  if ((FLAG)); then body=$(jq '.force = true' <<<"$body"); fi

  local slug
  slug=$(api POST /api/links -H "content-type: application/json" -d "$body" | jq -r '.slug // empty')
  [[ -n $slug ]] || die "server returned no slug"
  echo "$BASE/$slug"
}

cmd_file() {
  local use="eriz file <path> [name] [--exact]"
  parse_args --exact 1 2 "$use" "$@"

  local path=${ARGS[0]} name query
  if [[ ! -f $path ]]; then die "no such file: $path"; fi

  name=${ARGS[1]:-$(basename "$path")}
  # --data-binary sends the bytes as they are and sets content-length, which the
  # api requires
  query="?name=$(enc "$name")"
  if ((FLAG)); then query="$query&exact"; fi

  api POST "/api/files$query" --data-binary "@$path" | jq -r .url
}

cmd_paste() {
  local use="eriz paste <path|-> [id] [--name=<name>]"
  parse_args --name= 1 2 "$use" "$@"

  local path=${ARGS[0]} name query source
  # '-' is stdin, which has no name of its own, so --name is the only way to
  # give one. worth giving: the viewer picks its highlighting grammar from the
  # name's extension, and falls back to guessing without one.
  if [[ $path == - ]]; then
    source="@-"
    name=""
  else
    if [[ ! -f $path ]]; then die "no such file: $path"; fi
    source="@$path"
    name=$(basename "$path")
  fi
  # --name overrides the basename, so a file can be pasted under another name.
  # a bare --name= clears it, which is how a file paste opts out of one.
  if ((FLAG)); then name=$VALUE; fi

  query=""
  if [[ -n ${ARGS[1]:-} ]]; then query="?id=$(enc "${ARGS[1]}")"; fi
  if [[ -n $name ]]; then
    if [[ -n $query ]]; then query="$query&"; else query="?"; fi
    query="${query}name=$(enc "$name")"
  fi

  api POST "/api/snippets$query" --data-binary "$source" | jq -r .url
}

cmd_ls() {
  parse_args "" 0 0 "eriz ls" "$@"

  local listing nlinks nfiles nsnippets
  listing=$(api GET /api/list)
  nlinks=$(jq '.links | length' <<<"$listing")
  nfiles=$(jq '.files | length' <<<"$listing")
  nsnippets=$(jq '.snippets | length' <<<"$listing")

  # the api sends utc; this turns it into local time, as the admin page does.
  # fromdateiso8601 has no time to parse the milliseconds toISOString emits, so
  # they are dropped first. a record written before the api stored a creation
  # time has none, and it gets a blank column rather than a guess.
  #
  # padded here, unlike the slug below: read treats a tab as whitespace whatever
  # IFS says, so an empty column would be swallowed along with its separator and
  # shift every field after it. a timestamp is fixed width, so padding it in jq
  # cannot truncate anything the way padding a slug would.

  # strflocaltime needs jq >= 1.7
  local created='def pad: . + (" " * (16 - length));
    def created: (if .created == null then "" else (.created
    | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601
    | strflocaltime("%Y-%m-%d %H:%M")) end) | pad;'

  # the listing arrives newest first, and printing it in order is what keeps it
  # that way. the date leads every section, so the three line up as one column.
  if ((nlinks)); then
    echo "links:"
    # padded here rather than in jq, which would have to truncate a long slug
    jq -r "$created"'.links[] | [created, .slug, .url] | @tsv' <<<"$listing" |
      while IFS=$'\t' read -r at slug url; do
        printf '  %s %-12s -> %s\n' "$at" "$slug" "$url"
      done
  fi

  if ((nfiles)); then
    if ((nlinks)); then echo ""; fi
    echo "files:"
    jq -r "$created"'.files[] | [created, .name] | @tsv' <<<"$listing" |
      while IFS=$'\t' read -r at name; do
        printf '  %s f/%s\n' "$at" "$name"
      done
  fi

  if ((nsnippets)); then
    if ((nlinks || nfiles)); then echo ""; fi
    echo "snippets:"
    jq -r "$created"'.snippets[] | [created, .id, .name // ""] | @tsv' \
      <<<"$listing" |
      while IFS=$'\t' read -r at id name; do
        printf '  %s %-12s %s\n' "$at" "p/$id" "$name"
      done
  fi

  if ((nlinks == 0 && nfiles == 0 && nsnippets == 0)); then echo "(empty)"; fi
}

# an f/ prefix selects a file, a p/ prefix a snippet, anything else a link slug
record_path() {
  case $1 in
  f/*) echo "/api/files/$(enc "${1#f/}")" ;;
  p/*) echo "/api/snippets/$(enc "${1#p/}")" ;;
  *) echo "/api/links/$(enc "$1")" ;;
  esac
}

cmd_rm() {
  local use="eriz rm <slug|f/name|p/id>"
  parse_args "" 1 1 "$use" "$@"

  api DELETE "$(record_path "${ARGS[0]}")" >/dev/null
  echo "removed ${ARGS[0]}"
}

cmd_mv() {
  local use="eriz mv <slug|f/name|p/id> <new-slug|f/new-name|p/new-id>"
  parse_args "" 2 2 "$use" "$@"

  local from=${ARGS[0]} to=${ARGS[1]} body
  # both sides must name the same kind of record, so a typo cannot turn one
  # kind of rename into another
  case $from in
  f/*)
    if [[ $to != f/* ]]; then die "renaming a file needs f/ on both sides"; fi
    body=$(jq -n --arg name "${to#f/}" '{name: $name}')
    ;;
  p/*)
    if [[ $to != p/* ]]; then die "renaming a snippet needs p/ on both sides"; fi
    body=$(jq -n --arg id "${to#p/}" '{id: $id}')
    ;;
  *)
    case $to in
    f/*) die "cannot rename a link into a file" ;;
    p/*) die "cannot rename a link into a snippet" ;;
    esac
    body=$(jq -n --arg slug "$to" '{slug: $slug}')
    ;;
  esac

  api PATCH "$(record_path "$from")" \
    -H "content-type: application/json" -d "$body" >/dev/null
  echo "renamed $from -> $to"
}

cmd_url() {
  local use="eriz url <slug> <new-url>"
  parse_args "" 2 2 "$use" "$@"

  local body
  body=$(jq -n --arg url "${ARGS[1]}" '{url: $url}')
  api PATCH "/api/links/$(enc "${ARGS[0]}")" \
    -H "content-type: application/json" -d "$body" >/dev/null
  echo "retargeted ${ARGS[0]} -> ${ARGS[1]}"
}

command=${1:-}
if [[ $# -gt 0 ]]; then shift; fi

case $command in
link) cmd_link "$@" ;;
file) cmd_file "$@" ;;
paste) cmd_paste "$@" ;;
ls) cmd_ls "$@" ;;
rm) cmd_rm "$@" ;;
mv) cmd_mv "$@" ;;
url) cmd_url "$@" ;;
*) die "usage: eriz <link|file|paste|ls|rm|mv|url> ..." ;;
esac
