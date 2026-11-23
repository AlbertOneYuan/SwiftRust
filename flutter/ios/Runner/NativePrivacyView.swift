// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-21.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

struct NativePrivacyView: View {
    @ObservedObject private var localization = NativeLocalization.shared
    var body: some View {
        List {
            Section(NativeL("适用范围与开发者承诺")) {
                Text(NativeL("本声明适用于 SwiftRust iOS 客户端，更新日期为 2026-11-22。SwiftRust 是连接你有权访问的远程设备的客户端。"))
                Text(NativeL("SwiftRust 使用 AirFeedback 接收你主动提交的反馈及自动崩溃报告，用于应用功能和问题排查，并使用 AirTraffic 进行匿名使用统计。应用未接入广告，不会自动向开发者上传远程画面、文件、密码、剪贴板或连接历史。"))
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
                Text(NativeL("听写仅在你启用时访问麦克风，并使用 Apple 框架在本机识别；不支持本地识别的语言不会回退到云端。音频不发送给开发者、识别服务器或远程设备。听写期间，识别文字会实时发送到当前远程设备；识别结果修正时，会回删并替换本次听写已输入的相应文字。"))
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
                Text(NativeL("SwiftRust 不创建开发者托管的用户账号，也不在开发者后台保存远程会话内容或文件数据库。登录第三方服务不等于向开发者注册账号。AirFeedback 的反馈与崩溃报告及 AirTraffic 的匿名统计按支持和分析所需保留，未承诺固定自动删除期限。可通过下方邮箱提出资料查询或删除请求；匿名统计不关联账号，开发者可能无法仅凭账号定位对应记录。"))
                Text(NativeL("本机数据会保留至你删除相关记录或文件、清除对应配置或移除应用。可在设备菜单删除连接记录和已保存密码，在下载管理删除本机文件。清除代理凭据时请关闭代理、清空地址和认证字段后保存。卸载应用不保证删除钥匙串、系统备份、已导出文件或远端数据。"))
                Text(NativeL("停止连接、关闭 Tailscale 或代理、退出账号或撤销系统权限可停止相关功能。第三方服务的数据保存、账号删除和权利请求由相应服务提供方或管理员处理，适用其政策和法律要求；本机清除或退出登录不会自动删除服务端数据。"))
            }
            Section(NativeL("匿名使用统计")) {
                Text(NativeL("AirTraffic 仅接收主页、收藏、设置的固定页面名称及安装、更新、打开、进入后台等活动。统计包含随机的每次安装标识、会话标识、时间、应用版本与构建号、系统版本、设备型号及模拟器或 TestFlight 状态。不使用广告标识，不关联登录账号，不建立人物档案，不进行跨应用追踪，并请求停用 IP 地理位置推断。"))
                Text(NativeL("统计不接收远程 ID、主机名、账号、密码、输入、搜索词、文件名、错误消息、反馈内容或远程会话内容。点击与文字自动采集、会话回放、问卷、功能开关及统计 SDK 崩溃采集均已关闭。可在「设置 → 隐私 → 匿名使用统计」关闭后续统计；不影响 AirFeedback 的主动反馈与自动崩溃报告，也不会自动删除已收到的数据。卸载或重装可能重置统计标识。"))
            }
            Section(NativeL("自动崩溃报告")) {
                Text(NativeL("应用启动时会启用 Apple MetricKit。系统通常在后续启动时交付崩溃诊断，AirFeedback 会接收崩溃时间、应用版本和构建号及 Bundle ID、设备型号、系统版本和构建、架构、语言区域、异常类型及消息、终止原因和线程堆栈。报告包含随机的每次安装标识，仅用于统计受影响的安装，不包含账号、远程文件或内存内容；异常消息仍可能包含错误上下文。"))
                Text(NativeL("未发送成功的崩溃报告最多在本机排队 20 份，在后续启动时重试。应用使用 App Attest 尝试验证报告来自真实构建；支持并配置完成时会向 Apple 及 AirFeedback 发送验证证明，无法验证时仍可提交。反馈及崩溃报告不用于行为分析。"))
            }
            Section(NativeL("主动反馈与联系")) {
                Text(NativeL("在「设置 → 关于 → 发送反馈」中，仅在你点击发送后，AirFeedback 才会接收反馈文字、你选择的最多四张图片，以及应用版本和构建号、设备型号、系统版本和语言区域。表单不要求账号或邮箱，也不附加连接日志。请勿提交密码、Auth key 或不必要的私人内容，发送前请检查截图。"))
                Text(NativeL("反馈及崩溃资料仅用于应用功能、沟通和问题排查，不用于广告、追踪或关联你的账号。资料按支持所需保留，不保证问题处理后自动删除；可通过下方邮箱请求删除开发者持有的资料，法律要求保留的资料除外。主动发送邮件时，开发者也会收到邮箱地址、邮件内容及附件。GitHub 与 X 链接仅在你打开时跳转，其账号和访问数据适用各自政策。"))
                Link(destination: NativeContact.feedback) { Label("airefactorme@icloud.com", systemImage: "envelope") }
            }
        }
        .navigationTitle(NativeL("隐私声明"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityIdentifier("native.privacyPage")
    }
}
