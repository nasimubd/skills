# brief-lint.awk — check a triage brief.   awk -v name=<label> -f brief-lint.awk <brief.md>
# Findings print as  name:LINE: rule: message. Exit 3 when there are findings.
# Fenced code is ignored. POSIX awk only.

function finding(rule, msg) { printf "%s:%d: %s: %s\n", name, FNR, rule, msg; nfind++ }

function section_of(h,    s) {
  s = tolower(h); sub(/^[ \t]*#+[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s
}

BEGIN {
  split("summary|what is known|what is not known|risks and constraints|plan|untrusted content seen|approval", REQ, "|")
  nreq = 7; nextreq = 1; cur = ""; infence = 0
}

/^[ \t]*```/ { infence = !infence; next }
infence { next }

FNR <= 12 {
  if ($0 ~ /^Source:[ \t]+[^<[:space:]]/) hassource = 1
  if ($0 ~ /^Captured:[ \t]+[^<[:space:]]/) hascaptured = 1
  if (tolower($0) ~ /^mode:[ \t]+read-only/) hasmode = 1
}

/^##[ \t]/ {
  cur = section_of($0)
  seen[cur] = 1
  # order: every required heading must appear after the one before it
  for (i = 1; i <= nreq; i++) if (cur == REQ[i]) {
    if (i < lastidx) finding("section-order", "section \"" cur "\" is out of order; expected: summary, what is known, what is not known, risks and constraints, plan, untrusted content seen, approval")
    lastidx = i
  }
  nbody[cur] = 0
  next
}

{
  line = $0
  if (line ~ /[^ \t]/ && cur != "") nbody[cur]++

  if (cur == "what is known" && line ~ /^[ \t]*[-*][ \t]/) {
    nknown++
    if (line !~ /\[source:[ \t]*[^]]{3,}\]/) finding("evidence-missing", "a fact without [source: ...]: say where it came from, or move it to \"What is not known\"")
  }

  if (cur == "plan" && line ~ /^[ \t]*[0-9]+\.[ \t]/) {
    nplan++
    if (line !~ /^[ \t]*[0-9]+\.[ \t]+\[(read|change)\]/) finding("plan-step-kind", "start each plan step with [read] or [change]")
    if (tolower(line) ~ /\[(done|executed|applied|completed)\]/) finding("plan-executed", "a triage brief proposes; it does not execute. A plan step is marked done")
  }

  if (cur == "approval" && tolower(line) ~ /^status:[ \t]+awaiting approval/) awaiting = 1

  if (line ~ /(TODO|TBD|FIXME)/ || line ~ /<[A-Za-z][^>]*>/) finding("placeholder", "unfilled placeholder or TODO")
}

END {
  FNR = 0
  if (!hassource) finding("header-source", "add a \"Source:\" line (the URL or identifier) near the top")
  if (!hascaptured) finding("header-captured", "add a \"Captured:\" line (when the source was read) near the top")
  if (!hasmode) finding("header-mode", "add \"Mode: read-only\" near the top")
  for (i = 1; i <= nreq; i++) if (!(REQ[i] in seen)) finding("section-missing", "missing section \"## " REQ[i] "\"")
  if (("what is known" in seen) && nknown == 0) finding("evidence-missing", "\"What is known\" has no bullets with [source: ...]")
  if (("plan" in seen) && nplan == 0) finding("plan-empty", "the plan has no numbered steps")
  if (("untrusted content seen" in seen) && nbody["untrusted content seen"] == 0) finding("untrusted-section-empty", "list instruction-like content found in the source, or write \"none\"")
  if (("approval" in seen) && !awaiting) finding("approval-missing", "the Approval section must say \"Status: awaiting approval\"")
  exit (nfind > 0 ? 3 : 0)
}
