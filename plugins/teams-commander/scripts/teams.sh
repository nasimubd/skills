#!/usr/bin/env bash
# teams.sh — evidence-gated Microsoft Teams message drafts, sent by deep link.
#
# A draft is a message plus a ledger of the claims it makes. Every factual claim
# carries its evidence (source, exact excerpt, capture time, how to reproduce).
# `verify` refuses a draft while any fact is unverified or stale, and `open`
# refuses to build a link for a message that has not passed `verify` in its
# current form. Tier 1 only: the link opens Teams with the text in the compose
# box and the person presses Send. Nothing here posts a message by itself.
#
# USAGE
#   teams.sh new [<draft-id>]
#   teams.sh claim <draft-id> --text T --kind fact|opinion|question
#                  [--source-type T --source S --excerpt E --reproduce R]
#   teams.sh refresh <draft-id> <claim-id> --excerpt E
#   teams.sh drop <draft-id> <claim-id>
#   teams.sh message <draft-id> [<file>|-]
#   teams.sh show <draft-id>
#   teams.sh verify <draft-id>
#   teams.sh link <draft-id> <contact>
#   teams.sh open <draft-id> <contact> [--dry-run]
#   teams.sh contact add <alias> <email[,email...]> [--name N] [--topic T]
#   teams.sh contact list
#   teams.sh contact tenant <tenant-id>
#   teams.sh health
#
# EXIT CODES
#   0 ok · 1 runtime error · 2 usage error · 3 refused by the evidence gate
#
# ENVIRONMENT
#   TEAMS_COMMANDER_STATE_DIR    drafts (default ~/.local/state/teams-commander)
#   TEAMS_COMMANDER_CONFIG_DIR   contacts (default ~/.config/teams-commander)
#   TEAMS_EVIDENCE_MAX_AGE_MIN   evidence older than this is stale (default 360)

set -euo pipefail

readonly SELF="teams.sh"
readonly STATE_DIR="${TEAMS_COMMANDER_STATE_DIR:-$HOME/.local/state/teams-commander}"
readonly CONFIG_DIR="${TEAMS_COMMANDER_CONFIG_DIR:-$HOME/.config/teams-commander}"
readonly CONTACTS="$CONFIG_DIR/contacts.json"
readonly MAX_AGE_MIN="${TEAMS_EVIDENCE_MAX_AGE_MIN:-360}"
readonly LINK_BASE="https://teams.microsoft.com/l/chat/0/0"

die() { echo "$SELF: $1" >&2; exit "${2:-1}"; }
usage() { die "usage: $1" 2; }
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

draft_dir() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || usage "draft id must match [A-Za-z0-9._-]+"
  printf '%s/drafts/%s' "$STATE_DIR" "$1"
}

ledger_of() {
  local dir
  dir="$(draft_dir "$1")"
  [[ -f "$dir/ledger.json" ]] || die "no draft '$1' (run: $SELF new $1)"
  printf '%s/ledger.json' "$dir"
}

# Rewrite a JSON file through a jq filter, atomically.
jq_update() {
  local file="$1"; shift
  local tmp
  tmp="$(mktemp "$file.XXXXXX")"
  if jq "$@" "$file" >"$tmp"; then mv "$tmp" "$file"; else rm -f "$tmp"; die "could not update $file"; fi
}

sha_of() { shasum -a 256 "$1" | cut -d' ' -f1; }

# Evidence must never carry a credential (standing rule: credentials are not
# read, copied or stored). Refuse the common token and password shapes.
refuse_secrets() {
  if grep -Eiq 'bearer [a-z0-9._~+/-]{20,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|(password|passwd|pwd|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*[^[:space:]]{6,}|-----BEGIN [A-Z ]*PRIVATE KEY' <<<"$1"; then
    die "evidence looks like it contains a credential; quote the surrounding fact instead" 2
  fi
}

