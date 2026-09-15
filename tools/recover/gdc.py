"""Decode Godot 4.7 exported GDScript (.gdc) binary token buffers back to source.

Layout, verified against a script compiled by Godot 4.7.2 itself:
  "GDSC" | version u32 | decompressed_size u32 | zstd payload
  payload: ident_count, const_count, line_count, token_count (u32 each)
           identifiers  (u32 len, then len u32 chars each XOR 0xb6b6b6b6)
           constants    (standard Variant encoding)
           (token_index, line)   pairs  x line_count
           (token_index, column) pairs  x line_count
           tokens: u32 (type = low 7 bits, operand index = >> 8), u32 line
"""
import struct, zstandard


class Tagged(str):
    """A string literal that carries its GDScript sigil (&"x" StringName, ^"x" NodePath)."""
    sigil = ''

    def __new__(cls, value, sigil):
        o = str.__new__(cls, value); o.sigil = sigil; return o

TOKENS = ['Empty','Annotation','Identifier','Literal','<','<=','>','>=','==','!=','and','or','not',
'&&','||','!','&','|','~','^','<<','>>','+','-','*','**','/','%','=','+=','-=','*=','**=','/=','%=',
'<<=','>>=','&=','|=','^=','if','elif','else','for','while','break','continue','pass','return','match',
'when','as','assert','await','breakpoint','class','class_name','const','enum','extends','func','in','is',
'namespace','preload','self','signal','static','super','trait','var','void','yield','[',']','{','}','(',
')',',',';','.','..','...',':','$','->','_','Newline','Indent','Dedent','PI','TAU','INF','NaN',
'VCS conflict marker','`','?','Error','End of file']


def dec_variant(b, o):
    h, = struct.unpack_from('<I', b, o); o += 4
    t = h & 0xFFFF
    f64 = h & (1 << 16)
    if t == 0: return None, o
    if t == 1:
        v, = struct.unpack_from('<I', b, o); return bool(v), o + 4
    if t == 2:
        if f64:
            v, = struct.unpack_from('<q', b, o); return v, o + 8
        v, = struct.unpack_from('<i', b, o); return v, o + 4
    if t == 3:
        if f64:
            v, = struct.unpack_from('<d', b, o); return v, o + 8
        v, = struct.unpack_from('<f', b, o); return v, o + 4
    if t in (4, 21, 22):                       # String, StringName, NodePath
        ln, = struct.unpack_from('<I', b, o); o += 4
        s = b[o:o + ln].decode('utf-8')
        o += ln + ((4 - (ln % 4)) % 4)
        sig = {4: '', 21: '&', 22: '^'}[t]
        return (Tagged(s, sig) if sig else s), o
    if t == 5:                                 # Vector2
        x, y = struct.unpack_from('<ff', b, o); return ('Vector2(%g, %g)' % (x, y)), o + 8
    if t == 20:                                # Color
        r, g, bl, a = struct.unpack_from('<ffff', b, o)
        return ('Color(%g, %g, %g, %g)' % (r, g, bl, a)), o + 16
    raise ValueError('unsupported variant type %d at %d' % (t, o - 4))


def load(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'GDSC', 'not a .gdc file'
    dsize, = struct.unpack_from('<I', d, 8)
    raw = (zstandard.ZstdDecompressor().decompress(d[12:], max_output_size=max(dsize * 4, 1 << 20))
           if dsize else d[12:])
    u = lambda o: struct.unpack_from('<I', raw, o)[0]
    ic, cc, lc, tc = u(0), u(4), u(8), u(12)
    o = 16
    ids = []
    for _ in range(ic):
        ln = u(o); o += 4
        ids.append(''.join(chr(u(o + 4 * j) ^ 0xb6b6b6b6) for j in range(ln)))
        o += 4 * ln
    consts = []
    for _ in range(cc):
        v, o = dec_variant(raw, o); consts.append(v)
    tok_lines = {}
    for _ in range(lc):
        tok_lines[u(o)] = u(o + 4); o += 8
    tok_cols = {}
    for _ in range(lc):
        tok_cols[u(o)] = u(o + 4); o += 8
    toks = []
    for ti in range(tc):
        a = u(o); line = u(o + 4); o += 8
        t = a & 0x7F
        name = TOKENS[t] if t < len(TOKENS) else '?%d' % t
        val = None
        if name in ('Annotation', 'Identifier'):
            val = ids[a >> 8]
        elif name in ('Literal', 'Error'):
            val = consts[a >> 8]
        toks.append((name, val, line, tok_cols.get(ti)))
    return dict(ids=ids, consts=consts, tokens=toks, end=o, size=len(raw),
                counts=(ic, cc, lc, tc), lines=tok_lines, cols=tok_cols)
