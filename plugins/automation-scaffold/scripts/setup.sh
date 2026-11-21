#!/usr/bin/env bash
# setup.sh — the plugin's local configuration (~/.config/automation-scaffold/config.json).
# Holds IDs, URLs and Keychain item NAMES only; never a secret. There is deliberately no
# GitHub owner setting: the repository is always given by the user or asked for.
#
#   setup.sh show
#   setup.sh set <key> <value>      keys below
#   setup.sh unset <key>
#
# Keys:
#   workspaceDir                    folder that holds local clones (required; no default)
#   author.name, author.email       commit author for scaffold commits
#   powerPlatform.environmentId     e.g. Default-<tenant guid>
#   powerPlatform.environmentName   display name, for documents
#   n8n.url                         e.g. https://<name>.app.n8n.cloud
#   n8n.keychainItem                Keychain item (service) holding the n8n API key
#   make.zone                       e.g. eu1.make.com
#   make.teamId                     Make team id
#   make.keychainItem               Keychain item (service) holding the Make API token
#   azBin                           path to az when it is not on PATH
#
# EXIT CODES: 0 ok · 1 error · 2 usage

set -euo pipefail

readonly DIR="${AUTOMATION_SCAFFOLD_CONFIG_DIR:-$HOME/.config/automation-scaffold}"
readonly CONFIG="$DIR/config.json"
readonly KEYS="workspaceDir author.name author.email powerPlatform.environmentId powerPlatform.environmentName n8n.url n8n.keychainItem make.zone make.teamId make.keychainItem azBin"

die() { echo "setup.sh: $1" >&2; exit "${2:-1}"; }

mkdir -p "$DIR"
[[ -f "$CONFIG" ]] || echo '{}' >"$CONFIG"

valid_key() { [[ " $KEYS " == *" $1 "* ]] || die "unknown key '$1' (one of: $KEYS)" 2; }

update() {
  local tmp
  tmp="$(mktemp "$CONFIG.XXXXXX")"
  if jq "$@" "$CONFIG" >"$tmp"; then mv "$tmp" "$CONFIG"; else rm -f "$tmp"; die "could not update $CONFIG"; fi
}

case "${1:-}" in
  show)
    jq . "$CONFIG"
    ;;
  set)
    key="${2:-}" value="${3:-}"
    [[ -n "$key" && -n "$value" ]] || die "usage: setup.sh set <key> <value>" 2
    valid_key "$key"
    case "$key" in
      n8n.url) [[ "$value" =~ ^https:// ]] || die "n8n.url must start with https://" 2 ;;
      author.email) [[ "$value" =~ ^[^@[:space:]]+@[^@[:space:]]+$ ]] || die "not an email: $value" 2 ;;
      powerPlatform.environmentId)
        [[ "$value" =~ ^([A-Za-z]+-)?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
          || die "environment id must be a GUID, optionally prefixed (e.g. Default-<guid>): $value" 2 ;;
    esac
    # Refuse anything shaped like a secret: this file holds names, never values. The
    # environment id is exempt: it was format-checked above and is a GUID, not a secret.
    if [[ "$key" != powerPlatform.environmentId ]] && grep -Eq '^(eyJ|sk-|xox|ghp_|gho_)|^[A-Za-z0-9+/=_-]{40,}$' <<<"$value"; then
      die "that looks like a secret; store it in the Keychain and set the item NAME instead" 2
    fi
    update --arg k "$key" --arg v "$value" 'setpath($k | split("."); $v)'
    echo "set $key"
    ;;
  unset)
    valid_key "${2:-}"
    update --arg k "$2" 'delpaths([$k | split(".")])'
    echo "unset $2"
    ;;
  *) die "usage: setup.sh show | set <key> <value> | unset <key>" 2 ;;
esac
