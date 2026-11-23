# SwiftRust Privacy Policy

Last updated: November 22, 2026.

## About This Policy

This policy covers the SwiftRust iOS app, a client for remote devices you are authorized to access. Updated November 22, 2026.

SwiftRust does not automatically upload remote screens, files, passwords, clipboard contents or connection history to the developer. Material you manually select for feedback may contain such information, and system error messages in crash diagnostics may contain context. The app uses AirFeedback for feedback and automatic crash diagnostics, and AirTraffic for anonymous usage analytics, as described below. There are no ads.

## Connections and External Services

Remote access requires network communication. SwiftRust exchanges connection details with your remote devices, default or custom ID, relay and API servers, and any proxies you enable. This may include device IDs, addresses, ports, authentication details and network metadata. Session traffic includes screens, audio, input, files and, when enabled, clipboard contents. This traffic is not sent to a developer-operated collection server.

Service providers may process or retain data under their own settings and privacy policies. Use only devices you may access and providers you trust. You can choose self-hosted servers, disable proxies or turn off session features. The developer does not receive these connection-service providers’ backend records and cannot access or delete records on their behalf.

## Data Stored on Your Device

Connection history, favorites, device names, preferences, shortcuts, cached translations and downloads stay in the app’s local storage. Uploads may create temporary copies. Local diagnostic logs may contain device addresses, connection times and errors. These stored records and logs are not automatically uploaded; the crash diagnostics described below may include contextual system error messages.

Signing in sends credentials and verification codes to the API service you use. Sign-in state and access tokens stay on your device. The connection core stores saved remote passwords. Proxy drafts and credentials are kept in the device Keychain; the connection core also manages the active proxy settings.

## Tailscale

The embedded Tailscale node runs only when you enable it. It does not create a system VPN or route traffic from other apps. Browser authorization and Auth key sign-in contact Tailscale, which may process account details, node names, addresses, public keys and connection metadata. SDK log uploads are disabled; Tailscale may still keep records needed to provide its service.

Auth keys are not written to app preferences, Keychain or app logs. Node identity is stored in the app’s private directory and excluded from system backups. Signing out of Tailscale clears local node state. Contact Tailscale or your tailnet administrator to manage or request deletion of server-side device records, logs and account data.

