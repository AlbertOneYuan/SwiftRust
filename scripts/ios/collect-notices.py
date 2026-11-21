#!/usr/bin/env python3
"""Collect available license texts for the locked iOS Rust dependency graph.
Usage: collect-notices.py METADATA.json [VCPKG_INSTALLED_SHARE]
Generate metadata using cargo metadata --locked --features flutter --format-version 1 --filter-platform aarch64-apple-ios.
No absolute manifest/cache paths are written to the output.
"""
import hashlib, json, sys
from pathlib import Path
root = Path(__file__).resolve().parents[2]
metadata = json.loads(Path(sys.argv[1]).read_text())
lines = ['Third-Party Software Notices',
         'Includes components resolved for the iOS build and its build tools.',
         'Original copyright, permission and warranty notices follow.', '']
audit_path = root / 'docs/swiftrust/LICENSE_AUDIT.json'
audit = json.loads(audit_path.read_text()) if audit_path.exists() else {'entries': []}
reviews = {(r['name'], r['version']): r for r in audit['entries']}
rows = []; missing = []
for package in sorted(metadata['packages'], key=lambda x: (x['name'], x['version'])):
    folder = Path(package['manifest_path']).parent
    paths = set()
    if package.get('license_file'): paths.add(folder / package['license_file'])
    for pattern in ('LICENSE*', 'LICENCE*', 'COPYING*', 'NOTICE*', 'license*'):
        paths.update(p for p in folder.glob(pattern) if p.is_file())
    # REUSE-style projects keep license texts in a directory rather than root files.
    paths.update(p for p in (folder / 'LICENSES').glob('*') if p.is_file())
    texts = []
    for path in sorted(paths):
        try: texts.append((path.name, path.read_text(encoding='utf-8')))
        except (UnicodeError, OSError): pass
    review = reviews.get((package['name'], package['version']))
    if review:
        if review['package_source'] != package.get('source') or review['declared_license'] != package.get('license'):
            raise SystemExit('License review is stale: ' + package['name'])
        checksum = folder / '.cargo-checksum.json'
        if review.get('package_checksum') and (not checksum.exists() or json.loads(checksum.read_text()).get('package') != review['package_checksum']):
            raise SystemExit('Package checksum changed: ' + package['name'])
        for evidence in review['evidence']:
            path = root / evidence['file']
            if hashlib.sha256(path.read_bytes()).hexdigest() != evidence['sha256']:
                raise SystemExit('License evidence checksum mismatch: ' + evidence['file'])
            if evidence.get('kind') != 'manifest':
                texts.append((evidence['file'] + '\nOriginal source: ' + evidence['url'], path.read_text(encoding='utf-8')))
    name = package['name'] + ' ' + package['version']
    lines += ['=' * 72, name, 'License: ' + (package.get('license') or 'See upstream license files'),
              'Source: ' + (package.get('source') or package.get('repository') or 'Included in this project'), '']
    if review:
        lines += ['Review: ' + review['status'], '']
    if not texts:
        lines += ['No root license text found; consult the source package before distribution.', '']; missing.append(name)
    for filename, text in texts: lines += [filename, text, '']
    rows.append({'name': package['name'], 'version': package['version'], 'license': package.get('license'),
                 'source': package.get('source'), 'repository': package.get('repository'), 'license_files': [n.split('\n', 1)[0] for n, _ in texts], 'license_review_status': review['status'] if review else 'packaged-license-text'})
if len(sys.argv) > 2:
    share = Path(sys.argv[2])
    for path in sorted(share.glob('*/copyright')):
        lines += ['=' * 72, 'Native codec package: ' + path.parent.name, path.read_text(), '']
lines += ['=' * 72, 'SwiftTerm 1.18.0 — MIT', (root / 'flutter/ios/Runner/SwiftTermLicense.txt').read_text()]
(root / 'flutter/ios/Runner/ThirdPartyNotices.txt').write_text('\n'.join(lines))
(root / 'docs/swiftrust/DEPENDENCIES.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
pending = [r for r in audit['entries'] if r['status'] == 'pending']
summary = ['License evidence review — 2026-11-20',
           f"Original 46 entries: {len(audit['entries']) - len(pending)} supplemented/reconciled; {len(pending)} pending upstream notice or authorization clarification.",
           'This is not a complete license compatibility or final binary compliance certification.',
           'See LICENSE_AUDIT.md / LICENSE_AUDIT.json for all 46 decisions, sources and hashes.', '']
for item in pending:
    summary += [item['name'] + ' ' + item['version'], item['notes'], '']
if missing:
    summary += ['Current entries without a usable full license text:', *missing]
(root / 'docs/swiftrust/LICENSE_REVIEW.txt').write_text('\n'.join(summary) + '\n')
print(f'Collected {len(rows)} package entries; {len(missing)} entries need license-file review.')