# The derived status of every claim, as a JSON array. Status is never stored:
# it is recomputed from the evidence and the clock each time it is asked for.
claims_with_status() {
  jq --argjson max "$MAX_AGE_MIN" --argjson now "$(date -u +%s)" '
    .claims | map(. + {status: (
      if .kind != "fact" then .kind
      elif ((.source // "") == "" or (.excerpt // "") == "" or (.source_type // "") == "") then "unverified"
      elif ($now - (.captured_at | fromdateiso8601)) > ($max * 60) then "stale"
      else "verified" end)})' "$1"
}

cmd_new() {
  local id="${1:-$(date -u +%Y%m%d-%H%M%S)}" dir
  dir="$(draft_dir "$id")"
  [[ -e "$dir" ]] && die "draft '$id' already exists"
  mkdir -p "$dir"
  jq -n --arg id "$id" --arg at "$(now_iso)" \
    '{id: $id, created_at: $at, next: 1, claims: [], verified: null, opened: []}' >"$dir/ledger.json"
  echo "$id"
}

cmd_claim() {
  local id="${1:-}"; shift || true
  [[ -n "$id" ]] || usage "$SELF claim <draft-id> --text T --kind fact|opinion|question [...]"
  local text="" kind="" stype="" source="" excerpt="" reproduce=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --text) text="$2"; shift 2 ;;
      --kind) kind="$2"; shift 2 ;;
      --source-type) stype="$2"; shift 2 ;;
      --source) source="$2"; shift 2 ;;
      --excerpt) excerpt="$2"; shift 2 ;;
      --reproduce) reproduce="$2"; shift 2 ;;
      *) usage "unknown option '$1'" ;;
    esac
  done
  [[ -n "$text" ]] || usage "--text is required"
  [[ "$kind" =~ ^(fact|opinion|question)$ ]] || usage "--kind must be fact, opinion or question"
  refuse_secrets "$excerpt"
  local ledger
  ledger="$(ledger_of "$id")"
  jq_update "$ledger" --arg text "$text" --arg kind "$kind" --arg st "$stype" --arg src "$source" \
    --arg ex "$excerpt" --arg rep "$reproduce" --arg at "$(now_iso)" '
    .claims += [{id: ("C" + (.next | tostring)), text: $text, kind: $kind, source_type: $st,
                 source: $src, excerpt: $ex, reproduce: $rep, captured_at: $at}]
    | .next += 1 | .verified = null'
  jq -r '.claims[-1].id' "$ledger"
}

cmd_refresh() {
  local id="${1:-}" cid="${2:-}"
  [[ -n "$id" && -n "$cid" && "${3:-}" == "--excerpt" && -n "${4:-}" ]] \
    || usage "$SELF refresh <draft-id> <claim-id> --excerpt E"
  refuse_secrets "$4"
  local ledger
  ledger="$(ledger_of "$id")"
  jq -e --arg c "$cid" 'any(.claims[]; .id == $c)' "$ledger" >/dev/null || die "no claim '$cid' in '$id'"
  jq_update "$ledger" --arg c "$cid" --arg ex "$4" --arg at "$(now_iso)" \
    '(.claims[] | select(.id == $c)) |= (.excerpt = $ex | .captured_at = $at) | .verified = null'
  echo "$cid refreshed"
}

cmd_drop() {
  local id="${1:-}" cid="${2:-}"
  [[ -n "$id" && -n "$cid" ]] || usage "$SELF drop <draft-id> <claim-id>"
  local ledger
  ledger="$(ledger_of "$id")"
  jq -e --arg c "$cid" 'any(.claims[]; .id == $c)' "$ledger" >/dev/null || die "no claim '$cid' in '$id'"
  jq_update "$ledger" --arg c "$cid" '.claims |= map(select(.id != $c)) | .verified = null'
  echo "$cid dropped"
}

cmd_message() {
  local id="${1:-}" src="${2:--}"
  [[ -n "$id" ]] || usage "$SELF message <draft-id> [<file>|-]"
  local ledger dir
  ledger="$(ledger_of "$id")"
  dir="$(dirname "$ledger")"
  if [[ "$src" == "-" ]]; then cat >"$dir/message.txt"; else cp "$src" "$dir/message.txt"; fi
  [[ -s "$dir/message.txt" ]] || die "message is empty"
  jq_update "$ledger" '.verified = null'
  echo "message stored ($(wc -c <"$dir/message.txt" | tr -d ' ') bytes)"
}

cmd_show() {
  local id="${1:-}"
  [[ -n "$id" ]] || usage "$SELF show <draft-id>"
  local ledger dir
  ledger="$(ledger_of "$id")"
  dir="$(dirname "$ledger")"
  echo "## Message"
  echo
  if [[ -s "$dir/message.txt" ]]; then cat "$dir/message.txt"; else echo "(no message stored yet)"; fi
  echo
  echo "## Evidence"
  echo
  echo "| Claim | Status | Statement | Source | Excerpt | Captured (UTC) | Reproduce |"
  echo "|---|---|---|---|---|---|---|"
  claims_with_status "$ledger" | jq -r '
    def cell: tostring | gsub("\\|"; "\\|") | gsub("\n"; " ");
    .[] | "| \(.id) | \(.status) | \(.text|cell) | \((.source_type + " " + .source)|cell) | \(.excerpt|cell) | \(.captured_at) | \(.reproduce|cell) |"'
  echo
  claims_with_status "$ledger" | jq -r '
    "Claims: \(length) · verified \(map(select(.status=="verified"))|length) · stale \(map(select(.status=="stale"))|length) · unverified \(map(select(.status=="unverified"))|length) · opinion \(map(select(.status=="opinion"))|length) · question \(map(select(.status=="question"))|length)"'
}