[Tailscale Privacy Policy](https://tailscale.com/legal/privacy-policy)

## Apple Services

Dictation accesses the microphone only when you start it and uses Apple’s on-device recognition. Unsupported languages do not fall back to cloud recognition. Audio is not sent to the developer, a recognition server or the remote device. Recognized text is sent to the current remote device during dictation. Recognition corrections delete and replace the affected suffix entered by the current dictation.

Apple’s Translation framework is used only to translate fixed interface text. It is not given remote screens, hostnames, passwords, input, files or clipboard contents. Translations are cached locally, and iOS may download language packs. Apple services, system diagnostics and backups follow your system settings and Apple’s privacy policy.

App Attest verifies app authenticity through Apple. Attestation proofs are sent to Apple and AirFeedback.

[Apple Privacy Policy](https://www.apple.com/legal/privacy/)

## Optional Tips (App Store Builds)

Apple processes tips through In-App Purchase and handles payment records and refunds. SwiftRust verifies and completes transactions on your device. It does not see your payment card details or send transactions to a developer-operated purchase database. TestFlight purchases are sandbox tests and do not charge you.

## Camera and Files

Camera access is requested only when you open the QR scanner. Camera images are used to read connection codes, not saved or uploaded to the developer. File import accesses only items you authorize in the system picker. You can revoke permissions in iOS Settings. Manual remote ID entry works without camera access.

## Crash Diagnostics

AirFeedback automatically receives MetricKit crash diagnostics on a subsequent app launch. Reports include crash time, bundle identifier, app version/build, device model, OS version, architecture and region, exception type/code/signal/message, termination information and thread stacks. A random per-install identifier is not an account identifier.

Reports do not include remote session images or input, passwords, files or memory dumps. System error messages may nevertheless contain context. Up to 20 reports are queued locally for retry. There is no in-app switch to disable crash reporting; the analytics setting below does not control it.

## Anonymous Usage Analytics

Anonymous usage analytics is sent to AirTraffic using the PostHog SDK, not hosted in PostHog Cloud. Settings → Privacy → Anonymous Usage Analytics is on by default. Turning it off is saved persistently and stops new events thereafter, without affecting feedback or crash reporting. Previously queued or sent events may still arrive, and historical data is not automatically deleted.

Events cover only fixed pages (Home, Favorites and Settings) and install, update, app-open and background events. They include a random installation ID, event ID, session ID and timestamp. Technical fields include SDK name/version, app version/build and previous version/build, OS name/version, manufacturer, device model/type, simulator/TestFlight/sideload status and whether the app reopened from the background.

Analytics is not linked to accounts or used for advertising tracking. It does not collect IDFA, use fingerprinting, build user profiles, record session replays, automatically capture controls or enrich data with geolocation. It does not include remote device IDs, passwords, session images or input, search content, filenames or error content. Network communication necessarily exposes your IP address to the receiving service.

The per-install ID can link events from the same installation, not identify a signed-in user; a new installation or device may be counted anew. Feedback/crash reporting and analytics use separate installation identifiers.

## Retention and Deletion

SwiftRust does not create developer-hosted user accounts. The developer does not maintain a database of your remote-service accounts, session contents or files, apart from material you choose to submit in feedback. Signing in to an external service creates no account with the SwiftRust developer.

Local data remains until you delete it, clear its settings or remove the app. Delete connection history and saved passwords from device menus, and local files from Downloads. To clear proxy credentials, disable the proxy, clear the address and authentication fields, then save. Removing the app may leave Keychain items, backups, exported files and remote data intact.

You can stop connections, disable Tailscale or proxies, sign out, or revoke system permissions to stop the related features. Ask the relevant provider or administrator about server-side retention, account deletion and other data rights. Their policies and applicable law govern those requests. Clearing local data or signing out does not automatically delete server-side records.

There is no single automatic expiry period for feedback, crash or analytics data; it is retained as needed for support, diagnostics and usage statistics, except where retention is required by law. Contact airefactorme@icloud.com to request deletion and provide information that may help locate the records. Anonymous records cannot necessarily be found through a sign-in email address. Stopping reporting is not deletion.

## Feedback and Contact

In-app feedback is sent manually to AirFeedback and does not require an account or email address. You can submit up to 4,000 characters and up to four selected images, compressed as JPEG. It includes app version/build, device model, OS version and locale; connection logs are not automatically attached. Screenshots may contain private information: review selected images and do not submit passwords, Auth keys or unnecessary private content.

Feedback and crash data are used for support and diagnostics; analytics data is used to understand product usage. The developer and AirBuild, the provider of AirFeedback and AirTraffic, can access the respective data for these purposes. If you contact the developer by email, your email address, message and chosen attachments are received for support. GitHub and X links open only when you select them. Those platforms handle account and access data under their own policies.

Contact: airefactorme@icloud.com

---

# SwiftRust 隐私声明

更新日期：2026-11-22。

## 适用范围与开发者承诺

本声明适用于 SwiftRust iOS 客户端，更新日期为 2026-11-22。SwiftRust 是连接你有权访问的远程设备的客户端。

SwiftRust 不会自动向开发者上传远程画面、文件、密码、剪贴板或连接历史。你手动选择的反馈资料可能含有这些信息，崩溃诊断中的系统错误消息也可能带有上下文。应用使用 AirFeedback 接收反馈和自动崩溃诊断，并使用 AirTraffic 进行匿名使用统计，详见下文。应用不含广告。

## 远程连接与外部服务

客户端联网不等于向开发者收集数据。应用运行和使用连接功能时，会与远程设备、默认或自定义 ID／中继／API 服务器及启用的代理交换连接所需的设备标识、地址、端口、认证信息和网络元数据。画面、声音、输入、文件和启用后的剪贴板在相关设备及连接服务间传输。

这些服务可能按其配置和隐私政策处理、记录或保存数据。请自行确认远程设备的访问权限及服务提供方的可信程度；你可以选择自建服务器、关闭代理或停用不需要的会话功能。开发者不接收这些连接服务的后台记录，也无法替服务提供方访问或删除其数据。

## 本机数据与凭据

连接历史、收藏、设备别名、界面偏好、自定义快捷键、翻译缓存和下载文件保存在设备上的应用存储中。上传文件时可能建立临时副本；诊断日志也可能在本机包含设备地址、连接时间和错误。应用不自动上传这些本机记录和日志；下文所述崩溃诊断可能包含带有上下文的系统错误消息。

登录你使用的 API 服务时，凭据和验证码会发送给该服务；登录状态及访问令牌保存在本机。记住的远程密码由连接核心保存。代理草稿及认证信息存于本机钥匙串，正在使用的代理配置另由连接核心管理。

## Tailscale

仅在启用后运行内嵌 Tailscale 节点，不建立系统 VPN，也不接管其他应用。网页授权或 Auth key 登录会联系 Tailscale；服务方可能处理账号、节点名称、地址、公钥及连接元数据。应用关闭了该 SDK 的日志上传，但服务端仍可能保留运行所需记录。

Auth key 不写入普通设置、钥匙串或应用日志。节点身份状态保存在应用私有目录并排除系统备份。退出 Tailscale 会清除本机节点状态；服务端设备记录、日志及账号数据应向 Tailscale 或 Tailnet 管理员管理和申请删除。

[Tailscale 隐私政策](https://tailscale.com/legal/privacy-policy)

## 苹果翻译与系统服务

听写仅在你启用时访问麦克风，并使用 Apple 框架在本机识别；不支持本地识别的语言不会回退到云端。音频不发送给开发者、识别服务器或远程设备。听写期间，识别文字会实时发送到当前远程设备；识别结果修正时，会回删并替换本次听写已输入的相应文字。

苹果 Translation 框架仅接收固定界面文案，用于补全缺失译文，不接收远程画面、主机名、密码、输入、文件或剪贴板内容。译文缓存在本机，系统可能下载语言包。Apple 的服务、系统诊断和备份由你的系统设置及 Apple 隐私政策管理。

App Attest 通过 Apple 验证应用真实性，验证证明会发送给 Apple 和 AirFeedback。

[Apple 隐私政策](https://www.apple.com/legal/privacy/)

## 自愿赞助（App Store 版本）

赞助通过 Apple App 内购买处理。Apple 负责付款、交易记录及退款；SwiftRust 仅在设备上验证和完成交易，不读取银行卡信息，也不向开发者上传交易或建立购买档案。TestFlight 内购买使用沙盒，不实际扣款。

## 相机与文件权限

仅在打开扫码连接时请求相机权限，用于识别连接二维码，不保存或上传相机画面到开发者。文件导入只读取你通过系统选择器授权的项目。可在 iOS 设置撤销权限；拒绝相机权限后仍可手动输入远程 ID。

## 崩溃诊断

AirFeedback 会在后续启动应用时自动接收 MetricKit 崩溃诊断。报告包括崩溃时间、应用包标识、应用版本／构建号、设备型号、系统版本、架构和区域、异常类型／代码／信号／消息、终止信息及线程堆栈。随机的每安装标识不是账号标识。

报告不包含远程会话画面或输入、密码、文件或内存转储，但系统错误消息仍可能带有上下文。本机最多排队保存 20 份报告供重试。应用内没有关闭崩溃上报的开关，下述统计设置也不控制崩溃上报。

## 匿名使用统计

匿名使用统计通过 PostHog SDK 发送至 AirTraffic，并非托管在 PostHog Cloud。设置 → 隐私 → 匿名使用统计默认开启。关闭状态会持久保存，并停止之后的新事件，不影响反馈或崩溃上报。此前排队或已发送的事件仍可能到达，历史数据不会自动删除。

事件仅涵盖固定页面（Home／首页、Favorites／收藏、Settings／设置）以及安装、更新、打开应用和进入后台事件，包括随机安装 ID、事件 ID、会话 ID 和时间戳。技术字段包括 SDK 名称／版本、应用版本／构建号及先前版本／构建号、系统名称／版本、制造商、设备型号／类型、模拟器／TestFlight／侧载状态，以及是否从后台重新打开。

统计不关联账号，也不用于广告跟踪；不采集 IDFA、不使用指纹识别、不建立用户画像、不录制会话回放、不自动采集控件，也不进行地理位置增强。统计不包含远程设备 ID、密码、会话画面或输入、搜索内容、文件名或错误内容。网络通信必然会向接收服务暴露你的 IP 地址。

每安装标识可以关联同一安装的事件，但不是登录用户身份；新安装或更换设备可能被重新计数。反馈／崩溃上报与统计使用不同的安装标识。

## 保存期限、删除与撤销

SwiftRust 本身不创建开发者托管的用户账号。除你主动提交的反馈资料外，开发者不建立你的远程服务账号、会话内容或文件数据库；登录第三方服务不等于向开发者注册账号。

本机数据会保留至你删除相关记录或文件、清除对应配置或移除应用。可在设备菜单删除连接记录和已保存密码，在下载管理删除本机文件。清除代理凭据时请关闭代理、清空地址和认证字段后保存。卸载应用不保证删除钥匙串、系统备份、已导出文件或远端数据。

停止连接、关闭 Tailscale 或代理、退出账号或撤销系统权限可停止相关功能。第三方服务的数据保存、账号删除和权利请求由相应服务提供方或管理员处理，适用其政策和法律要求；本机清除或退出登录不会自动删除服务端数据。

反馈、崩溃和统计数据没有统一的自动到期天数，按支持、诊断和使用统计所需保留；法律要求保留的资料除外。你可以通过 airefactorme@icloud.com 请求删除，并提供有助于定位记录的信息，但不保证能通过登录邮箱找到匿名记录。停止上报不等于删除。

## 主动反馈与联系

应用内反馈仅在你手动发送时提交至 AirFeedback，无需账号或邮箱。你可以提交最多 4,000 字符和最多四张选择的图片，图片会压缩为 JPEG。反馈附带应用版本／构建号、设备型号、系统版本和区域语言设置（locale），不会自动附加连接日志。截图可能包含隐私信息：请检查所选图片，不要提交密码、Auth key 或不必要的私人内容。

反馈和崩溃数据用于支持与诊断，统计数据用于了解产品使用情况。开发者以及 AirFeedback 和 AirTraffic 的服务提供方 AirBuild 可为相应用途访问各自的数据。如果你通过邮件联系开发者，开发者会收到你的邮箱地址、邮件内容及你选择的附件，用于支持沟通。GitHub 与 X 链接仅在你打开时跳转到相应平台，其账号和访问数据适用各自政策。

联系邮箱：airefactorme@icloud.com
