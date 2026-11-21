# redact.awk — one engine for finding and removing secret-like strings.
#
#   awk -v mode=scan   -v name=<label> -f redact.awk <file>   report line and kind, never the value
#   awk -v mode=redact                  -f redact.awk <file>   print the text with matches replaced
#
# Kinds are either "secret" (a credential; scan exits 3) or "pii" (personal data; reported as a
# warning only). The patterns are heuristics: they catch the common shapes and miss novel ones.
# POSIX awk only (macOS awk is the one-true-awk): case-insensitive matching is done by lowering a
# copy of the line, which keeps every position identical for ASCII.

function add(kind, sev, re, ci) { n++; K[n] = kind; S[n] = sev; R[n] = re; C[n] = ci }

BEGIN {
  add("private-key",   "secret", "-----BEGIN [A-Z ]*PRIVATE KEY-----", 0)
  add("aws-access-key","secret", "AKIA[0-9A-Z]{16}", 0)
  add("github-token",  "secret", "gh[pousr]_[A-Za-z0-9]{30,}", 0)
  add("slack-token",   "secret", "xox[baprs]-[A-Za-z0-9-]{10,}", 0)
  add("jwt",           "secret", "eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}", 0)
  add("bearer-token",  "secret", "[Bb]earer [A-Za-z0-9._~+/=-]{20,}", 0)
  add("connection-string", "secret", "(password|pwd)=[^; \t\"']{4,}", 1)
  add("email",         "pii",    "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z][A-Za-z]+", 0)
  # key = value assignments for credential-looking keys (value kept out of any output)
  assign = "(password|passwd|secret|token|api[_-]?key|apikey|client[_-]?secret|access[_-]?key|private[_-]?key)[\"']?[ \t]*[:=][ \t]*[\"']?[^ \t\"',;]{8,}"
}

{
  line = $0
  low = tolower(line)

  # Assignments first, so the value is removed whole and the key stays readable.
  out = ""
  rest = line; lrest = low
  while (match(lrest, assign)) {
    pre = substr(rest, 1, RSTART - 1)
    m = substr(rest, RSTART, RLENGTH)
    lm = substr(lrest, RSTART, RLENGTH)
    tmp = lm
    sub(/^[^:=]*[:=][ \t]*["']?/, "", tmp)
    prefixlen = length(lm) - length(tmp)
    if (tmp ~ /^\[redacted:/) {                 # already redacted: not a secret any more
      out = out pre m
      rest = substr(rest, RSTART + RLENGTH)
      lrest = substr(lrest, RSTART + RLENGTH)
      continue
    }
    if (mode == "scan") {
      printf "%s:%d: secret-like: credential assignment\n", name, NR
      nsecret++
    }
    out = out pre substr(m, 1, prefixlen) "[REDACTED:credential]"
    rest = substr(rest, RSTART + RLENGTH)
    lrest = substr(lrest, RSTART + RLENGTH)
  }
  line = out rest

  for (i = 1; i <= n; i++) {
    if (mode == "scan") {
      probe = (C[i] ? tolower(line) : line)
      if (probe ~ R[i]) {
        if (S[i] == "secret") { printf "%s:%d: secret-like: %s\n", name, NR, K[i]; nsecret++ }
        else { printf "%s:%d: pii: %s\n", name, NR, K[i]; npii++ }
      }
    } else {
      if (C[i]) {
        # case-insensitive: locate on a lowered copy, replace on the original
        o = ""; r2 = line; l2 = tolower(line)
        while (match(l2, R[i])) {
          o = o substr(r2, 1, RSTART - 1) "[REDACTED:" K[i] "]"
          r2 = substr(r2, RSTART + RLENGTH); l2 = substr(l2, RSTART + RLENGTH)
        }
        line = o r2
      } else {
        gsub(R[i], "[REDACTED:" K[i] "]", line)
      }
    }
  }
  if (mode == "redact") print line
}

# A scan fails (exit 3) only on secrets; personal data is a warning.
END {
  if (mode == "scan") exit (nsecret > 0 ? 3 : 0)
}
