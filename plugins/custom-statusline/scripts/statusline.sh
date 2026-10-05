#!/bin/bash
# Generic Claude Code status line — works the same in any git repo, any
# language/ecosystem. No project-specific paths, tag prefixes, or names are
# hardcoded here; everything is detected at render time.
#
# Reads Claude Code's status JSON from stdin, prints a 3-line status:
#   1. repo path + branch + git indicators + release tag(s) + age
#   2. model + effort/thinking badge + context-window usage bar + session cost
#   3. GitHub URL (origin) + public/private visibility badge
#
# Indicators:
#   M = Modified (unstaged)    D = Deleted (unstaged)
#   S = Staged (for commit)    U = Untracked (new files)
#   ↑ = Commits ahead          ↓ = Commits behind
#   ≡ = Stash count            ⚠ = Merge conflicts
#
# Install: copy this file into the target repo (e.g. .claude/statusline.sh)
# and point .claude/settings.json's "statusLine" at it — see
# ../SKILL.md for the one-command install flow.

# The statusline must OBSERVE repo state, never CONTEND for it. Every render
# runs `git status`/`git diff`, which by default take .git/index.lock to
# refresh the index — fired on every prompt render, that can race a
# concurrent `git commit`/`git add` in the same checkout. This makes git
# subprocesses here skip the OPTIONAL index lock (same mechanism VS Code
# uses); status/diff still report correctly, they just don't write the lock.
export GIT_OPTIONAL_LOCKS=0

RESET='\033[0m'
GRAY='\033[90m'
YELLOW='\033[33m'
RED='\033[91m'
GREEN='\033[92m'
CYAN='\033[96m'

# Strips proxy env vars before any gh/curl call, so a proxy configured for
# other purposes on this machine can never silently break (or MITM) the
# status line's outbound calls. Cheap defensive default even on machines
# that don't currently run one.
probe_direct() {
    env -u HTTPS_PROXY -u HTTP_PROXY -u ALL_PROXY -u https_proxy -u http_proxy -u all_proxy "$@"
}

input=$(cat)

