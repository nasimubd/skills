# lint.awk — check a click-path guide against the labels of its source of truth.
#
#   awk -v guide=<name shown> -v allow="A,B" -f lint.awk <labels-file> <guide.md>
#
# The first file is the label list (one per line, already normalised); the second is the guide.
# Findings print as  guide:LINE: rule-id: message. Exit status 3 when there are findings.
#
# Text inside fenced code blocks and `inline code` is ignored. Bold is reserved for interface
# elements, so every bold term must be a label (or explicitly allowed). POSIX awk only.

function norm(s) {
  gsub(/[ \t]+/, " ", s)
  sub(/^ /, "", s)
  sub(/ $/, "", s)
  sub(/(…|\.\.\.|:)$/, "", s)
  sub(/ $/, "", s)
  return s
}

function finding(rule, msg) {
  printf "%s:%d: %s: %s\n", guide, FNR, rule, msg
  nfind++
}

function has(pattern, text) { return text ~ pattern }

BEGIN {
  nallow = split(allow, aa, ",")
  for (i = 1; i <= nallow; i++) { t = norm(aa[i]); if (t != "") allowed[t] = 1 }
  expected = 1; infence = 0; seenprereq = 0; nsteps = 0; checked = 0; nlabels = 0; nfind = 0
}

# --- first file: the labels -----------------------------------------------------------------
FNR == NR { t = norm($0); if (t != "") { labels[t] = 1; nlabels++ }; next }

# --- second file: the guide -------------------------------------------------------------------
/^[ \t]*```/ { infence = !infence; next }
infence { next }

{
  line = $0
  isheading = (line ~ /^[ \t]*#+[ \t]/)

  if (isheading && tolower(line) ~ /^[ \t]*#+[ \t]+prerequisites/) seenprereq = 1

  # Blank inline code so nothing inside it is judged.
  t = line
  gsub(/`[^`]*`/, "[C]", t)

  # Pull the bold terms out; leave "[B]" in their place for the later checks.
  plain = ""
  rest = t
  offset = 0
  while (match(rest, /\*\*[^*]+\*\*/)) {
    term = substr(rest, RSTART + 2, RLENGTH - 4)
    plain = plain substr(rest, 1, RSTART - 1) "[B]"
    atstart = (offset == 0 && RSTART == 1)
    offset += RSTART + RLENGTH - 1
    rest = substr(rest, RSTART + RLENGTH)
    if (isheading) continue
    nt = norm(term)
    if (atstart && term ~ /:[ \t]*$/) continue          # a callout such as **Note:**
    checked++
    if (!(nt in labels) && !(nt in allowed)) {
      finding("ui-label-unverified", "bold text \"" nt "\" is not a label in the source. Bold is for interface elements only: use plain text for emphasis, or take the label from the source")
    }
  }
  plain = plain rest

  # Numbered steps: consecutive from 1, and only after a Prerequisites section.
  if (line ~ /^[ \t]*[0-9]+\.[ \t]/) {
    n = line
    sub(/^[ \t]*/, "", n)
    sub(/\..*$/, "", n)
    n = n + 0
    nsteps++
    if (nsteps == 1 && !seenprereq) finding("prerequisites-missing", "a Prerequisites section must come before the first step")
    if (n != expected) finding("step-number", "step " n " where " expected " was expected: number the steps 1, 2, 3 without gaps")
    expected = n + 1
  }

  if (isheading) next

  # Menu paths: bold items joined by " > ", never arrows.
  if (plain ~ /(->|→|=>|»|>>)/) finding("menu-separator", "write a menu path as **File** > **Open**, with a right angle bracket and spaces, not an arrow")
  if (plain ~ /[A-Za-z0-9_)] > [A-Za-z0-9_(]/) finding("menu-bold", "bold every item of a menu path: **File** > **Open**")

  low = " " tolower(plain) " "

  # Sensory and positional identification (WCAG 2.1, 1.3.3).
  if (low ~ /[^a-z](to|on|at|in|from) the (left|right|top|bottom|upper|lower|middle|center|centre)/ ||
      low ~ /[^a-z](above|below|underneath|beneath)[^a-z]/ ||
      low ~ /[^a-z](next to|beside) the[^a-z]/ ||
      low ~ /[^a-z](upper|lower|top|bottom)[- ](left|right)/ ||
      low ~ /[^a-z]the (red|green|blue|yellow|orange|purple|pink|grey|gray|black|white) (button|icon|link|text|box|bar|tab|field|menu|arrow|square|circle|dot|badge)/ ||
      low ~ /[^a-z](round|square|circular|rectangular|big|large|small|tiny|bigger|smaller) (button|icon|link|box|tab|arrow)/) {
    finding("sensory-language", "do not identify a control by position, colour, shape or size; use its text label")
  }

  # Filler.
  if (low ~ /[^a-z-](simply|just|easily|easy|seamless|seamlessly|powerful|obviously|basically|very)[^a-z-]/ || low ~ /[^a-z-]of course[^a-z-]/) {
    finding("filler-word", "drop filler (simply, just, easily, powerful, obviously, very): write the imperative step")
  }

  # Leftovers.
  if (plain ~ /(TODO|TBD|FIXME)/ || plain ~ /<[A-Za-z][^>]*>/) finding("placeholder", "unfilled placeholder or TODO")
}

END {
  if (nsteps == 0) { printf "%s:0: no-steps: the guide has no numbered steps\n", guide; nfind++ }
  printf "Checked %d bold element(s) against %d source label(s); %d numbered step(s); findings: %d\n", checked, nlabels, nsteps, nfind
  exit (nfind > 0 ? 3 : 0)
}
