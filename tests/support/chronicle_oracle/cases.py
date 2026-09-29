import sys
def enc(n):
    if n == 0: return b""
    neg = n < 0; m = -n if neg else n
    out = bytearray()
    while m: out.append(m & 0xff); m >>= 8
    if out[-1] & 0x80: out.append(0x80 if neg else 0)
    elif neg: out[-1] |= 0x80
    return bytes(out)
def push(b):
    if len(b) == 0: return b"\x00"
    if len(b) <= 75: return bytes([len(b)]) + b
    if len(b) <= 255: return b"\x4c" + bytes([len(b)]) + b
    if len(b) <= 65535: return b"\x4d" + len(b).to_bytes(2,"little") + b
    return b"\x4e" + len(b).to_bytes(4,"little") + b
def pn(n): return push(enc(n))
OP = dict(MUL2=0x8d, DIV2=0x8e, VER=0x62, VERIF=0x65, VERNOTIF=0x66, ELSE=0x67, ENDIF=0x68, IF=0x63,
          SUBSTR=0xb3, LEFT=0xb4, RIGHT=0xb5, LSHIFTNUM=0xb6, RSHIFTNUM=0xb7, ONE=0x51, ZERO=0x00, DROP=0x75)
def o(*names): return bytes(OP[n] for n in names)
cases = []
def add(name, chron, ver, script): cases.append((name, chron, ver, script))
vals = [0, 1, -1, 2, -2, 3, -3, 5, -5, 63, 64, -64, 127, 128, -128, 255, 32767, 2**31-1, 2**31, -(2**31),
        2**62, 2**63-1, -(2**63-1), 2**63, -(2**63), 2**63+1, 2**64+1, -(2**64+1), 2**127, 2**200+1, -(2**200+1), 2**255-19]
for i, v in enumerate(vals):
    add(f"2mul_{i}", 1, 1, pn(v) + o("MUL2"))
    add(f"2div_{i}", 1, 1, pn(v) + o("DIV2"))
for i, (v, s) in enumerate([(1,8),(-1,1),(5,0),(0,300),(1,64),(-3,100),(2**64,1),(12345,17)]):
    add(f"lsh_{i}", 1, 1, pn(v) + pn(s) + o("LSHIFTNUM"))
for i, (v, s) in enumerate([(16,2),(-5,1),(-1,1),(-1,200),(5,0),(1,1),(-16,2),(-17,2),(2**100+5,99),(-(2**100+5),99),(7,300),(-7,300)]):
    add(f"rsh_{i}", 1, 1, pn(v) + pn(s) + o("RSHIFTNUM"))
add("lsh_neg", 1, 1, pn(1) + pn(-1) + o("LSHIFTNUM"))
add("rsh_neg", 1, 1, pn(1) + pn(-1) + o("RSHIFTNUM"))
data = push(b"abcdef")
for i, (b, l) in enumerate([(0,6),(1,3),(5,1),(0,0),(6,0),(2,5),(-1,1),(1,-1),(7,0)]):
    add(f"substr_{i}", 1, 1, data + pn(b) + pn(l) + o("SUBSTR"))
add("substr_empty", 1, 1, push(b"") + pn(0) + pn(0) + o("SUBSTR"))
for i, l in enumerate([0, 2, 6, 7, -1]):
    add(f"left_{i}", 1, 1, data + pn(l) + o("LEFT"))
    add(f"right_{i}", 1, 1, data + pn(l) + o("RIGHT"))
add("ver_v1", 1, 1, o("VER"))
add("ver_v2", 1, 2, o("VER"))
add("ver_big", 1, 0xfffffffe, o("VER"))
add("verif_match", 1, 2, push(bytes([2,0,0,0])) + o("VERIF", "ONE", "ELSE", "ZERO", "ENDIF"))
add("verif_short", 1, 2, push(bytes([2])) + o("VERIF", "ONE", "ELSE", "ZERO", "ENDIF"))
add("verif_other", 1, 2, push(bytes([1,0,0,0])) + o("VERIF", "ONE", "ELSE", "ZERO", "ENDIF"))
add("vernotif_match", 1, 2, push(bytes([2,0,0,0])) + o("VERNOTIF", "ONE", "ELSE", "ZERO", "ENDIF"))
add("vernotif_other", 1, 2, push(bytes([1,0,0,0])) + o("VERNOTIF", "ONE", "ELSE", "ZERO", "ENDIF"))
add("verif_empty", 1, 2, o("VERIF", "ENDIF", "ONE"))
add("verif_untaken", 1, 2, o("ZERO", "IF", "VERIF", "ENDIF", "ENDIF", "ONE"))
add("verif_untaken_unbalanced", 1, 2, o("ZERO", "IF", "VERIF", "ENDIF", "ONE"))
# pre-Chronicle (post-Genesis)
add("pre_2mul", 0, 1, pn(1) + o("MUL2"))
add("pre_2div", 0, 1, pn(2) + o("DIV2"))
add("pre_2mul_untaken", 0, 1, o("ZERO", "IF", "MUL2", "ENDIF", "ONE"))
add("pre_ver", 0, 2, o("VER"))
add("pre_verif", 0, 2, push(bytes([2,0,0,0])) + o("VERIF", "ONE", "ENDIF"))
add("pre_verif_untaken", 0, 2, o("ZERO", "IF", "VERIF", "ENDIF", "ONE"))
add("pre_substr", 0, 1, data + pn(1) + pn(3) + o("SUBSTR"))
add("pre_rsh", 0, 1, pn(16) + pn(2) + o("RSHIFTNUM"))
add("pre_lsh", 0, 1, pn(1) + pn(8) + o("LSHIFTNUM"))
add("pre_left", 0, 1, data + pn(2) + o("LEFT"))
add("pre_right", 0, 1, data + pn(2) + o("RIGHT"))
mode = sys.argv[1] if len(sys.argv) > 1 else "oracle"
for name, chron, ver, script in cases:
    print(name, chron, ver, script.hex())
