import re, sys
cases = [l.split() for l in open("cases.txt")]
orc = {}
for l in open("oracle.txt"):
    m = re.match(r"(\S+) stack=\[(.*?)\] err=(.*)$", l.strip())
    orc[m.group(1)] = (m.group(2), m.group(3))
def errmap(e):
    if "negative shift amount" in e: return "NegativeShift"
    if "invalid range" in e or "invalid length" in e: return "NumberTooBig"
    if "empty stack for OP_VERIF" in e: return "UnbalancedConditionals"
    if "end of script reached in conditional" in e: return "UnbalancedConditionals"
    if "disabled opcode" in e or "reserved opcode" in e: return "UnknownOpcode"
    raise SystemExit("unmapped: " + e)
out = []
for name, chron, ver, script in cases:
    stack, err = orc[name]
    items = [] if stack == "" else ["" if s == "''" else s for s in stack.split(",")]
    if err == "ok": outcome = ".success"
    elif err.startswith("false stack entry"): outcome = ".false_result"
    else: outcome = f".{{ .script_error = error.{errmap(err)} }}"
    st = ", ".join(f'"{s}"' for s in items)
    if outcome.startswith(".{"): st = ""  # go-sdk's stack on error is its pre-op snapshot; only the error is compared
    out.append(f'    .{{ .name = "{name}", .chronicle = {"true" if chron=="1" else "false"}, .version = 0x{int(ver):08x}, .script = "{script}", .outcome = {outcome}, .stack = &.{{{st}}} }},')
print("\n".join(out))
