# SwiftRust landing design

Three coordinated concept sections: hero, hands-on experience, open details/source footer. Built-in Image Gen concepts are in this folder. Prompts describe an independent RustDesk iOS improvement, with native UI, gestures, keyboard and expanded screens. Not screenshots of a released build. Final product UI is code-native and labeled illustrative.

Tokens: white #fff; ink #171717; muted #747474; line #e9e9e9; panel #f6f6f6; orange #ff681e. System sans (SF/PingFang fallback), desktop hero 68px/1.16, section 46px/1.25, body18px/1.8, metadata14px. Page max1200px, gutters clamp24..80px. Header90px; hero~760px; section padding120px; buttons black pill, outline-free quiet text actions; no link arrows. Only purpose-framed product demo surface; three detail columns are open, divided with thin rules. Footer source band near-black.

Hero: wordmark + three anchors; two-line black/orange headline, gray two-line paragraph, explore CTA/source-anchor secondary; one code-native graphite phone tilted7deg on a light gray circle. Orange abstract desktop is drawn in CSS; native keyboard keycaps are selectable text. No private app screenshot data.

Experience: heading and paragraph, orange underline tabs for trackpad/direct/keyboard; interactive gray product canvas left, explanation and two ruled notes right. Touch feedback illustrations use two small touch-contact marks (code-native circles), not an unrequested photographic hand. Desktop/keyboard layouts adapt on mobile with no horizontal overflow. Tab states update copy and visual demo; control buttons produce local demo responses only.

Final: three open text columns (native, screen, connection), black source band and modal with true attribution and source-pending disclosure; footer independent-project note. No claimed App Store release, public GitHub repo, compliance certification, metrics or testimonials.

Update 2026-11-21: preserve the established visual direction, add a single workspace showcase with accessible terminal/windows/files tabs and illustrative non-personal content. Expand open refinement columns to six concise feature groups, correct classic/new touch gesture distinctions, document OS-dependent multiwindow/background limits and Tailscale remote prerequisites. Keep repository availability separate from version-matched source availability.

Duo asset update 2026-11-21: replace the generic phone hero with landscape and portrait Duo screenshot frames, replace the control-mode illustration with selectable real captures and an accessible enlargement dialog, and use a real terminal capture in the workspace section. Keep the supplied PNG pixels unchanged; device bezels are CSS illustrations. Existing source CTA remains prominent. Exclude captures containing actual connection IDs or personal account details.

Multiwindow clarification: show actual separate SwiftRust scenes in the iOS app switcher, using the supplied system screenshot instead of an invented side-by-side remote desktop. Add a Home Screen menu tab with the supplied redacted quick-action capture. Do not promise a fixed number of windows or Home Screen actions.

文件传输展示替换为用户提供的 Duo 多选文件截图 `duo-files.jpg`，原图完整使用，设备外框沿用 CSS 示意。对应页签改为实机展示并移除“功能示意”说明。
验证：Browser plugin not available，使用现有 Playwright 与本机 Chrome；在 1440px、390px 下验证页面标题、文件传输页签切换、图片加载及完整显示、无横向溢出、无控制台错误。仅本地修改，未发布。

多窗口增加“同一台电脑，不同显示器”用法，默认展示 `duo-displays.jpg`；可切换至保留的系统后台独立窗口截图，并点开大图。文件传输文案明确本机上传到远端与远端下载到手机的双向操作。
验证：Browser plugin not available，沿用本机 Playwright/Chrome；1440px、390px、320px 检查多窗口页签、两张截图切换、放大及 Escape 关闭，图片完整显示且无横向溢出或控制台错误。文件传输文案更新后复查桌面与手机布局。修改保留在本地仓库。

首屏文案更新为“随时随地，快速连接远程桌面”，副文案突出 SOCKS5 / HTTPS 代理优化与内嵌 Tailscale。网络详情集中说明地址/IP 与端口、独立开关、延迟检测以及 Tailscale 网页/Auth key 授权；保留远端连接条件。同步页面标题与描述，不增加未经测量的速度承诺。
验证：Browser plugin not available，使用本机 Playwright/Chrome；1440px、390px、320px 验证首屏文案、布局无横向溢出、CTA 跳转、网络说明显示与控制台健康；截图保存在本机 QA 临时目录。仅本地修改，未上传或发布。

English edition: a complete static `/en/` page with concise product copy, locale-specific metadata/alt/ARIA text and reciprocal hreflang links. Header language links are visible on desktop and mobile; mobile prioritizes the brand and language switch. Shared JavaScript localizes all mode/example changes and resolves image paths from the script URL for nested/GitHub Pages paths. Real app screenshots remain unchanged and are identified as Chinese UI captures.
QA: Browser plugin not available; existing Playwright + local Chrome at 1440/1024/780/390/320px. Verified Chinese→English→Chinese navigation, selected-language state, all mode/workspace switches, screenshot dialogs and legal dialog, decoded image assets, no untranslated English UI text (except the native-language label 中文), no overflow and no console errors. The current Cloudflare preview serves the English route; no GitHub upload.