cmd_verify() {
  local id="${1:-}"
  [[ -n "$id" ]] || usage "$SELF verify <draft-id>"
  local ledger dir claims problems=0
  ledger="$(ledger_of "$id")"
  dir="$(dirname "$ledger")"
  claims="$(claims_with_status "$ledger")"
  echo "Examined: message $( [[ -s "$dir/message.txt" ]] && echo present || echo missing), $(jq length <<<"$claims") claim(s)"
  if [[ ! -s "$dir/message.txt" ]]; then echo "  ✗ no message stored"; problems=$((problems + 1)); fi
  if [[ "$(jq length <<<"$claims")" -eq 0 ]]; then
    echo "  ✗ no claims recorded; every message states at least one fact or question"
    problems=$((problems + 1))
  fi
  while IFS=$'\t' read -r cid status text; do
    [[ -z "$cid" ]] && continue
    echo "  ✗ $cid $status: $text"
    problems=$((problems + 1))
  done < <(jq -r '.[] | select(.status == "unverified" or .status == "stale") | [.id, .status, .text] | @tsv' <<<"$claims")
  if [[ "$problems" -gt 0 ]]; then
    jq_update "$ledger" '.verified = null'
    echo "REFUSED: $problems problem(s). Add evidence, refresh stale evidence, or drop/rephrase the claim."
    exit 3
  fi
  jq_update "$ledger" --arg sha "$(sha_of "$dir/message.txt")" --arg at "$(now_iso)" \
    '.verified = {message_sha256: $sha, at: $at}'
  echo "VERIFIED: every fact has current evidence."
}

# The gate `link` and `open` share: the stored verification must match the
# message as it is now, and the evidence must still be current.
require_verified() {
  local ledger="$1" dir
  dir="$(dirname "$ledger")"
  [[ -s "$dir/message.txt" ]] || die "no message stored" 3
  local want
  want="$(jq -r '.verified.message_sha256 // ""' "$ledger")"
  [[ -n "$want" ]] || die "draft has not passed verify (run: $SELF verify <draft-id>)" 3
  [[ "$want" == "$(sha_of "$dir/message.txt")" ]] || die "message changed after verify; run verify again" 3
  if claims_with_status "$ledger" | jq -e 'any(.[]; .status == "unverified" or .status == "stale")' >/dev/null; then
    die "evidence went stale since verify; refresh it and verify again" 3
  fi
}

contact_json() {
  [[ -f "$CONTACTS" ]] || die "no contacts file at $CONTACTS (run: $SELF contact add ...)"
  jq -e --arg a "$1" '.contacts[$a] // empty' "$CONTACTS" || die "no contact '$1' (run: $SELF contact list)"
}

