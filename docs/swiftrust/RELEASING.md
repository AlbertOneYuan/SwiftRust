# Source distribution checklist

- Preserve RustDesk history, copyright notices, LICENCE and third-party notices.
- Publish the complete source matching each distributed binary, including modified native and Rust sources, initialized submodule contents, necessary generated sources, resources, build scripts and compatibility patches.
- Use version tags and keep corresponding source accessible. `scripts/ios/source-archive.py` creates a source archive including initialized submodules; GitHub automatic ZIP files normally omit their contents.
- Retain applicable dependency licenses and source availability information. See THIRD_PARTY_NOTICES.md, DEPENDENCIES.json and the license audit records.
- Configure a real version-matched source URL with `scripts/ios/configure-source-url.py` where used. An upstream-only source link does not represent this modified version.
- Review applicable license conditions for the actual distribution method. This checklist is not a legal compliance certification.
- Exclude signing keys, credentials, provisioning profiles, account sessions, reviewer details, device identifiers, build products and local user state from published source.
