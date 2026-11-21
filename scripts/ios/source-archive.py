#!/usr/bin/env python3
"""Archive Git-visible source plus initialized submodules, without Git metadata/build secrets.
Not a replacement for checking all Corresponding Source/dependency requirements.
"""
from pathlib import Path
import subprocess, tarfile, sys
root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / '.build-swiftrust/SwiftRust-source.tar.gz'
out.parent.mkdir(parents=True, exist_ok=True)
files = set()
def collect(folder, prefix=Path()):
    names = subprocess.check_output(['git', '-C', str(folder), 'ls-files', '--cached', '--others', '--exclude-standard', '-z']).decode().split('\0')
    for name in names:
        if not name: continue
        path = folder / name
        if path.is_file() or path.is_symlink(): files.add(prefix / name)
        elif path.is_dir() and (path / '.git').exists(): collect(path, prefix / name)
collect(root)
for path in files:
    if path.suffix.lower() in {'.p12', '.pfx', '.mobileprovision', '.ipa'} or path.name == '.env':
        raise SystemExit('Refusing credential/build artifact: ' + str(path))
with tarfile.open(out, 'w:gz') as archive:
    for path in sorted(files): archive.add(root / path, arcname=str(Path('SwiftRust') / path), recursive=False)
print(f'{out}: {len(files)} source files (includes initialized submodules). Review dependencies before distribution.')
