# 构建 SwiftRust iOS

本仓库包含 RustDesk 上游源码、SwiftRust 原生前端、Rust C ABI、Icon Composer 可编辑资源、Cargo.lock 与 SwiftPM Package.resolved。原生 App 不加载 Flutter.framework/App.framework；Cargo 的 `flutter` feature 名称仍用于编译现有连接核心，不代表 UI 使用 Flutter。

## 本次验证环境与版本

- Apple Silicon macOS；Xcode 27.2，iOS 27.2 SDK；App 最低 iOS 17。
- SwiftTerm 1.18.0，revision 7691f85b222a67a66b58499e1b2647443cf0dda7。
- libs/hbb_common: fae47e024dd83cef6aaecde0aa7d11731df11649。
- vcpkg checkout d13c536672dced4b8c671955ea7d057a1b7a1ff8，manifest baseline 9e593bb18ea69cc5095e012465dcd675a822ed0d。
- 已安装原生 codec：aom 3.14.1、libvpx 1.15.2、libyuv 1857、opus 1.5.2、libjpeg-turbo 3.2.0。完整解析依赖见 DEPENDENCIES.json 和锁文件。
- 已复制现有生成桥接源文件；不需要重新运行 flutter_rust_bridge 代码生成器。

## 准备

安装 Xcode 命令行工具、Rust/rustup、CMake、Ninja、pkg-config、NASM、autoconf、automake、libtool、Python 3。命令均在仓库根目录运行。Git clone 后执行：

```sh
git submodule update --init --recursive
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
```

vcpkg 的设备和模拟器都叫 `arm64-ios`，但 SDK 不同，必须使用独立安装目录，不能互相复用二进制。以下以模拟器为例；设备将 `simulator` 换成 `device`：

```sh
mkdir -p .build-swiftrust
git clone https://github.com/microsoft/vcpkg .build-swiftrust/vcpkg-simulator
git -C .build-swiftrust/vcpkg-simulator checkout d13c536672dced4b8c671955ea7d057a1b7a1ff8
.build-swiftrust/vcpkg-simulator/bootstrap-vcpkg.sh -disableMetrics
.build-swiftrust/vcpkg-simulator/vcpkg install --triplet arm64-ios \
  --x-manifest-root="$PWD/scripts/ios/deps/simulator" \
  --x-install-root="$PWD/.build-swiftrust/vcpkg-simulator/installed" \
  --overlay-triplets="$PWD/scripts/ios/deps/simulator/triplets" \
  --overlay-ports="$PWD/scripts/ios/deps/ports" \
  --overlay-ports="$PWD/res/vcpkg"
export VCPKG_ROOT="$PWD/.build-swiftrust/vcpkg-simulator"
scripts/ios/build.sh simulator
```

设备签名使用自己的团队与可用 Bundle ID；不要复制发布者的私钥：

```sh
export VCPKG_ROOT="$PWD/.build-swiftrust/vcpkg-device"
export SWIFTRUST_TEAM_ID=YOUR_TEAM_ID
export SWIFTRUST_BUNDLE_ID=your.own.swiftrust
scripts/ios/build.sh device
```

通过 Xcode 打开 `flutter/ios/Runner.xcworkspace`，选择 Runner、自己的签名团队和真机，也可安装输出的 Runner.app：

```sh
xcrun devicectl device install app --device YOUR_DEVICE_UDID PATH_TO_Runner.app
```

脚本使用空 entitlements 构建基本远程客户端；不申请推送/Wi-Fi entitlement。若自行增加这些能力，请配置对应 App ID。初次签名可能需要在 Xcode 登录自己的账号、创建描述文件。

## 已有兼容补丁

`scripts/ios/deps/ports/libvpx` 保留本次构建使用的模拟器 SDK 编译标志修复；条件仅在 iOS Simulator 生效，其余 codec 使用仓库 res/vcpkg ports。

`prepare-patches.py` 将已锁定 libsodium-sys 0.2.7 的 arm64 模拟器支持，以及 system-configuration 0.5.1 的 iOS IrDA 符号兼容补丁应用到本机 Cargo 源缓存。这与当前已验证版本采用的补丁相同，修改内容在 patches/ 中公开。它会修改缓存；若之前编译过未打补丁的包，先对这两个包 cargo clean。将来更换版本必须重新验证补丁，不要静默沿用。

## 许可证清单

```sh
cargo metadata --locked --features flutter --format-version 1 --filter-platform aarch64-apple-ios > .build-swiftrust/metadata.json
scripts/ios/collect-notices.py .build-swiftrust/metadata.json "$VCPKG_ROOT/installed/arm64-ios/share"
```

原 46 项扫描结果已逐项核查，40 项已补齐/澄清；LICENSE_REVIEW.txt 目前列出剩余 6 项。LICENSE_AUDIT.json 保存版本、原文来源、校验和与结论，collect-notices.py 会验证后应用这些补充。当前脚本是构建和归档辅助，不声称已在空白 Mac 上完成全部依赖重建。

## 内嵌 Tailscale（91 起）

需要 Go 1.27.1 或更新版本（本机验证 Go 1.27.4），并可访问官方 Go 模块及 libtailscale 源码下载服务。`scripts/ios/build.sh` 会调用 `build-tailscale.sh`；如单独用 Xcode，先分别执行 `scripts/ios/build-tailscale.sh device` / `simulator`。静态库放在忽略的 `.build-swiftrust/tailscale` 中，不能混用设备和模拟器归档。脚本锁定官方 libtailscale 提交，在其原 Go module 内叠加 SwiftRust 适配文件，`go build -mod=readonly -trimpath` 保留上游 go.mod/go.sum 锁定关系。不要把登录状态目录或 Tailnet 私钥放到仓库里。集成说明见 [TAILSCALE.md](TAILSCALE.md)。

## Optional shortcut template regeneration

The app includes signed, generic native-action workflow templates. To regenerate them on macOS with Apple's Shortcuts CLI:

```sh
python3 scripts/ios/build-shortcut-templates.py
```

The signer sends each placeholder-only workflow to Apple for validation. Device IDs remain blank import questions; do not put credentials or personal addresses into the build templates. Keep the signed resource bytes unchanged at runtime. Apple's file sharing/signing documentation: https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac . The editable generator is included as corresponding source; no third-party runtime library is used.

## Optional feedback and diagnostics configuration

The public source does not contain the developer’s service key or Apple team ID. Feedback, crash uploads and anonymous analytics remain inactive until a service key is configured. To use your own AirFeedback environment, set `SwiftRustFeedbackKey` in the app’s build-generated Info.plist. Set `SwiftRustAppAttestTeamID` only if you also configure App Attest for your own Apple team. Keep deployment-specific values in local, ignored build configuration.
