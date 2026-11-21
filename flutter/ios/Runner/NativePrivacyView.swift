// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-21.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

struct NativePrivacyView: View {
    @ObservedObject private var localization = NativeLocalization.shared
    var body: some View {
        List {
            Section(NativeL("适用范围与开发者承诺")) {
                Text(NativeL("本声明适用于 SwiftRust iOS 客户端，更新日期为 2026-11-21。SwiftRust 是连接你有权访问的远程设备的客户端。"))
                Text(NativeL("SwiftRust 开发者不运营用于接收应用用户数据的后台服务。应用不会自动向开发者上传远程画面、文件、密码、剪贴板、连接历史或使用记录，也未接入广告、行为分析或自动上传至开发者的崩溃收集服务。"))
            }
            Section(NativeL("远程连接与外部服务")) {
                Text(NativeL("客户端联网不等于向开发者收集数据。应用运行和使用连接功能时，会与远程设备、默认或自定义 ID／中继／API 服务器及启用的代理交换连接所需的设备标识、地址、端口、认证信息和网络元数据。画面、声音、输入、文件和启用后的剪贴板在相关设备及连接服务间传输。"))
                Text(NativeL("这些服务可能按其配置和隐私政策处理、记录或保存数据。请自行确认远程设备的访问权限及服务提供方的可信程度；你可以选择自建服务器、关闭代理或停用不需要的会话功能。开发者不接收这些服务的后台记录，也无法替服务提供方访问或删除其数据。"))
            }
            Section(NativeL("本机数据与凭据")) {
                Text(NativeL("连接历史、收藏、设备别名、界面偏好、自定义快捷键、翻译缓存和下载文件保存在设备上的应用存储中。上传文件时可能建立临时副本；诊断日志也可能在本机包含设备地址、连接时间和错误。应用不自动将这些内容发送给开发者。"))
                Text(NativeL("登录你使用的 API 服务时，凭据和验证码会发送给该服务；登录状态及访问令牌保存在本机。记住的远程密码由连接核心保存。代理草稿及认证信息存于本机钥匙串，正在使用的代理配置另由连接核心管理。"))
            }
            Section(NativeL("Tailscale")) {
                Text(NativeL("仅在启用后运行内嵌 Tailscale 节点，不建立系统 VPN，也不接管其他应用。网页授权或 Auth key 登录会联系 Tailscale；服务方可能处理账号、节点名称、地址、公钥及连接元数据。应用关闭了该 SDK 的日志上传，但服务端仍可能保留运行所需记录。"))
                Text(NativeL("Auth key 不写入普通设置、钥匙串或应用日志。节点身份状态保存在应用私有目录并排除系统备份。退出 Tailscale 会清除本机节点状态；服务端设备记录、日志及账号数据应向 Tailscale 或 Tailnet 管理员管理和申请删除。"))
                Link(NativeL("Tailscale 隐私政策"), destination: URL(string: "https://tailscale.com/legal/privacy-policy")!)
            }
            Section(NativeL("苹果翻译与系统服务")) {
                Text(NativeL("苹果 Translation 框架仅接收固定界面文案，用于补全缺失译文，不接收远程画面、主机名、密码、输入、文件或剪贴板内容。译文缓存在本机，系统可能下载语言包。Apple 的服务、系统诊断和备份由你的系统设置及 Apple 隐私政策管理。"))
                Link(NativeL("苹果隐私政策"), destination: URL(string: "https://www.apple.com/legal/privacy/")!)
            }
            #if SWIFTRUST_APPSTORE
            Section(NativeL("自愿赞助")) {
                Text(NativeL("赞助通过 Apple App 内购买处理。Apple 负责付款、交易记录及退款；SwiftRust 仅在设备上验证和完成交易，不读取银行卡信息，也不向开发者上传交易或建立购买档案。TestFlight 内购买使用沙盒，不实际扣款。"))
            }
            #endif
            Section(NativeL("相机与文件权限")) {
                Text(NativeL("仅在打开扫码连接时请求相机权限，用于识别连接二维码，不保存或上传相机画面到开发者。文件导入只读取你通过系统选择器授权的项目。可在 iOS 设置撤销权限；拒绝相机权限后仍可手动输入远程 ID。"))
            }
            Section(NativeL("保存期限、删除与撤销")) {
                Text(NativeL("开发者没有应用后台的用户账号、会话内容或文件数据库，因此没有可由开发者查询或执行删除的此类数据。SwiftRust 本身不创建开发者托管的用户账号；登录第三方服务不等于向开发者注册账号。"))
                Text(NativeL("本机数据会保留至你删除相关记录或文件、清除对应配置或移除应用。可在设备菜单删除连接记录和已保存密码，在下载管理删除本机文件。清除代理凭据时请关闭代理、清空地址和认证字段后保存。卸载应用不保证删除钥匙串、系统备份、已导出文件或远端数据。"))
                Text(NativeL("停止连接、关闭 Tailscale 或代理、退出账号或撤销系统权限可停止相关功能。第三方服务的数据保存、账号删除和权利请求由相应服务提供方或管理员处理，适用其政策和法律要求；本机清除或退出登录不会自动删除服务端数据。"))
            }
            Section(NativeL("主动反馈与联系")) {
                Text(NativeL("仅当你主动发送邮件或提供资料时，开发者会收到你的邮箱地址、邮件内容及你选择附上的文件或日志，用于回复和排查问题。应用不会自动发送反馈或附加日志。请勿提交密码、Auth key 或不必要的私人内容。"))
                Text(NativeL("反馈资料仅用于处理沟通和问题。你可以通过下方邮箱请求删除开发者持有的反馈资料；法律要求保留的资料除外。GitHub 与 X 链接仅在你打开时跳转到相应平台，其账号和访问数据适用各自政策。"))
                Link(destination: NativeContact.feedback) { Label("airefactorme@icloud.com", systemImage: "envelope") }
            }
        }
        .navigationTitle(NativeL("隐私声明"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityIdentifier("native.privacyPage")
    }
}
