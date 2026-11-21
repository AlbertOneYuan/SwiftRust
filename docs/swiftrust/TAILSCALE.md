# 内嵌 Tailscale

使用官方 libtailscale / tsnet，完全在 SwiftRust 进程的用户态中运行。不是系统 VPN，不使用 NetworkExtension，不接管其他 App，也无需另装 Tailscale iOS App。

## 使用

设置 → 连接 → Tailscale → 启用内嵌 Tailscale → 登录 Tailscale。App 内的 Safari 授权页面由 Tailscale/你的身份提供方处理密码，SwiftRust 不收集它。需要设备审批的 Tailnet 会显示等待管理员批准。

也支持输入管理后台生成的 Auth key 登录。密钥只用于本次节点认证，不保存在普通设置中；字段提交后清空，SDK 保留正常的节点身份状态。已有已登录节点需先退出登录才能换账号。

登录后列出有权发现的设备。远端也要运行 Tailscale 和 RustDesk，并在 RustDesk 开启直接 IP 访问，默认端口 21118；如改过端口，请在此页修改。Tailnet ACL/Grants 需允许此节点访问该端口。仍需 RustDesk 的密码/权限验证，不能因在 Tailnet 中而绕过。

也可在主页输入 100.64.0.0/10 范围的 IP、Tailscale IPv6 或 .ts.net:端口。普通 RustDesk ID 继续使用原路径。已配置的 HTTP/SOCKS 代理不被覆盖。内嵌节点没有配置 exit node、子网路由或 Funnel；当前仅提供此 App 的 Tailnet 设备直连。

关闭开关停止本地节点并保留登录状态，重新启用可恢复。退出登录会退出并删除 App 内的节点状态；Tailscale 管理后台中的设备记录可能仍需管理员另行删除。iOS 后台限制仍然存在，不承诺永久在线；回前台会重建本机转发监听并刷新状态。

## 构建与来源

- 官方源码：https://github.com/tailscale/libtailscale
- 固定提交：dacde75057ff350e146505829beff446e6823966；上游 go.mod 锁定 tailscale.com v1.104.1。
- SwiftRust 适配：scripts/ios/tailscale/swiftrust.go；原头文件保留在 Runner/TailscaleBridge/tailscale.h。
- Go 1.27.1+；设备和模拟器分别运行 scripts/ios/build-tailscale.sh。
- Swift 客户端、临时内存路由、本机带认证 SOCKS 与会话接入均为本次添加；未修改 hbb_common 子模块，未添加系统 VPN entitlement。
- BSD/Go 依赖声明：TailscaleNotices.txt；29 个参与构建的 Go module 清单：TAILSCALE_DEPENDENCIES.json。

正式发布对应源码时还需包含/按适用许可提供所用 SDK 及依赖的对应源码，而不只是二进制静态库。构建目录与实际节点状态不应提交。现有源码发布入口与 6 项旧依赖待核实事项继续按 RELEASING.md 处理。

## 验证边界

已验证两种架构的编译、实际 tsnet 节点启动/状态读取、本机 SOCKS5 要求认证、路由地址边界以及原生设置入口。测试使用临时、未登录的 ephemeral 节点，不会加入用户的 Tailnet。真实账号登录、节点审批与到真实 RustDesk 主机的连接需要在手机上授权后实测，不能由启动测试代替。
