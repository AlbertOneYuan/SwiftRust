# SwiftRust 产品落地页

简约白色与品牌橙色，说明在 RustDesk 原有 iOS 基础上的体验改进。HTML/CSS/JS 静态页面，无需构建，没有追踪脚本、外部字体或表单数据提交。

在 SwiftRust 仓库根目录执行 `python3 -m http.server 63891 --directory website` 后访问 localhost:63891；也可直接将本目录内容部署到静态托管服务。

交互包括触控板/直接触控/快捷键盘说明切换，终端/系统多窗口/文件传输/桌面菜单展示切换，快捷键演示反馈和开源说明弹窗。内容涵盖四种输入模式、桌面菜单设备、多窗口、恢复连接、手动分辨率、统计信息、代理及内嵌 Tailscale。首屏、控制体验和终端使用用户提供的 iPhone Duo 实机截图；设备边框使用 Apple 官方素材并以 CSS 定位。多窗口展示同一电脑的不同显示器，并可切换查看 Duo 系统后台的独立窗口截图；桌面菜单使用图标长按菜单实机截图；文件传输使用用户提供的多选文件实机截图。选用的素材不展示真实远程 ID、账号或个人文件路径。

项目仓库入口为 https://github.com/AlbertOneYuan/SwiftRust 。源码已发布至主分支，页面提供真实仓库入口。现阶段不提供应用下载，不使用虚假的 GitHub 或 App Store 链接。AGPL-3.0.txt 为原项目许可证原文，第三方声明和未完成事项仍以主项目 docs/swiftrust 为准。

设计使用内置 Image Gen 生成三段概念作为参考：首屏产品介绍、模式演示、原生提升及开源说明。简报与设计规则见 DESIGN.md；页面本身通过 HTML/CSS/JS 实现，原应用图标复用项目资产；当前 Duo 屏幕内容使用实机截图，不使用 AI 重绘。

## GitHub Pages 托管

网页可以和 iOS App 共用此仓库，无需单独建立网站仓库。已提供 `.github/workflows/swiftrust-pages.yml`，只将 `website/` 上传为网站，不构建 Rust、Flutter 或 iOS，也不发布主仓库其余文件。

首次启用：

1. 将完整项目推送到你自己的 GitHub 仓库，并确认网站及工作流位于仓库的默认分支。
2. 打开仓库 **Settings → Pages → Build and deployment → Source → GitHub Actions**。
3. 打开 **Actions → Deploy SwiftRust website → Run workflow**，选择默认分支并运行。工作流仅在手动触发时部署。
4. 部署成功后，访问工作流 `github-pages` 环境中显示的 URL，通常为 `https://你的用户名.github.io/仓库名/`。这是地址格式示例，并非已发布地址。

更新落地页后，再从 Actions 手动运行工作流。仅允许默认分支部署，未写死 main/master；源码推送不会自动替换现有 Pages 首页。

使用 GitHub 自动提供的短期 GITHUB_TOKEN/OIDC 权限，不需要个人访问令牌、Apple 签名证书或另外配置 Secrets。仓库/组织如限制 Actions 或部署分支，需允许此工作流及默认分支。GitHub Free 可为公开仓库提供 Pages；私有仓库需对应付费计划，具体以 GitHub 账户权限为准。

页面资源均使用相对路径，支持仓库子路径（例如 /SwiftRust/）和日后绑定自有域名。自有域名请在 Pages 设置及 DNS 中配置，当前未写入 CNAME 或假域名。

官方参考：https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages

首屏强调“随时随地，快速连接远程桌面”，突出 SOCKS5 / HTTPS 代理配置与应用内 Tailscale。详细网络介绍保留地址/IP 与端口、代理开关、延迟检测及网页/Auth key 授权能力，不承诺特定网络下的连接性能。

## 中英文页面

中文入口为 `index.html`，完整英文入口为 `en/index.html`（`/en/`）。页顶“中文 / English”使用真实链接切换，语言随 URL 保留；静态托管和 GitHub Pages 子路径均可使用。英文页面包含独立标题、描述、替代文本和开源说明；交互文案随页面语言切换。实机截图保留原始中文界面。

Pages 通过 GitHub Actions 发布 website 目录。中文首页为 https://albertoneyuan.github.io/SwiftRust/ ，英文为 /SwiftRust/en/ ，公开隐私声明为 /SwiftRust/privacy/ 。工作流保留手动触发，发布前核对使用隐私政策链接的外部配置。