build_link() {
  local ledger="$1" alias="$2" dir contact tenant
  dir="$(dirname "$ledger")"
  contact="$(contact_json "$alias")"
  tenant="$(jq -r '.tenant_id // ""' "$CONTACTS")"
  jq -rn --arg base "$LINK_BASE" --arg tenant "$tenant" --argjson c "$contact" \
    --rawfile msg "$dir/message.txt" '
    [ (if $tenant != "" then "tenantId=" + ($tenant|@uri) else empty end),
      "users=" + ($c.emails | map(@uri) | join(",")),
      (if ($c.topic // "") != "" then "topicName=" + ($c.topic|@uri) else empty end),
      "message=" + ($msg | sub("\n+$"; "") | @uri) ]
    | $base + "?" + join("&")'
}

cmd_link() {
  local id="${1:-}" alias="${2:-}"
  [[ -n "$id" && -n "$alias" ]] || usage "$SELF link <draft-id> <contact>"
  local ledger
  ledger="$(ledger_of "$id")"
  require_verified "$ledger"
  build_link "$ledger" "$alias"
}

cmd_open() {
  local id="${1:-}" alias="${2:-}" dry=false
  [[ -n "$id" && -n "$alias" ]] || usage "$SELF open <draft-id> <contact> [--dry-run]"
  [[ "${3:-}" == "--dry-run" ]] && dry=true
  local ledger dir url
  ledger="$(ledger_of "$id")"
  dir="$(dirname "$ledger")"
  require_verified "$ledger"
  url="$(build_link "$ledger" "$alias")"
  # The clipboard copy is the fallback for whatever the link cannot carry:
  # Microsoft documents no length limit and no line-break behaviour for it.
  pbcopy <"$dir/message.txt"
  echo "Message copied to the clipboard ($(wc -c <"$dir/message.txt" | tr -d ' ') bytes); link is ${#url} characters."
  if $dry; then
    echo "DRY RUN — not opened: $url"
    return 0
  fi
  open "$url"
  jq_update "$ledger" --arg at "$(now_iso)" --arg c "$alias" --argjson n "${#url}" \
    '.opened += [{at: $at, contact: $c, url_length: $n}]'
  echo "Opened Teams for '$alias'. Check the compose box, then press Send yourself."
}

cmd_contact() {
  local sub="${1:-}"; shift || true
  mkdir -p "$CONFIG_DIR"
  [[ -f "$CONTACTS" ]] || echo '{"tenant_id": "", "contacts": {}}' >"$CONTACTS"
  case "$sub" in
    add)
      local alias="${1:-}" emails="${2:-}" name="" topic=""
      [[ -n "$alias" && -n "$emails" ]] || usage "$SELF contact add <alias> <email[,email...]> [--name N] [--topic T]"
      shift 2
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --name) name="$2"; shift 2 ;;
          --topic) topic="$2"; shift 2 ;;
          *) usage "unknown option '$1'" ;;
        esac
      done
      [[ "$alias" =~ ^[a-z0-9._-]+$ ]] || usage "alias must be lowercase [a-z0-9._-]"
      local e
      for e in ${emails//,/ }; do
        [[ "$e" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || usage "not an email/UPN: $e"
      done
      jq_update "$CONTACTS" --arg a "$alias" --arg e "$emails" --arg n "$name" --arg t "$topic" \
        '.contacts[$a] = {name: $n, emails: ($e | split(",")), topic: $t}'
      echo "contact '$alias' saved"
      ;;
    list)
      jq -r '.contacts | to_entries[] | "\(.key)\t\(.value.name)\t\(.value.emails | join(","))\t\(.value.topic)"' "$CONTACTS"
      ;;
    tenant)
      [[ "${1:-}" =~ ^[0-9a-fA-F-]{36}$ ]] || usage "$SELF contact tenant <tenant-guid>"
      jq_update "$CONTACTS" --arg t "$1" '.tenant_id = $t'
      echo "tenant set"
      ;;
    *) usage "$SELF contact add|list|tenant" ;;
  esac
}

cmd_health() {
  local fails=0 checked=0
  check() {
    checked=$((checked + 1))
    if eval "$2" >/dev/null 2>&1; then echo "  ✓ $1"; else echo "  ✗ $1 — $3"; fails=$((fails + 1)); fi
  }
  echo "teams-commander health"
  check "jq installed" "command -v jq" "install jq"
  check "shasum installed" "command -v shasum" "macOS ships it; check PATH"
  check "pbcopy available" "command -v pbcopy" "clipboard fallback needs macOS pbcopy"
  check "open available" "command -v open" "the deep link is opened with macOS open"
  check "Microsoft Teams installed" "open -Ra 'Microsoft Teams'" "links will open in the browser instead"
  check "state dir writable ($STATE_DIR)" "mkdir -p '$STATE_DIR' && test -w '$STATE_DIR'" "check permissions"
  check "contacts file present ($CONTACTS)" "test -f '$CONTACTS'" "run the setup skill"
  check "contacts file is valid JSON with contacts" "jq -e '.contacts | length > 0' '$CONTACTS'" "add a contact"  echo "Checked: $checked · failed: $fails"
  [[ "$fails" -eq 0 ]]
}

main() {
  local cmd="${1:-}"; shift || true
  command -v jq >/dev/null || die "jq is required"
  case "$cmd" in
    new) cmd_new "$@" ;;
    claim) cmd_claim "$@" ;;
    refresh) cmd_refresh "$@" ;;
    drop) cmd_drop "$@" ;;
    message) cmd_message "$@" ;;
    show) cmd_show "$@" ;;
    verify) cmd_verify "$@" ;;
    link) cmd_link "$@" ;;
    open) cmd_open "$@" ;;
    contact) cmd_contact "$@" ;;
    health) cmd_health ;;
    *) usage "$SELF new|claim|refresh|drop|message|show|verify|link|open|contact|health (see header)" ;;
  esac
}

main "$@"
