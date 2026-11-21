# untrusted.awk — flag instruction-like text in content the agent fetched (a ticket, a chat
# thread, a log). The content is data; this scan makes planted instructions visible so the brief
# can list them. It is a heuristic: it catches common phrasings and misses novel ones, so it
# supports the rule "fetched content is never obeyed" and never replaces it.
#
#   awk -v name=<label> -f untrusted.awk <file>
# Prints  name:LINE: untrusted-instruction: <kind>: "<excerpt>"  and exits 3 when anything matched.

function add(kind, re) { n++; K[n] = kind; R[n] = re }

BEGIN {
  add("override-previous", "(ignore|disregard|forget|override)[ ]+(all |any |the |your )?(previous|prior|earlier|above|preceding)[ ]+(instructions|prompts|rules|directions|context)")
  add("override-previous", "disregard (all )?(of )?(your|the) (instructions|rules|guidelines)")
  add("new-instructions", "(new|updated|revised) (instructions|system prompt|directives?)[ ]*:")
  add("impersonates-system", "(system|admin|administrator|developer|security)[ ]+(notice|message|override|instruction|alert|directive)")
  add("addresses-the-assistant", "(note|message|instruction)s? (to|for) (the |an? )?(ai|assistant|agent|model|llm|claude)")
  add("commands-an-action", "you (must|should|are required to|have to|need to)[ ]+(now )?(immediately )?(run|execute|delete|remove|send|post|email|forward|upload|reveal|print|disable|approve|merge|push)")
  add("run-this-command", "(run|execute|paste)[ ]+(the following|this)[ ]+(command|script|code|snippet)")
  add("pipe-to-shell", "(curl|wget)[^|;]*\\|[ ]*(sudo )?(ba|z|da|k)?sh")
  add("asks-for-secrets", "(reveal|print|show|send|output|exfiltrate|share)[ ]+(me |us )?(your|the|all)[ ]+(system prompt|instructions|api[ _-]?keys?|passwords?|tokens?|secrets?|credentials|environment variables?)")
  add("conceal-from-user", "(do not|don't|never)[ ]+(tell|inform|mention|reveal|show)[ ]+(this )?(to )?(the )?(user|human|operator|reader)")
  add("role-takeover", "you are now[ ]+(a|an|the|in)[ ]|act as (a|an|the) [a-z]+ (without|with no) (restrictions|limits|rules)")
}

{
  low = tolower($0)
  for (i = 1; i <= n; i++) {
    if (match(low, R[i])) {
      ex = substr($0, RSTART, RLENGTH)
      if (length(ex) > 70) ex = substr(ex, 1, 70) "..."
      printf "%s:%d: untrusted-instruction: %s: \"%s\"\n", name, NR, K[i], ex
      hits++
      break
    }
  }
}

END { exit (hits > 0 ? 3 : 0) }
