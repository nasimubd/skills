#!/usr/bin/env bash
# labels.sh — extract the candidate interface labels from an application definition.
#
# Source it; it defines cgp_labels only. bash 3.2 compatible (macOS).
#
#   cgp_labels <file> [comma-separated keys]
#
# Prints one normalised label per line, sorted and unique. With keys, only the values stored
# under those keys count (precise); without, every string in the file counts (broad: a label
# check can then be satisfied by an internal string that happens to match).
#
# JSON is read with jq. Anything else (YAML, Power Fx style, markdown, plain text) is read line
# by line: the value of `key: value`, list items, headings, and any quoted string.

[[ -n "${CGP_LABELS_LOADED:-}" ]] && return 0
CGP_LABELS_LOADED=1

cgp_is_image() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    *.png | *.jpg | *.jpeg | *.gif | *.webp | *.bmp | *.heic | *.tif | *.tiff | *.pdf) return 0 ;;
  esac
  return 1
}

cgp_labels() {
  local file="$1" keys="${2:-}" raw
  if [[ ! -f "$file" ]]; then
    echo "click-path-guides: source not found: $file" >&2
    return 1
  fi
  if cgp_is_image "$file"; then
    echo "click-path-guides: '$file' is an image or document, not a definition. Screenshots hide sub-menus and invite invented paths; provide the app or flow definition, export or schema." >&2
    return 1
  fi

  if command -v jq >/dev/null 2>&1 && jq -e . "$file" >/dev/null 2>&1; then
    if [[ -n "$keys" ]]; then
      raw="$(jq -r --arg keys "$keys" '($keys | split(",") | map(gsub("^\\s+|\\s+$"; ""))) as $k
        | .. | objects | to_entries[] | select(.key as $x | $k | index($x)) | .value | strings' "$file" 2>/dev/null)"
    else
      raw="$(jq -r '.. | strings' "$file" 2>/dev/null)"
    fi
  else
    raw="$(awk -v keys="$keys" '
      function emit(s) { print s }
      BEGIN { nk = split(keys, kk, ","); for (i = 1; i <= nk; i++) { gsub(/^[ \t]+|[ \t]+$/, "", kk[i]); want[kk[i]] = 1 } }
      {
        line = $0
        sub(/^[ \t]+/, "", line)
        if (line ~ /^#/ && line !~ /^#+[ \t]+[^ ]/) next
        if (line ~ /^#+[ \t]/ && keys == "") { h = line; sub(/^#+[ \t]+/, "", h); emit(h) }
        item = line
        if (item ~ /^- /) { sub(/^- +/, "", item); if (keys == "") emit(item) }
        if (match(item, /^[^:#"\047]+:[ \t]+/)) {
          k = substr(item, 1, RLENGTH); sub(/:[ \t]+$/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", k)
          v = substr(item, RLENGTH + 1)
          if (keys == "" || (k in want)) emit(v)
        }
        if (keys == "") {
          rest = line
          while (match(rest, /"[^"]+"/)) { emit(substr(rest, RSTART + 1, RLENGTH - 2)); rest = substr(rest, RSTART + RLENGTH) }
          rest = line
          while (match(rest, /\047[^\047]+\047/)) { emit(substr(rest, RSTART + 1, RLENGTH - 2)); rest = substr(rest, RSTART + RLENGTH) }
        }
      }' "$file")"
  fi

  printf '%s\n' "$raw" | awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    {
      s = trim($0)
      sub(/^=[ \t]*/, "", s)                    # Power Fx: ="Submit"
      if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s = substr(s, 2, length(s) - 2)
      gsub(/[ \t]+/, " ", s)
      s = trim(s)
      sub(/(…|\.\.\.|:)$/, "", s)
      s = trim(s)
      if (s == "" || length(s) > 100) next
      if (s ~ /^[0-9.+-]+$/ || s ~ /^(true|false|null)$/ || s ~ /:\/\//) next
      print s
    }' | sort -u
}
