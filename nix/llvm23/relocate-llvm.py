import pathlib,subprocess,json,sys
root=pathlib.Path(sys.argv[1]).resolve();z3=pathlib.Path(sys.argv[2]);zstd=pathlib.Path(sys.argv[3])
prefixes={'@@HOMEBREW_PREFIX@@/opt/llvm':str(root),'@@HOMEBREW_CELLAR@@/llvm/23.1.6':str(root),'@@HOMEBREW_PREFIX@@/opt/lld':str(root),'@@HOMEBREW_CELLAR@@/lld/23.1.6':str(root),'@@HOMEBREW_PREFIX@@/opt/z3':str(z3),'@@HOMEBREW_PREFIX@@/opt/zstd':str(zstd),'/opt/homebrew/Cellar/llvm/23.1.6':str(root),'/opt/homebrew/opt/llvm':str(root)}
record=[];unknown=[]
for p in sorted(root.rglob('*')):
 if not p.is_file() or p.is_symlink():continue
 with p.open('rb') as f:magic=f.read(4)
 if magic not in (b'\xcf\xfa\xed\xfe',b'\xca\xfe\xba\xbe',b'\xfe\xed\xfa\xcf'):continue
 deps=subprocess.check_output(['otool','-L',str(p)],text=True).splitlines()[1:]
 changes=[]
 for line in deps:
  if ' (compatibility version ' not in line:continue
  old=line.strip().split(' (compatibility')[0];new=old
  for a,b in prefixes.items():
   if old.startswith(a+'/'):new=b+old[len(a):];break
  if old.startswith('@rpath/'):
   candidate=root/'lib'/old.removeprefix('@rpath/')
   if not candidate.exists():candidate=p.parent/old.removeprefix('@rpath/')
   if not candidate.exists():candidate=root/'lib/unwind'/old.removeprefix('@rpath/')
   if candidate.exists():new=str(candidate)
  if new!=old:changes.extend(['-change',old,new])
  elif not old.startswith(('/usr/lib/','/System/Library/','@loader_path/',str(root),'/nix/store/')):unknown.append([str(p),old])
 if p.suffix=='.dylib':changes.extend(['-id',str(p)])
 load=subprocess.check_output(['otool','-l',str(p)],text=True).splitlines()
 for i,line in enumerate(load):
  if line.strip()=='cmd LC_RPATH':
   old=load[i+2].strip().split(' (offset')[0].removeprefix('path ')
   if 'HOMEBREW' in old or old.startswith('/opt/homebrew'):changes.extend(['-rpath',old,str(root/'lib')])
 if changes:
  subprocess.run(['install_name_tool',*changes,str(p)],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  subprocess.run(['codesign','-f','-s','-',str(p)],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 record.append(str(p.relative_to(root)))
assert not unknown,unknown
text_changes=0
for p in sorted(root.rglob('*')):
 if not p.is_file() or p.is_symlink() or p.stat().st_size>16*1024**2:continue
 b=p.read_bytes()
 if b'\0' in b or b'HOMEBREW' not in b and b'/opt/homebrew' not in b:continue
 try:s=b.decode('utf8')
 except UnicodeDecodeError:continue
 new=s
 for a,v in prefixes.items():new=new.replace(a,v)
 if new!=s:p.write_text(new);text_changes+=1
(root/'share/llvm23-relocation.json').write_text(json.dumps({'mach_o_files':record,'text_files':text_changes,'root':str(root)},indent=2)+'\n')
print('Relocated and signed',len(record),'Mach-O files;',text_changes,'text files')
