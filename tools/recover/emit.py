"""Rebuild readable GDScript from a decoded .gdc token stream."""
import sys, math
import gdc

KEYWORDS = {'and','or','not','if','elif','else','for','while','break','continue','pass','return',
            'match','when','as','assert','await','breakpoint','class','class_name','const','enum',
            'extends','func','in','is','namespace','preload','self','signal','static','super',
            'trait','var','void','yield'}
NO_SPACE_BEFORE = {',', ')', ']', '}', ':', ';', '.', '..', '...'}
# '(' and '[' bind tight only after something callable/subscriptable
CALLABLE_PREV = {'Identifier', 'Literal', 'Annotation', ')', ']', '}', 'self', 'super', 'preload'}
NO_SPACE_AFTER  = {'(', '[', '$', '.', '..', '...', '~', '{'}
UNARY_CTX = {'(','[','{',',','=','+=','-=','*=','/=','%=','**=','<<=','>>=','&=','|=','^=',
             'return',':','->','<','<=','>','>=','==','!=','and','or','not','+','-','*','/','%',
             '**','in','if','elif','while','when','&&','||','!','START'}


def fmt_literal(v):
    if v is None: return 'null'
    if v is True: return 'true'
    if v is False: return 'false'
    if isinstance(v, float):
        if math.isinf(v): return 'INF' if v > 0 else '-INF'
        if math.isnan(v): return 'NAN'
        r = repr(v)
        return r if ('.' in r or 'e' in r) else r + '.0'
    if isinstance(v, str):
        sig = getattr(v, 'sigil', '')
        return sig + '"' + v.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\t', '\\t') + '"'
    return repr(v)


def piece_of(name, val):
    if name in ('Identifier', 'Annotation'): return val
    if name == 'Literal': return fmt_literal(val)
    if name == 'NaN': return 'NAN'
    return name


def render(res):
    tokens = res['tokens']
    cols = res['cols']
    # indent (in tabs) for the line each line-starting token opens
    line_indent = {}
    for ti, col in cols.items():
        if ti < len(tokens):
            line_indent[tokens[ti][2]] = max(0, col - 1)
    by_line = {}
    for name, val, line, _c in tokens:
        if name in ('Newline', 'Indent', 'Dedent', 'Empty', 'End of file'):
            continue
        by_line.setdefault(line, []).append((name, piece_of(name, val)))

    # The column table records statement starts only, so any line missing from
    # it is a backslash continuation of the statement above it.
    last_start = 0
    out, last = [], 0
    for ln in sorted(by_line):
        cont = out and ln not in line_indent
        if not cont and last:
            out.extend([''] * min(max(0, ln - last - 1), 2))
        last = ln
        toks = by_line[ln]
        s, prev = '', 'START'
        i = 0
        while i < len(toks):
            name, piece = toks[i]
            if name == ':' and i + 1 < len(toks) and toks[i + 1][0] == '=':
                s = s.rstrip() + ' := '
                prev = 'SPACED'; i += 2; continue
            if name in ('-', '+', '!') and prev in UNARY_CTX:
                if s and prev not in NO_SPACE_AFTER and prev != 'START':
                    s += ' '
                s += piece
                prev = 'UNARY'; i += 1; continue
            if s:
                need = True
                if name in NO_SPACE_BEFORE: need = False
                if prev in NO_SPACE_AFTER or prev in ('UNARY', 'SPACED'): need = False
                if name in ('(', '['): need = prev not in CALLABLE_PREV
                if need: s += ' '
            s += piece
            prev = name
            i += 1
        if cont:
            out[-1] = out[-1] + ' \\'
            out.append('\t' * (line_indent.get(last_start, 0) + 2) + s.rstrip())
        else:
            last_start = ln
            out.append('\t' * line_indent.get(ln, 0) + s.rstrip())
    return '\n'.join(out).rstrip() + '\n'


if __name__ == '__main__':
    sys.stdout.write(render(gdc.load(sys.argv[1])))
