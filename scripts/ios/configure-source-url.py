#!/usr/bin/env python3
"""Set the HTTPS URL of the complete source corresponding to the released app."""
from pathlib import Path
import plistlib, sys
from urllib.parse import urlparse
if len(sys.argv) != 2: raise SystemExit('Usage: configure-source-url.py https://host/path/to/version-matched-source')
url = sys.argv[1]
parsed = urlparse(url)
if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
    raise SystemExit('A real HTTPS URL without embedded credentials is required')
p = Path(__file__).resolve().parents[2] / 'flutter/ios/Runner/Info.plist'
data = plistlib.loads(p.read_bytes()); data['SwiftRustSourceURL'] = url
p.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_XML, sort_keys=False))
print('Source URL configured. Verify public access and matching version before release.')
