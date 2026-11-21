#!/usr/bin/env python3
# SwiftRust modifications © 2026 SwiftRust contributors.
# SPDX-License-Identifier: AGPL-3.0-only
"""Build generic, importable native-action templates on macOS using Apple's signer.
Apple receives these placeholder-only workflows for validation. No device IDs,
credentials or signing-team settings are included. Requires macOS Shortcuts.
"""
import argparse
import itertools
import plistlib
import subprocess
import tempfile
import uuid
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, default=Path(__file__).resolve().parents[2] / 'flutter/ios/Runner/ShortcutTemplates')
args = parser.parse_args()
args.output_dir.mkdir(parents=True, exist_ok=True)
for mode, relay, window in itertools.product(('desktop', 'terminal', 'files', 'camera'), (False, True), (False, True)):
    variant = f'{mode}-r{int(relay)}w{int(window)}'
    workflow = {
        'WFWorkflowActions': [{
            'WFWorkflowActionIdentifier': 'swiftrust.airefactor.me.NativeConnectDeviceIntent',
            'WFWorkflowActionParameters': {
                'AppIntentDescriptor': {'BundleIdentifier': 'swiftrust.airefactor.me', 'Name': 'SwiftRust', 'AppIntentIdentifier': 'NativeConnectDeviceIntent'},
                'UUID': str(uuid.uuid5(uuid.NAMESPACE_URL, 'swiftrust://template/' + variant)).upper(),
                'id': '', 'mode': mode, 'newWindow': window, 'relay': relay,
            },
        }],
        'WFWorkflowClientVersion': '4018.0.4',
        'WFWorkflowMinimumClientVersion': 900, 'WFWorkflowMinimumClientVersionString': '900',
        'WFWorkflowIcon': {'WFWorkflowIconStartColor': 4271458815, 'WFWorkflowIconGlyphNumber': 61440},
        'WFWorkflowTypes': [], 'WFQuickActionSurfaces': [],
        'WFWorkflowInputContentItemClasses': [], 'WFWorkflowOutputContentItemClasses': [],
        'WFWorkflowHasShortcutInputVariables': False, 'WFWorkflowHasOutputFallback': False,
        'WFWorkflowImportQuestions': [{'ActionIndex': 0, 'ParameterKey': 'id', 'Category': 'Parameter',
            'Text': '远程 ID 或 IP 地址（可粘贴 SwiftRust 复制的设备 ID）', 'DefaultValue': ''}],
    }
    with tempfile.TemporaryDirectory(prefix='swiftrust-shortcut-') as temp:
        source = Path(temp) / 'unsigned.shortcut'
        source.write_bytes(plistlib.dumps(workflow, fmt=plistlib.FMT_BINARY))
        subprocess.run(['/usr/bin/shortcuts', 'sign', '--mode', 'anyone', '--input', str(source),
                        '--output', str(args.output_dir / f'SwiftRust-{variant}.shortcut')], check=True)
    print(f'Signed native {variant} template')
