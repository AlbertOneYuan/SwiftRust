# SwiftRust additional component review

Review date: 2026-11-21. Baseline: RustDesk `669cb8ac62aa20d3626395877d7dd0357aec7ed2`.

## Components introduced by the native iOS work

| Component | Evidence / scope | Required material included |
|---|---|---|
| SwiftTerm 1.18.0 | SwiftPM pin `7691f85b222a67a66b58499e1b2647443cf0dda7`; the app links the SwiftTerm library product | Original MIT permission, disclaimer and all four original copyright lines in `SwiftTermLicense.txt`; also included in aggregate notices |
| libtailscale | Pinned source `dacde75057ff350e146505829beff446e6823966` | Root BSD-3-Clause license in `TailscaleNotices.txt` |
| tailscale.com v1.104.1 and Go dependencies | `TAILSCALE_DEPENDENCIES.json` records 29 resolved modules, including libtailscale; each has a recorded root license file | Original notices in `TailscaleNotices.txt`, followed by the Go runtime/standard-library license |
| GitHub / X marks | Official SVGs identify repository/profile links; these are trademarks, not software dependencies | `BrandNotices.txt` and asset provenance in `BRAND_ASSETS.md`; no AGPL relicensing claim |
| Apple product bezels | Website assets only; not iOS application dependencies | Original design-resource license and source links in `website/assets/bezel/` |

SwiftUI, UIKit, StoreKit, Translation, Vision/AVFoundation and other Apple system frameworks are provided by the platform SDK. No additional open-source icon framework or payment SDK was introduced for the recent UI and tip work.

The pinned SwiftPM resolution also contains `swift-argument-parser` 1.8.2. The inspected SwiftTerm manifest assigns ArgumentParser to its Termcast executable, not the SwiftTerm library target used by Runner. A resolved package is not, by itself, evidence that the app distributes that library. If a future app target links ArgumentParser, include its applicable license/notice files.

No additional Rust packages are declared in Cargo.toml or Cargo.lock compared with this baseline. Native iOS adapters reuse existing core dependencies. This does not remove notice or source obligations for inherited Rust and native-codec dependencies.

## Presentation and source material

SwiftRust and RustDesk have separate attribution entries. Both retain the AGPL relationship of the combined derivative work. Their short attribution files accompany the full AGPL text. Original source-file copyrights, `LICENCE`, root `NOTICE`, SwiftTerm and Tailscale notices are retained.

The in-app aggregate drops generated Chinese audit commentary, not original license text. Full evidence and unresolved issues remain in `LICENSE_AUDIT.md`, `LICENSE_AUDIT.json` and `LICENSE_REVIEW.txt`. The notice collector now emits the same concise presentation on regeneration. Long text is read off-main and presented as lazy chunks in one continuous scroll view; export provides the complete original resource files.

## Remaining release requirements

The six existing unresolved entries remain: hbb_common, quest, repng, scrap, stunclient and target_build_utils. Their review status is not changed by this presentation work. Seek original notice/authorization evidence where required. The resolved dependency graph includes build tools and is not a final linker-level SBOM or a blanket compatibility clearance.

Before public distribution, provide complete version-matched Corresponding Source, configure its URL, and review distribution-term compatibility under RELEASING.md. Separate app entries do not separate the derivative work from its AGPL obligations.
