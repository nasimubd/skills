# normalize.awk — reduce a shell command to what would actually run.
#
# Reads the command on stdin and prints one line:
#   * the contents of quoted strings are removed, so a commit message or an echo
#     that merely quotes a destructive command does not trigger a rule;
#   * a quoted string with no whitespace is kept (rm -rf "$HOME" must still match);
#   * $(...) and backticks inside double quotes are kept, because they run;
#   * heredoc bodies are removed (they are data unless the tag is unquoted, which
#     is not worth the false positives);
#   * newlines become " ; ", so a multi-line script is several commands.
#
# POSIX awk only (macOS awk is the one-true-awk): no gensub, no length(array).
# Quote state carries across lines, as it does in the shell.

function is_heredoc(line, i) {
  return (substr(line, i, 2) == "<<" && substr(line, i, 3) != "<<<" \
          && (i == 1 || substr(line, i - 1, 1) != "<"))
}

function note_tag(line, i,    rest) {
  rest = substr(line, i + 2)
  sub(/^-/, "", rest)
  sub(/^[ \t]*/, "", rest)
  if (match(rest, "^[" dq q "\\\\]?[A-Za-z_][A-Za-z0-9_]*[" dq q "]?")) {
    pending_tag = substr(rest, RSTART, RLENGTH)
    gsub("[" dq q "\\\\]", "", pending_tag)
    pending = 1
  }
}

function close_quote(    code) {
  # A string handed to `sh -c` or `eval` is code, so it is kept whole. Any other string
  # with whitespace is data; one without whitespace survives (rm -rf "$HOME").
  code = (out ~ "(^|[^[:alnum:]_.-])(ba|z|da|k)?sh[ \t]+(-[A-Za-z]+[ \t]+)*-[A-Za-z]*c[ \t]*$" \
          || out ~ "(^|[^[:alnum:]_.-])eval[ \t]*$")
  if (!hadsub && qbuf != "" && (code || qbuf !~ /[ \t]/)) out = out qbuf
  qbuf = ""
  hadsub = 0
}

BEGIN { st = 0; out = ""; hd = 0; pending = 0; qbuf = ""; hadsub = 0; depth = 0; first = 1 }

{
  line = $0
  if (hd) {
    t = line
    sub(/^[ \t]+/, "", t)
    if (line == tag || t == tag) hd = 0
    next
  }
  if (!first) out = out " ; "
  first = 0
  n = length(line)
  for (i = 1; i <= n; i++) {
    c = substr(line, i, 1)
    if (st == 0) {
      if (c == "\\") { out = out c substr(line, i + 1, 1); i++ }
      else if (c == q) { st = 1; qbuf = ""; hadsub = 0 }
      else if (c == dq) { st = 2; qbuf = ""; hadsub = 0 }
      else if (is_heredoc(line, i)) { note_tag(line, i); out = out c }
      else out = out c
    } else if (st == 1) {
      if (c == q) { st = 0; close_quote() } else qbuf = qbuf c
    } else if (st == 2) {
      if (c == "\\") { qbuf = qbuf substr(line, i + 1, 1); i++ }
      else if (c == dq) { st = 0; close_quote() }
      else if (c == "$" && substr(line, i, 2) == "$(") { st = 3; depth = 1; hadsub = 1; out = out "$("; i++ }
      else if (c == bt) { st = 4; hadsub = 1; out = out bt }
      else qbuf = qbuf c
    } else if (st == 3) {
      if (is_heredoc(line, i)) note_tag(line, i)
      out = out c
      if (c == "(") depth++
      else if (c == ")") { depth--; if (depth == 0) st = 2 }
    } else if (st == 4) {
      out = out c
      if (c == bt) st = 2
    }
  }
  if (pending) { hd = 1; tag = pending_tag; pending = 0 }
}

END { print out }
