"""Minimal Godot 4 binary Variant decoder (the subset project.binary uses)."""
import struct

class Obj:
    def __init__(self, cls, props): self.cls, self.props = cls, props
    def __repr__(self): return f"Object({self.cls},{self.props})"

def _str(b, o):
    ln, = struct.unpack_from('<I', b, o); o += 4
    s = b[o:o + ln].split(b'\0')[0].decode('utf-8')
    return s, o + ln + ((4 - (ln % 4)) % 4)

def dec(b, o):
    h, = struct.unpack_from('<I', b, o); o += 4
    t = h & 0xFFFF; f64 = h & (1 << 16)
    if t == 0:  return None, o
    if t == 1:
        v, = struct.unpack_from('<I', b, o); return bool(v), o + 4
    if t == 2:
        if f64: v, = struct.unpack_from('<q', b, o); return v, o + 8
        v, = struct.unpack_from('<i', b, o); return v, o + 4
    if t == 3:
        if f64: v, = struct.unpack_from('<d', b, o); return v, o + 8
        v, = struct.unpack_from('<f', b, o); return v, o + 4
    if t in (4, 21, 22): return _str(b, o)
    if t == 24:
        cls, o = _str(b, o)
        n, = struct.unpack_from('<I', b, o); o += 4
        props = []
        for _ in range(n):
            k, o = _str(b, o)
            v, o = dec(b, o)
            props.append((k, v))
        return Obj(cls, props), o
    if t == 27:
        n, = struct.unpack_from('<I', b, o); o += 4; n &= 0x7FFFFFFF
        d = {}
        for _ in range(n):
            k, o = dec(b, o); v, o = dec(b, o); d[k] = v
        return d, o
    if t == 28:
        n, = struct.unpack_from('<I', b, o); o += 4; n &= 0x7FFFFFFF
        a = []
        for _ in range(n):
            v, o = dec(b, o); a.append(v)
        return a, o
    if t == 34:
        n, = struct.unpack_from('<I', b, o); o += 4
        a = []
        for _ in range(n):
            s, o = _str(b, o); a.append(s)
        return a, o
    raise ValueError(f'variant type {t} at {o-4}')

def load_project_binary(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'ECFG'
    n, = struct.unpack_from('<I', d, 4); o = 8
    out = []
    for _ in range(n):
        kl, = struct.unpack_from('<I', d, o); o += 4
        key = d[o:o + kl].rstrip(b'\0').decode(); o += kl
        vl, = struct.unpack_from('<I', d, o); o += 4
        val, _e = dec(d, o); o += vl
        out.append((key, val))
    return out
