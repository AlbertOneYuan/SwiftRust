#!/bin/bash
# SwiftRust native iOS build; modified 2026-11-20, AGPL-3.0.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
platform="${1:-simulator}"
build_root="${SWIFTRUST_BUILD_ROOT:-$repo_root/.build-swiftrust}"
case "$platform" in
  simulator) rust_target=aarch64-apple-ios-sim; sdk=iphonesimulator; destination='generic/platform=iOS Simulator' ;;
  device) rust_target=aarch64-apple-ios; sdk=iphoneos; destination='generic/platform=iOS' ;;
  *) echo 'Usage: scripts/ios/build.sh [simulator|device]' >&2; exit 2 ;;
esac
export PATH="$HOME/.cargo/bin:$PATH"
: "${VCPKG_ROOT:?Set VCPKG_ROOT to a vcpkg checkout with matching arm64-ios codec libraries installed; see docs/swiftrust/BUILD_IOS.md}"
rustup target add "$rust_target"
scripts/ios/build-tailscale.sh "$platform"
cargo fetch --locked
python3 scripts/ios/prepare-patches.py
export SDKROOT="$(xcrun --sdk "$sdk" --show-sdk-path)"
export IPHONEOS_DEPLOYMENT_TARGET=15.0
if [ "$platform" = simulator ]; then
  export BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios_sim='--target=arm64-apple-ios15.0-simulator'
else
  export BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios='--target=arm64-apple-ios15.0'
fi
cargo build --locked --features flutter --target "$rust_target" --lib
unset SDKROOT IPHONEOS_DEPLOYMENT_TARGET
args=(-workspace flutter/ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination "$destination" -derivedDataPath "$build_root/DerivedData-$platform" "RUSTDESK_LIBRARY_DIR=$repo_root/target/$rust_target/debug" build)
if [ "$platform" = simulator ]; then
  args+=(CODE_SIGNING_ALLOWED=NO)
else
  : "${SWIFTRUST_TEAM_ID:?Set your own SWIFTRUST_TEAM_ID for device signing}"
  args+=("DEVELOPMENT_TEAM=$SWIFTRUST_TEAM_ID" "CODE_SIGN_ENTITLEMENTS=$repo_root/scripts/ios/device.entitlements")
  # Set a unique bundle ID when the original app ID is unavailable to your team.
  if [ -n "${SWIFTRUST_BUNDLE_ID:-}" ]; then args+=("PRODUCT_BUNDLE_IDENTIFIER=$SWIFTRUST_BUNDLE_ID"); fi
fi
xcodebuild "${args[@]}"
echo "App: $build_root/DerivedData-$platform/Build/Products/Debug-$sdk/Runner.app"
