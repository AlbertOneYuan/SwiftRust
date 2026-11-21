# SwiftRust 修改声明

修改者：SwiftRust 项目贡献者。记录日期：2026-11-20。
基于 RustDesk commit `669cb8ac62aa20d3626395877d7dd0357aec7ed2`；不是官方 RustDesk 发布。

主要修改：原生 SwiftUI/UIKit iOS 界面替代 Flutter 运行时、Rust C ABI 桥接、四种输入模式与触控板手势、原生画布与独立指针尺寸、分辨率适配、快捷键盘与自定义快捷键、SwiftTerm 终端与标签、设备外观及登录入口、统一连接确认与错误弹窗、后台断开策略与按需前台重连、SwiftRust 品牌及 Icon Composer 图标、开源说明。

同时公开了 libsodium-sys、system-configuration 的 iOS 兼容补丁，以及 libvpx 的模拟器 SDK 编译标志修复。

现有历史与许可证保留。具体实现说明见 `flutter/ios/NATIVE_FRONTEND.md`。当前工作区还包含早期 Flutter 手势/翻译等修改，不应只发布原生 Swift 文件而遗漏 Rust 与其他必要来源。修改文件清单见本目录 `MODIFIED_FILES.txt`；使用上面的 base 和 Git diff 可检查代码差异，但 Git diff 不能替代完整源码发布包。

新增原生文件带有 SwiftRust 修改日期及许可证标识。上游版权不能因品牌替换而删除。

2026-11-21：原生代理设置增加明确协议选择、域名/IP 加端口及完整 URL 输入、TCP 连接延迟与错误显示；保存时 DNS 检查移出主线程。未修改共享代理协议/TLS 实现，未验证用户实际代理。

## SwiftRust 1.0.0 — iOS 改进汇总

修改者：Albert 与 SwiftRust 项目贡献者。整理日期：2026-11-21。

- 使用 SwiftUI / UIKit 重建 iOS 前端，原生画布通过 Rust C ABI 接入原有连接核心。
- 保留 RustDesk 原版鼠标及直接触控手势，新增触控板和新直接触控；增加双指滚动、长按拖动、画布限制、指针与滚动调节和震动反馈。
- 重设计分页快捷键盘，支持自定义组合键；集成 SwiftTerm 终端、多标签和快捷面板。
- 改进上传、下载管理、重复下载检查、多选、长按及确认后的远端永久删除。
- 增加系统支持的独立多窗口、扫码、桌面菜单设备、URL Scheme 与快捷指令入口。
- 优化 SOCKS5 / HTTPS 代理设置及 TCP 连通延迟显示，集成用户态 Tailscale 与 Auth key 入口。
- 调整启动恢复、按需前台重连、会话类型保持和后台断开设置。
- 增加原生语言、隐私、开源声明、支持与反馈页面，以及 SwiftRust 图标和中英文产品落地页。

上列为本修改版本的工作范围，不表示这些能力均为 RustDesk 首次提供。远程连接、协议、编解码及其他继承能力仍来源于上游。具体实现与验证边界见原生前端记录和各功能文档。