# One batched jq call decodes every top-level field we need — avoids paying
# a jq cold-start per field on every render.
IFS=$'\x1f' read -r model_name effort_level thinking_enabled cost git_branch \
    ctx_used ctx_window session_id <<< "$(
    echo "$input" | jq -r '
        [
            (.model.display_name // .model.id // ""),
            (.effort.level // ""),
            (.thinking.enabled | if . == null then "" else tostring end),
            (.cost.total_cost_usd // ""),
            (.git.branch // ""),
            (.context_window.total_input_tokens // "" | tostring),
            (.context_window.context_window_size // "" | tostring),
            (.session_id // .session.id // "")
        ] | join("")' 2>/dev/null \
        || printf '\x1f\x1f\x1f\x1f\x1f\x1f'
)"

repo_path=$(pwd | sed "s|$HOME|~|")

if [ -z "$git_branch" ]; then
    git_branch=$(git branch --show-current 2>/dev/null)
    [ -z "$git_branch" ] && git_branch=$(git rev-parse --short HEAD 2>/dev/null)
fi

# === Git status indicators ===
colorize_stat() {
    local label="$1" value="$2" color="${3:-$YELLOW}"
    if [ "$value" -eq 0 ]; then
        printf '%b%s:%s%b' "$GRAY" "$label" "$value" "$RESET"
    else
        printf '%b%s:%s%b' "$color" "$label" "$value" "$RESET"
    fi
}

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    modified=$(git diff --name-only --diff-filter=M 2>/dev/null | wc -l | tr -d ' ')
    deleted=$(git diff --name-only --diff-filter=D 2>/dev/null | wc -l | tr -d ' ')
    staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
else
    modified=0; deleted=0; staged=0; untracked=0
fi

ahead=0; behind=0
if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    ahead=$(git rev-list '@{u}..HEAD' --count 2>/dev/null || echo 0)
    behind=$(git rev-list 'HEAD..@{u}' --count 2>/dev/null || echo 0)
fi
stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
conflicts=$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l | tr -d ' ')

git_line="$(colorize_stat M "$modified") $(colorize_stat D "$deleted") $(colorize_stat S "$staged") $(colorize_stat U "$untracked")"
if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    git_line="${git_line} $(colorize_stat ↑ "$ahead") $(colorize_stat ↓ "$behind")"
fi
git_line="${git_line} $(colorize_stat ≡ "$stash_count") $(colorize_stat ⚠ "$conflicts" "$RED")"

# === Release tag(s) — auto-detected, no per-repo configuration ===
#
# Most repos tag plain semver (v1.2.3) — that's the "default" group below.
# Some repos (independently-versioned monorepo streams) namespace tags as
# <name>-v1.2.3 (e.g. server-v1.2.0, web-v1.0.3); each distinct name becomes
# its own group, shown side by side. Either way this needs zero
# configuration: it reads whatever tags actually exist.
reltime() {
    local diff=$(( $(date +%s) - $1 ))
    if   (( diff < 60 ));     then printf '%ds'  "$diff"
    elif (( diff < 3600 ));   then printf '%dm'  "$(( diff / 60 ))"
    elif (( diff < 86400 ));  then printf '%dh'  "$(( diff / 3600 ))"
    elif (( diff < 604800 )); then printf '%dd'  "$(( diff / 86400 ))"
    else                           printf '%dw'  "$(( diff / 604800 ))"
    fi
}

render_tags() {
    local all_tags groups g tag epoch entry line=""
    all_tags=$(git tag -l 2>/dev/null)
    if [ -z "$all_tags" ]; then
        printf '%b∅ no releases yet%b' "$GRAY" "$RESET"
        return
    fi

    groups=$(echo "$all_tags" | sed -nE 's/^([A-Za-z0-9_.]+)-v[0-9]+\.[0-9]+\.[0-9]+.*/\1/p' | sort -u)
    echo "$all_tags" | grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+' && groups=$(printf '%s\n__default__\n' "$groups")
    groups=$(echo "$groups" | sort -u)

    for g in $groups; do
        if [ "$g" = "__default__" ]; then
            tag=$(echo "$all_tags" | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1)
        else
            tag=$(echo "$all_tags" | grep -E "^${g}-v[0-9]" | sort -V | tail -1)
        fi
        [ -z "$tag" ] && continue
        epoch=$(git log -1 --format=%at "$tag" 2>/dev/null)
        entry="${CYAN}${tag}${RESET}"
        [ -n "$epoch" ] && entry="${entry} ${GRAY}($(reltime "$epoch") ago)${RESET}"
        line="${line}${line:+ }${entry}"
    done
    printf '%b' "$line"
}

line1="${GREEN}${repo_path}${RESET} ${GRAY}(${git_branch})${RESET}  ${git_line}  ${GRAY}|${RESET} $(render_tags)"

# === Model + context window + cost ===
cfmt() {
    local n="$1"
    if   [ "$n" -ge 1000000 ] 2>/dev/null; then printf '%dM' $(( n / 1000000 ))
    elif [ "$n" -ge 1000 ]    2>/dev/null; then printf '%dk' $(( n / 1000 ))
    else                                        printf '%s' "$n"
    fi
}

context_bar() {
    local used="$1" total="$2" width=10 pct filled i bar="" color
    if [ -z "$used" ] || [ -z "$total" ] || [ "$total" -le 0 ] 2>/dev/null; then
        return
    fi
    pct=$(( used * 100 / total ))
    filled=$(( pct * width / 100 ))
    [ "$filled" -gt "$width" ] && filled=$width
    for ((i = 0; i < width; i++)); do
        if [ "$i" -lt "$filled" ]; then bar="${bar}█"; else bar="${bar}░"; fi
    done
    color="$GREEN"
    [ "$pct" -ge 70 ] && color="$YELLOW"
    [ "$pct" -ge 90 ] && color="$RED"
    printf '%b%s%b %s%% (%s/%s)' "$color" "$bar" "$RESET" "$pct" "$(cfmt "$used")" "$(cfmt "$total")"
}

ctx_display=""
ctx_rendered="$(context_bar "$ctx_used" "$ctx_window")"
[ -n "$ctx_rendered" ] && ctx_display=" ${GRAY}|${RESET} ctx ${ctx_rendered}"

badge=""
[ -n "$effort_level" ] && badge="${badge} ${GRAY}[${effort_level}]${RESET}"
[ "$thinking_enabled" = "true" ] && badge="${badge} ${GRAY}[thinking]${RESET}"

cost_display=""
[ -n "$cost" ] && cost_display=" ${GRAY}|${RESET} \$$(printf '%.4f' "$cost" 2>/dev/null || echo "$cost")"

line2="${model_name:-?}${badge}${ctx_display}${cost_display}"
[ -z "$session_id" ] || line2="${line2} ${GRAY}|${RESET} ${session_id}"

# === GitHub URL + visibility (cached, proxy-safe) ===
remote_url=$(git remote get-url origin 2>/dev/null)
line3=""
if [ -n "$remote_url" ]; then
    owner_repo=$(echo "$remote_url" | sed -E 's|git@github\.com:||; s|https://github\.com/||; s|\.git$||')
    https_url="https://github.com/${owner_repo}"
    if [ "$git_branch" != "main" ] && [ -n "$git_branch" ]; then
        https_url="${https_url}/tree/${git_branch}"
    fi

    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    vis_cache="${git_dir:-/tmp}/ccstatusline-visibility-cache"
    vis=""
    if [ -f "$vis_cache" ]; then
        age=$(( $(date +%s) - $(stat -c %Y "$vis_cache" 2>/dev/null || stat -f %m "$vis_cache" 2>/dev/null || echo 0) ))
        [ "$age" -lt 3600 ] && vis=$(cat "$vis_cache")
    fi
    if [ -z "$vis" ]; then
        vis=$(probe_direct timeout 2 gh api "repos/${owner_repo}" --jq 'if .private then "private" else "public" end' 2>/dev/null)
        [ -n "$vis" ] && echo "$vis" > "$vis_cache" 2>/dev/null
    fi

    line3="${CYAN}${https_url}${RESET}"
    [ -n "$vis" ] && line3="${line3} ${GRAY}[${vis}]${RESET}"
fi

printf '%b\n%b\n%b\n' "$line1" "$line2" "$line3"
