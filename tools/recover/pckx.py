import struct, os, sys
def extract(pck, out):
    d=open(pck,'rb').read()
    flags,=struct.unpack_from('<I',d,20)
    fbase,=struct.unpack_from('<q',d,24)
    diroff,=struct.unpack_from('<q',d,32)
    off=diroff; n,=struct.unpack_from('<I',d,off); off+=4
    got=[]
    for _ in range(n):
        ln,=struct.unpack_from('<I',d,off); off+=4
        path=d[off:off+ln].decode().rstrip('\0'); off+=ln
        o,s=struct.unpack_from('<qq',d,off); off+=16+16
        off+=4
        data=d[fbase+o:fbase+o+s] if flags&2 else d[o:o+s]
        p=os.path.join(out,path); os.makedirs(os.path.dirname(p),exist_ok=True)
        open(p,'wb').write(data); got.append(path)
    return got
if __name__=='__main__':
    for p in extract(sys.argv[1], sys.argv[2]): print(p)
