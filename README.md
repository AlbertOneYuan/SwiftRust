# SwiftRust

**随时随地，快速连接远程桌面。**

SwiftRust 是 Albert 基于 [RustDesk](https://github.com/rustdesk/rustdesk) 开发的 iOS 远程客户端。在保留 RustDesk 连接核心及原有鼠标、直接触控手势的基础上，使用 SwiftUI / UIKit 重建 iOS 界面，并改进触控、键盘、终端、文件传输和多窗口体验。

[项目仓库](https://github.com/AlbertOneYuan/SwiftRust) · [产品页面源码](website/) · [iOS 编译指南](docs/swiftrust/BUILD_IOS.md) · [修改记录](docs/swiftrust/MODIFICATIONS.md) · [隐私声明](docs/swiftrust/PRIVACY.md)

## iOS 改进

| 方向 | SwiftRust 的修改 |
| --- | --- |
| 原生界面 | SwiftUI / UIKit 主页、设备列表、设置和控制界面；SF Symbols、深浅色外观、可切换 App 图标。原生 App 不加载 Flutter 界面运行时。 |
| 输入与手势 | 新增触控板、新直接触控模式，保留 RustDesk 原版鼠标及直接触控模式；双指滚动、长按拖动、缩放与画布移动，支持震动反馈。 |
| 指针与画布 | 可调指针大小、移动速度、滚动速度及方向；画布锁定、最小缩放限制、显示器切换和远端支持的分辨率选择。 |
| 快捷键盘 | 分页快捷面板、自定义组合键、震动开关；系统键盘与快捷面板切换，适配横竖屏及不同窗口尺寸。 |
| 终端 | 基于 SwiftTerm 的原生终端、多标签、标签重命名和快捷键面板。 |
| 文件传输 | 本机上传、远端下载、下载管理、重复下载检查、多选和长按操作；远端永久删除前确认。 |
| 多窗口 | 在系统支持的设备上打开多个独立 SwiftRust 窗口，连接不同机器，或分别查看同一机器的不同显示器。 |
| 快速启动 | 扫码连接、桌面图标长按菜单、按连接类型保存设备入口、`swiftrust://` 参数启动及快捷指令入口。 |
| 网络设置 | SOCKS5 / HTTPS 代理输入优化，支持域名或 IP 加端口及代理连通延迟显示；内嵌用户态 Tailscale，支持 Auth key。 |
| 会话管理 | 区分启动恢复与后台返回重连，保留桌面、终端、文件传输等会话类型；可配置后台断开策略和连接确认。 |
| 信息与语言 | 原生统计浮层、语言选择、缺失界面译文的 Apple 翻译补全，以及隐私和开源声明页面。 |

多窗口能力由系统决定；后台运行受 iOS 限制。分辨率切换取决于远端系统与显示器支持。代理延迟表示代理端点的 TCP 连通延迟，不代表完整远程会话延迟。

## 项目范围与上游

本仓库以 iOS 客户端改进为主要维护范围。其他平台的使用、编译、自建 ID / 中继服务器以及 RustDesk 通用功能，请参考上游：

- [RustDesk 源码及 README](https://github.com/rustdesk/rustdesk)
- [RustDesk 官方文档](https://rustdesk.com/docs/)
- [RustDesk 自建服务器](https://github.com/rustdesk/rustdesk-server)

SwiftRust 基于 RustDesk 提交 `669cb8ac62aa20d3626395877d7dd0357aec7ed2`，是独立修改版本，与 RustDesk 官方项目无隶属关系。完整修改来源、兼容补丁及实现记录见 [修改声明](docs/swiftrust/MODIFICATIONS.md) 和 [原生前端记录](flutter/ios/NATIVE_FRONTEND.md)。

## 编译 iOS

### 环境

- Apple Silicon Mac、Xcode 及命令行工具；App 最低支持 iOS 17。
- Rust / rustup、Go，以及 CMake、Ninja、pkg-config、NASM、autoconf、automake、libtool、Python 3。
- 分别为真机和模拟器构建的 vcpkg 原生编解码依赖。
- 真机安装需要使用你自己的 Apple 开发团队和可用 Bundle ID。

已验证工具版本、依赖提交、vcpkg 安装命令及兼容补丁见 [完整 iOS 编译指南](docs/swiftrust/BUILD_IOS.md)。以下命令在仓库根目录执行，需先按该指南准备依赖：

```sh
git clone --recurse-submodules https://github.com/AlbertOneYuan/SwiftRust.git
cd SwiftRust
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
```

模拟器：

```sh
export VCPKG_ROOT="$PWD/.build-swiftrust/vcpkg-simulator"
scripts/ios/build.sh simulator
```

真机：

```sh
export VCPKG_ROOT="$PWD/.build-swiftrust/vcpkg-device"
export SWIFTRUST_TEAM_ID=YOUR_TEAM_ID
export SWIFTRUST_BUNDLE_ID=your.own.swiftrust
scripts/ios/build.sh device
```

脚本编译 Rust 连接核心、用户态 Tailscale 和原生 App。Xcode 工程位于 `flutter/ios/Runner.xcworkspace`，选择 **Runner**；目录名沿用上游，当前 iOS 界面使用 SwiftUI / UIKit。Rust 构建仍复用名为 `flutter` 的 feature，无需重新运行 Flutter Rust Bridge 代码生成器。

设备与模拟器的静态库不能混用。以上为 Apple Silicon / ARM64 路径；完整流程尚未在空白 Mac 上逐步重建验证。

## 反馈

- 问题与建议：[GitHub Issues](https://github.com/AlbertOneYuan/SwiftRust/issues)
- 邮箱：[airefactorme@icloud.com](mailto:airefactorme@icloud.com)
- 关注开发者：[Albert on X](https://x.com/kiwicatone)

反馈时请提供 App 版本、设备与系统版本、连接类型及复现步骤；请勿提交密码、Auth key、私钥或其他敏感信息。

## 许可证与致谢

SwiftRust 保留 RustDesk 的版权及许可，按 [GNU AGPL v3](LICENCE) 提供。第三方组件分别遵循其原有许可证，详见 [NOTICE](NOTICE)、[第三方声明](THIRD_PARTY_NOTICES.md) 及应用内 Open-Source Notices。

感谢 RustDesk 及其贡献者提供连接核心，感谢 SwiftTerm、Tailscale 及其他开源组件的作者。本项目不提供任何担保；请仅连接你拥有或已获授权访问的设备。
