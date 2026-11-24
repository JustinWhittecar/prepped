#!/usr/bin/env bash
# SimGear Forever on CurseForge (project 1754471, https://www.curseforge.com/wow/addons/simgearforever),
# read through the CurseForge Core API. SimGear publishes there only: no public GitHub releases.
#
#   tools/simgear_cf.sh pinned               the version in tools/simgear-pin.txt
#   tools/simgear_cf.sh latest               the newest release-type file's version
#   tools/simgear_cf.sh fetch <version> <dir> download that version's zip and unzip it into <dir>
#
# Needs CF_CORE_API_KEY: a CurseForge Core API key from https://console.curseforge.com. That is not
# the upload token the packager uses (CF_API_KEY); the upload API can't list another author's files.
# Fails, never guesses: no key, an API error or no matching file all exit non-zero with the reason.
#
# Testing without the API: SIMGEAR_CF_FILES=<json> reads a /v1/mods/<id>/files response from a file.
set -euo pipefail
shopt -s inherit_errexit # a failed API call inside $(...) stops the script too

PROJECT_ID=1754471
API=https://api.curseforge.com/v1
ROOT=$(cd "$(dirname "$0")/.." && pwd)

die() { echo "simgear_cf: $*" >&2; exit 1; }

pinned() {
  local v
  v=$(grep -v '^[[:space:]]*#' "$ROOT/tools/simgear-pin.txt" | grep -m1 -o '^[0-9][0-9.]*') || true
  [[ -n $v ]] || die "no version in tools/simgear-pin.txt"
  echo "$v"
}

api() { # path -> JSON on stdout
  [[ -n ${CF_CORE_API_KEY:-} ]] || die "CF_CORE_API_KEY is not set. Add a CurseForge Core API key (console.curseforge.com) as the repository secret CF_CORE_API_KEY."
  local out
  out=$(curl -fsS --retry 3 -H "Accept: application/json" -H "x-api-key: $CF_CORE_API_KEY" "$API$1") \
    || die "CurseForge API request failed: $API$1 (bad key, or the API is down)"
  jq -e '.data' >/dev/null <<<"$out" 2>/dev/null || die "unexpected CurseForge response for $1: ${out:0:200}"
  echo "$out"
}

# Every file of the project as one JSON array (the API pages at 50).
files() {
  if [[ -n ${SIMGEAR_CF_FILES:-} ]]; then jq -c '.data' "$SIMGEAR_CF_FILES"; return; fi
  local index=0 all='[]' page n
  while :; do
    page=$(api "/mods/$PROJECT_ID/files?pageSize=50&index=$index")
    n=$(jq '.data | length' <<<"$page")
    all=$(jq -c --argjson a "$all" '$a + .data' <<<"$page")
    (( n < 50 )) && break
    index=$((index + 50))
  done
  echo "$all"
}

# Release-type files (releaseType 1; 2 = beta, 3 = alpha) as "version<TAB>id<TAB>fileName<TAB>downloadUrl".
releases() {
  files | jq -r '.[] | select(.releaseType == 1)
    | (.fileName | capture("(?<v>[0-9]+\\.[0-9]+\\.[0-9]+)").v // empty) as $v
    | [$v, (.id | tostring), .fileName, (.downloadUrl // "")] | @tsv'
}

latest() {
  local v
  v=$(releases | cut -f1 | sort -V | tail -n1)
  [[ -n $v ]] || die "no release files with a version in their name on CurseForge project $PROJECT_ID"
  echo "$v"
}

fetch() {
  local want=$1 dir=$2 line id name url tmp
  line=$(releases | awk -F'\t' -v v="$want" '$1 == v { print; exit }')
  [[ -n $line ]] || die "no SimGear Forever $want release file on CurseForge project $PROJECT_ID"
  IFS=$'\t' read -r _ id name url <<<"$line"
  # A null downloadUrl means the author turned off third-party downloads; the CDN path is the
  # documented fallback for public files (files/<id / 1000>/<id % 1000>/<name>).
  [[ -n $url ]] || url="https://edge.forgecdn.net/files/$((id / 1000))/$((id % 1000))/$name"
  tmp=$(mktemp -d)
  curl -fsSL --retry 3 -o "$tmp/$name" "$url" || die "download failed: $url"
  mkdir -p "$dir"
  unzip -q -o "$tmp/$name" -d "$dir"
  rm -rf "$tmp"
  [[ -f $dir/SimGearForever/SimGearForever.toc ]] || die "$name unzipped, but $dir/SimGearForever/SimGearForever.toc is missing"
  echo "SimGear Forever $want ($name) in $dir"
}

case ${1:-} in
  pinned) pinned ;;
  latest) latest ;;
  fetch) [[ $# -eq 3 ]] || die "usage: $0 fetch <version> <dir>"; fetch "$2" "$3" ;;
  *) die "usage: $0 pinned | latest | fetch <version> <dir>" ;;
esac
