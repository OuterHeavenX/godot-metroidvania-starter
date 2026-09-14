import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import varint

def gd(v):
    if v is None: return 'null'
    if v is True: return 'true'
    if v is False: return 'false'
    if isinstance(v, str): return '"%s"' % v
    if isinstance(v, float): return repr(v)
    return str(v)

def obj(o):
    body = ','.join('"%s":%s' % (k, gd(v)) for k, v in o.props)
    return 'Object(%s,%s)' % (o.cls, body)

SECTIONS = ['application', 'autoload', 'display', 'input', 'input_devices', 'rendering']

def build(project_binary):
    items = varint.load_project_binary(project_binary)
    buckets = {}
    for k, v in items:
        buckets.setdefault(k.split('/')[0], []).append((k, v))
    out = ['; Engine configuration file.', '; Recovered from the exported build.', '',
           'config_version=5', '']
    for sec in SECTIONS:
        if sec not in buckets: continue
        out.append('[%s]' % sec); out.append('')
        for k, v in buckets[sec]:
            sub = k.split('/', 1)[1]
            if sec == 'input':
                evs = ',\n'.join(obj(e) for e in v['events'])
                out.append('%s={\n"deadzone": %s,\n"events": [%s\n]\n}' % (sub, gd(v['deadzone']), evs))
            elif isinstance(v, list):
                out.append('%s=PackedStringArray(%s)' % (sub, ', '.join(gd(x) for x in v)))
            else:
                out.append('%s=%s' % (sub, gd(v)))
        out.append('')
    return '\n'.join(out)

if __name__ == '__main__':
    sys.stdout.write(build(sys.argv[1]))
