import pathlib,tarfile,shutil,os,sys,posixpath
out=pathlib.Path(sys.argv[1]); out.mkdir(); links=[]
for archive in sys.argv[2:]:
    with tarfile.open(archive,'r|gz') as tar:
        for m in tar:
            parts=pathlib.PurePosixPath(m.name).parts
            assert parts and not m.name.startswith('/') and '..' not in parts,m.name
            assert parts[0] in ('llvm','lld') and (len(parts)==1 or parts[1]=='23.1.6'),m.name
            if [m.name,m.linkname]==['llvm/23.1.6/etc/clang','../../../../etc/clang']:continue
            if len(parts)<=2:continue
            dest=out.joinpath(*parts[2:])
            if m.isdir():dest.mkdir(parents=True,exist_ok=True)
            elif m.isfile():
                dest.parent.mkdir(parents=True,exist_ok=True)
                with tar.extractfile(m) as src,dest.open('wb') as dst:shutil.copyfileobj(src,dst)
                dest.chmod(m.mode|0o200)
            elif m.issym() or m.islnk():
                resolved=posixpath.normpath(posixpath.join(posixpath.dirname(m.name),m.linkname) if m.issym() else m.linkname)
                assert not m.linkname.startswith('/') and resolved.startswith(parts[0]+'/23.1.6/'),(m.name,m.linkname)
                links.append((dest,m.linkname if m.issym() else str(out.joinpath(*pathlib.PurePosixPath(m.linkname).parts[2:])),m.islnk()))
            else:raise AssertionError(m.name)
for dest,target,hard in links:
    assert not dest.exists(),dest
    if hard:os.link(target,dest)
    else:dest.symlink_to(target)
