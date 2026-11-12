# rca-lint.awk — check a root-cause note.   awk -v name=<label> -f rca-lint.awk <rca.md>
# Findings print as  name:LINE: rule: message. Exit 3 when there are findings.
# The rollback snapshot is verified by the caller (it needs the filesystem). POSIX awk only.

function finding(rule, msg) { printf "%s:%d: %s: %s\n", name, FNR, rule, msg; nfind++ }
function section_of(h,    s) { s = tolower(h); sub(/^[ \t]*#+[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

BEGIN {
  split("summary|impact|timeline|root cause|resolution|prevention|rollback|deferred work", REQ, "|")
  nreq = 8; cur = ""; infence = 0; lastidx = 0
}

/^[ \t]*```/ {
  if (!infence && cur == "root cause") nquote++
  infence = !infence
  next
}
infence { next }

/^##[ \t]/ {
  cur = section_of($0); seen[cur] = 1
  for (i = 1; i <= nreq; i++) if (cur == REQ[i]) {
    if (i < lastidx) finding("section-order", "section \"" cur "\" is out of order; expected: summary, impact, timeline, root cause, resolution, prevention, rollback, deferred work")
    lastidx = i
  }
  next
}

{
  line = $0
  if (line ~ /[^ \t]/ && cur != "") nbody[cur]++

  if (cur == "timeline" && line ~ /^[ \t]*[-*0-9]/) ntimeline++

  if (cur == "root cause" && line ~ /^[ \t]*[-*][ \t]/) {
    ncause++
    if (line !~ /\[source:[ \t]*[^]]{3,}\]/) finding("evidence-missing", "a root-cause statement without [source: ...]: quote the log line or config that shows it")
  }

  if (cur == "resolution" && line ~ /^Contained:[ \t]+[^<[:space:]]/) contained = 1

  if (cur == "prevention" && line ~ /^[ \t]*([-*]|[0-9]+\.)[ \t]/) nprev++

  low = " " tolower(line) " "
  if (low ~ /[^a-z](human error|operator error|user error|careless|carelessly|negligent|negligence|incompetent|incompetence|blame|blamed|at fault)[^a-z]/ ||
      low ~ /[^a-z]fault of[^a-z]/ ||
      low ~ /[^a-z]should have (known|checked|noticed|caught|tested|read|realized|realised)[^a-z]/ ||
      low ~ /[^a-z](forgot to|failed to (notice|check|read|test|review|verify))[^a-z]/) {
    finding("blame-language", "write about systems and conditions, not people: say what the process allowed, not who missed it")
  }

  if (line ~ /(TODO|TBD|FIXME)/ || line ~ /<[A-Za-z][^>]*>/) finding("placeholder", "unfilled placeholder or TODO")
}

END {
  FNR = 0
  for (i = 1; i <= nreq; i++) if (!(REQ[i] in seen)) finding("section-missing", "missing section \"## " REQ[i] "\"")
  if (("root cause" in seen) && ncause == 0) finding("evidence-missing", "\"Root cause\" has no bullets with [source: ...]")
  if (("root cause" in seen) && nquote == 0) finding("evidence-quote", "\"Root cause\" needs at least one verbatim excerpt in a fenced block (the log line or config)")
  if (("timeline" in seen) && ntimeline == 0) finding("timeline-empty", "the timeline has no entries")
  if (("resolution" in seen) && !contained) finding("contained-missing", "the Resolution section needs a line \"Contained: <what stopped the impact, and when>\"")
  if (("prevention" in seen) && nprev != 1) finding("prevention-count", "propose exactly one prevention step (found " nprev + 0 ")")
  if (("deferred work" in seen) && nbody["deferred work"] == 0) finding("deferred-empty", "list optimisations deferred until after the incident, or write \"none\"")
  exit (nfind > 0 ? 3 : 0)
}
