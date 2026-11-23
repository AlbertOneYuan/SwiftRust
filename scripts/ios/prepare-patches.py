#!/usr/bin/env python3
"""Apply iOS compatibility patches to locked Cargo dependencies.
Changes the local Cargo source cache; no private keys or code generation involved.
Run before building; if the cache was already compiled, cargo clean -p NAME first.
"""
from pathlib import Path
import os, subprocess
root = Path(__file__).resolve().parents[2]
registry = Path(os.environ.get('CARGO_HOME', Path.home() / '.cargo')) / 'registry/src'
for crate, file, patch, marker in [
    ('libsodium-sys-0.2.7', 'build.rs', 'libsodium-ios-simulator.patch', '"aarch64-apple-ios-sim" =>'),
    ('system-configuration-0.5.1', 'src/network_configuration.rs', 'system-configuration-ios.patch', '#[cfg(target_os = "ios")]'),
    ('system-configuration-0.5.1', 'src/network_configuration.rs', 'system-configuration-ios-bridge.patch', '{ id_is_equal_to(kSCNetworkInterfaceTypeBridge) }'),
]:
    candidates = list(registry.glob('*/' + crate + '/' + file))
    if not candidates: raise SystemExit(f'{crate} not fetched; run cargo fetch --locked')
    for source in candidates:
        if marker not in source.read_text():
            subprocess.run(['patch', str(source), str(root / 'scripts/ios/patches' / patch)], check=True)
            print('Patched', crate)
