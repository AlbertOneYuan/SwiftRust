# Third-party notices

SwiftRust derives from RustDesk (GNU AGPL v3); see LICENCE and NOTICE. Original upstream notices remain applicable.

- SwiftTerm 1.18.0 (`7691f85b222a67a66b58499e1b2647443cf0dda7`): MIT. Full notice in `flutter/ios/Runner/SwiftTermLicense.txt`.
- Resolved iOS Rust dependencies and their available license/copyright files are collected in `flutter/ios/Runner/ThirdPartyNotices.txt`. The inventory includes build/transitive dependencies and is broader than a final linker-level SBOM. Missing-license entries are listed for review; this is not a license compatibility certification.
- Native codecs: aom, libvpx, libyuv, libjpeg-turbo, opus; bundled installed-package copyright texts are included in the same notices resource.
- SF Symbols are provided through Apple system APIs; no SF Symbols vector exports are redistributed as a third-party icon font/library. Apple SDK tools and symbols remain governed by Apple's terms.
- SwiftRust `.icon` projects and their editable vector/image assets are included under `flutter/ios/Runner/SwiftRustIcon`.

Regenerate Rust notices using `scripts/ios/collect-notices.py`; see BUILD_IOS.md. Preserve dependency license files if vendoring or packaging their source. Lockfiles and source references supplement, but do not replace, any requirement to supply actual corresponding dependency sources.

## Missing-notice review (2026-11-20)

The original 46 missing-root-license entries have been reviewed individually: 40 were supplemented/reconciled, and 6 remain pending upstream notice or authorization clarification. See [LICENSE_AUDIT.md](docs/swiftrust/LICENSE_AUDIT.md), machine-readable evidence and SHA-256 hashes in LICENSE_AUDIT.json, and outstanding items in LICENSE_REVIEW.txt. For MPL-2.0 webm bindings, preserve MPL source obligations and the nested libwebm BSD notice; do not replace them with the application's AGPL notice.

## Embedded Tailscale

Version 91 adds official libtailscale (revision dacde75057ff350e146505829beff446e6823966, BSD-3-Clause), tailscale.com 1.104.1 and its used Go modules. Original notices and the Go runtime license are bundled in flutter/ios/Runner/TailscaleNotices.txt; module inventory is docs/swiftrust/TAILSCALE_DEPENDENCIES.json. Regenerate with scripts/ios/collect-tailscale-notices.py against the pinned source. SwiftRust's Go adapter is AGPL-3.0, without relicensing upstream files. This inventory does not certify all source-distribution or license compatibility obligations.
