#!/bin/bash
# Pinned official libtailscale userspace archive, plus the SwiftRust adapter.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
revision=dacde75057ff350e146505829beff446e6823966
build_root="${SWIFTRUST_TAILSCALE_BUILD_ROOT:-$repo_root/.build-swiftrust/tailscale}"
source_root="$build_root/source"
mkdir -p "$build_root"
if [ -f "$source_root/go.mod" ] && [ "$(cat "$source_root/.swiftrust-revision" 2>/dev/null || true)" != "$revision" ]; then
  echo 'Cached Tailscale source revision differs; use a fresh SWIFTRUST_TAILSCALE_BUILD_ROOT.' >&2; exit 1
fi
if [ ! -f "$source_root/go.mod" ]; then
  mkdir -p "$source_root"
  curl --fail --location --retry 2 "https://codeload.github.com/tailscale/libtailscale/tar.gz/$revision" | tar -xz --strip-components=1 -C "$source_root"
  printf '%s' "$revision" > "$source_root/.swiftrust-revision"
fi
cp "$repo_root/scripts/ios/tailscale/swiftrust.go" "$source_root/swiftrust.go"
cd "$source_root"
export CGO_ENABLED=1 GOOS=ios GOARCH=arm64
case "${1:-device}" in
 device) export CC="$source_root/swift/script/clangwrap-ios.sh"; output=libtailscale_ios.a ;;
 simulator) export CC="$source_root/swift/script/clangwrap-ios-sim-arm.sh"; output=libtailscale_ios_sim_arm64.a ;;
 *) echo 'Usage: build-tailscale.sh [device|simulator]' >&2; exit 2 ;;
esac
go build -mod=readonly -trimpath -ldflags=-w -tags ios -o "$build_root/$output" -buildmode=c-archive
printf 'Built %s\n' "$build_root/$output"
