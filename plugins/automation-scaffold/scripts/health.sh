#!/usr/bin/env bash
# health.sh — check everything a scaffold run needs, one line per check, then a count.
# Read-only: it asks the platforms for a token or a listing, never changes anything,
# and never prints a secret.
#
# EXIT CODES: 0 every required check passed · 1 a required check failed

set -uo pipefail

readonly CONFIG="${AUTOMATION_SCAFFOLD_CONFIG_DIR:-$HOME/.config/automation-scaffold}/config.json"
fails=0 warns=0 checked=0

check() {   # check <required|optional> <label> <command> <fix>
  local level="$1" label="$2" cmd="$3" fix="$4"
  checked=$((checked + 1))
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  ✓ $label"
  elif [[ "$level" == required ]]; then
    echo "  ✗ $label — $fix"; fails=$((fails + 1))
  else
    echo "  ! $label — $fix (optional)"; warns=$((warns + 1))
  fi
}
cfg() { jq -r "$1 // empty" "$CONFIG" 2>/dev/null; }

echo "automation-scaffold health"
check required "config file ($CONFIG)" "test -f '$CONFIG'" "run the setup skill"
check required "git" "command -v git" "install git"
check required "jq" "command -v jq" "install jq"
check required "unzip" "command -v unzip" "install unzip"
check required "node 22 or newer" "node -e 'process.exit(+process.versions.node.split(\".\")[0] >= 22 ? 0 : 1)'" "install Node.js 22+"
check required "npm" "command -v npm" "comes with Node.js"
check required "mise" "command -v mise" "install mise (https://mise.jdx.dev)"
check required "gh signed in" "gh auth status" "run: gh auth login"
check required "workspace folder configured (no default)" "test -n \"\$(cfg .workspaceDir)\" && test -d \"\$(cfg .workspaceDir)\"" "setup: set workspaceDir to an existing folder"
check required "commit author configured" "test -n \"\$(cfg .author.name)\" && test -n \"\$(cfg .author.email)\"" "setup: set author.name and author.email"

AZ="$(cfg .azBin)"; AZ="${AZ:-az}"
if [[ -n "$(cfg .powerPlatform.environmentId)" ]]; then
  check required "az available" "command -v '$AZ'" "install the Azure CLI or set azBin"
  check required "Power Apps token (az login)" "'$AZ' account get-access-token --resource https://service.powerapps.com/ --query expiresOn -o tsv" "run: az login"
  check required "Power Automate token (az login)" "'$AZ' account get-access-token --resource https://service.flow.microsoft.com/ --query expiresOn -o tsv" "run: az login"
else
  check optional "Power Platform environment configured" "false" "setup: set powerPlatform.environmentId"
fi

if [[ -n "$(cfg .n8n.url)" ]]; then
  item="$(cfg .n8n.keychainItem)"
  check required "n8n API key available" "test -n \"\${N8N_API_KEY:-}\" || security find-generic-password -a \"\$USER\" -s '$item' >/dev/null" "set N8N_API_KEY or add Keychain item '$item'"
  check required "n8n API readable with that key" "node '$(dirname "${BASH_SOURCE[0]}")/n8n-ping.js'" "check the key and n8n.url"
else
  check optional "n8n instance configured" "false" "setup: set n8n.url and n8n.keychainItem"
fi

if jq -e '(.platforms // []) | index("make")' "$CONFIG" >/dev/null 2>&1; then
  item="$(cfg .make.keychainItem)"
  check required "Make API token available" "test -n \"\${MAKE_API_TOKEN:-}\" || security find-generic-password -s '$item' >/dev/null" "set MAKE_API_TOKEN or add Keychain item '$item'"
  check required "Make team id configured" "test -n \"\$(cfg .make.teamId)\"" "setup: set make.teamId"
else
  echo "  - Make.com not in config.platforms; discovery does not query it"
fi

echo "Checked: $checked · failed: $fails · optional missing: $warns"
[[ "$fails" -eq 0 ]]
