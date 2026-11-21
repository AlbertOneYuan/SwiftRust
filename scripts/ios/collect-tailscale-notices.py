#!/usr/bin/env python3
"""Collect fixed Go module notices for the embedded iOS Tailscale archive.
Run with the pinned libtailscale source directory after go mod download.
"""
from pathlib import Path
import os,subprocess,json
root=Path(__file__).resolve().parents[2]; source=Path(__import__('sys').argv[1]).resolve()
env=os.environ.copy();env.update(GOOS='ios',GOARCH='arm64',CGO_ENABLED='1',CC=str(source/'swift/script/clangwrap-ios.sh'))
raw=subprocess.check_output(['go','list','-deps','-f','{{with .Module}}{{.Path}}|{{.Version}}|{{.Dir}}{{end}}','.'],cwd=source,env=env,text=True)
modules=sorted(set(x for x in raw.splitlines() if x))
parts=['Embedded Tailscale / libtailscale notices','libtailscale revision dacde75057ff350e146505829beff446e6823966; tailscale.com v1.104.1','SwiftRust adapter is AGPL-3.0; upstream modules retain their licenses.',''];rows=[]
for item in modules:
 name,version,folder=item.split('|',2);directory=Path(folder);paths=set()
 for pattern in ['LICENSE*','LICENCE*','COPYING*','NOTICE*','COPYRIGHT*','AUTHORS*']:
  paths.update(p for p in directory.glob(pattern) if p.is_file())
 parts+=['='*72,name+' '+version,'']
 if not paths:parts+=['No root license text found. Inspect upstream package before distribution.','']
 for p in sorted(paths):parts+=[p.name,p.read_text(errors='replace'),'']
 rows.append({'module':name,'version':version,'license_files':[p.name for p in sorted(paths)]})
goroot=Path(subprocess.check_output(['go','env','GOROOT'],text=True).strip());parts+=['='*72,'Go standard library/runtime',((goroot/'LICENSE') if (goroot/'LICENSE').exists() else (goroot.parent/'LICENSE')).read_text()]
(root/'flutter/ios/Runner/TailscaleNotices.txt').write_text('\n'.join(parts))
(root/'docs/swiftrust/TAILSCALE_DEPENDENCIES.json').write_text(json.dumps(rows,indent=2)+'\n')
print('Collected notices for',len(rows),'Go modules; missing:',[r['module'] for r in rows if not r['license_files']])
