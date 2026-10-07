# NextBeat

本机使用的 iPhone 周计划 App，配有 WidgetKit 主屏幕小组件。使用 SwiftUI、WidgetKit 和 App Group 共享文件；不联网，不调用 AI，也没有账号系统。Muse 在 App 外生成 JSON，粘贴到“导入”页即可。

## 当前开发状态

项目文件：`NextBeat.xcodeproj`。已在 macOS 27、Xcode 27 和 iOS 27 的 iPhone 17 Pro Max 模拟器上构建并运行。核心 XCTest、命令行检查与模拟器界面测试覆盖计划导入、逐项编辑、重启后持久保存和自省语开关。中号与纵向超大组件都已实际添加到模拟器主屏幕；组件能读取共享计划及设置。当前设计的真尺寸截图见 `Screenshots/nextbeat-widget-refined-light.png` 与 `Screenshots/nextbeat-widget-refined-dark.png`。真机安装和个人账号签名尚须由你按下文在 Xcode 中完成。

## 主屏幕组件与自省语

NextBeat 提供小号、中号、普通大号及 **iOS 27 的纵向超大号**。Apple 的 [纵向超大号说明](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralargeportrait)确认它可放在 iPhone 主屏幕；在当前 iPhone 17 Pro Max 模拟器上，它占据接近整页的主屏幕区域，但系统仍保留状态栏、底部 Dock 等空间。iOS 17–26 可选普通大号。

纵向超大号顶部显示可选自省语；右上角以月份和年份标示本周，具体日期留给七列的日头。中间是周一到周日的**七列课表**，表头以上方的小号日期数字辅助下方较大的星期名称；当天星期使用朱红色块，并用整列淡色区分。每项将开始与结束时间上下对齐，开始时间用较深字重、结束时间用较浅颜色，第三行显示标题。iPhone 模拟器上已用每天 10 项、共 70 项的计划检查实际显示密度。正在进行的任务用深色块与朱红细线标记，空档时以暖铜色突出下一项。下方深色区域单独展示当前／下一任务的完整时间范围、标题和提醒语，最底部留有一条可单独设置的“今日一问”。长标题在小格中截断，深色区域可显示更多内容；超出可见格数时显示 `+N`，并优先让当前／下一任务留在可见范围。轻点组件可在 App 周视图查看全部事项。普通大号使用一行一天的摘要布局。

配色取自 App 图标：暖纸白、石墨黑与少量朱红；深色模式使用深石墨背景与柔和米白文字。大字体模式会放大标题及底部提醒区，课表数字限制在能完整显示起止时间的字号范围；可见格数减少时用 `+N` 提示其余事项，完整内容始终可在 App 内查看。组件为任务起止和跨日节点准备滚动时间线，每次预生成最多 36 条记录，并提前请求下一批，避免密集计划产生过大的 WidgetKit 归档。系统决定实际展示和重载时机，不能保证按秒或严格按分钟切换。

在 App **设置 → 组件底部** 中，可以修改“今日一问”这行的栏标题（最多 8 字）及其右侧文字；顶部和底部内容可以分别关闭。点“保存并更新小组件”后会保存到共享存储并请求组件刷新。关闭仅隐藏对应文字，内容会保留以便重新开启。旧版 `reflection-v1.json` 会自动补齐新增的底部设置及栏标题，不丢失已有文字。两处设置仍保存在同一个 App Group 的 `reflection-v1.json`；周计划仍在 `plans-v1.json`，导入／导出的周计划 JSON 格式没有变化。如果共享存储配置错误，App 和组件会明确报错。

## 首次安装 Xcode

1. 在 Mac 打开 **App Store**，搜索 **Xcode**（发布者 Apple），点击“获取”或“安装”。若提示登录 Apple 账号、接受条款或输入 Mac 管理员密码，请你本人在系统界面完成；不要把密码发给其他人。
2. 安装结束后在“应用程序”打开 Xcode，接受许可，允许安装它提示的附加组件。在 Xcode 的 **Settings → Platforms** 安装一个 iOS Simulator runtime（如尚未自动安装）。Xcode 首次启动可能需要数分钟。
3. 在“终端”运行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`，再运行 `xcodebuild -version` 和 `xcrun simctl list devices available`。第一条命令只是在已安装的 Xcode 与 Command Line Tools 间切换；若 Xcode 安装在其他路径，请改用实际路径。
4. 双击 `NextBeat.xcodeproj` 打开。选择顶部 scheme **NextBeat**，运行目的地选一个 iPhone Simulator，然后按 **⌘R**。模拟器编译不需要登录开发账号。

如果 Xcode 报 SDK 或 Simulator runtime 缺失，请回到 **Xcode → Settings → Platforms** 安装 iOS runtime，并重试。

## 导入格式

示例在 `Examples/week-2026-10-05.json`。JSON 必须包含 `week_start`（周一）、有效 IANA `timezone` 和从周一到周日连续排列的七个 `days`。无事项的日期写 `"items": []`。时间使用 `HH:mm`；开始为 `00:00` 至 `23:59`，结束可用 `24:00` 表示该日期结束时的次日零点。除此以外不能跨午夜。每项必须有 `start`、`end`、非空 `title` 和字符串 `tip`（可为空）。

导入页先“验证并预览”，再“确认保存”。验证失败会指出日期与事项，原数据不会被替换。同一 `week_start` 完整替换旧周；不同周分别保存。周视图可逐项编辑、添加、删除，并复制或分享当前周 JSON。修改时间后会自动按开始时间重新排序，重叠仍会报错。

**时区规则：** 所有日期和时刻按 JSON 的 `timezone` 解释；不会使用模拟器当前时区去猜测。夏令时跳过而不存在的当地时间，以及回拨时重复出现两次而无法判定的时间，都会被拒绝并指出日期与事项。WidgetKit 会为事项开始、结束和日期切换建立 timeline；系统决定实际展示与刷新时机，不保证秒级切换。

## 模拟器验收

1. 在 Xcode 选 NextBeat scheme 和 iPhone 模拟器，按 ⌘R。首次打开应显示“本周还没有计划”；若出现“共享存储错误”，检查两个 target 的 App Group 设置。
2. 复制 `Examples/week-2026-10-05.json`，在 App 的“导入”页粘贴，点“验证并预览”与“确认保存”。确认“周计划”可查看七天事项。
3. 模拟器主屏幕长按空白处 → 点添加小组件 → 搜索 **NextBeat** → 在 iOS 27 选纵向超大号；旧系统选普通大号。可用 Preview 查看固定时刻；不要用等待来验收时间线。
4. 在“周计划”修改一项标题与时间，回到主屏幕观察小组件；WidgetKit 可能延迟重新载入。结束 App 进程并重新打开，核对编辑后的计划仍在。
5. 在 App“设置 → 组件底部”把栏标题改成自己的文字，保存并重启 App，确认标题仍在且组件跟着更新；标题旁的 × 可快速清空后重写。分别关闭顶部与底部自省语并保存，核对组件相应句子消失；重新开启后应恢复。在 Xcode Canvas 打开 App 和 Widget 文件的 `#Preview`。预览覆盖当前事项、空档、全天结束、无计划、长标题、深色模式、大字、关闭自省语及自定义底部标题。
6. 验证失败替换：先保存有效周计划，再把同周 JSON 的结束时间改成早于开始时间，点“验证并预览”；应报错且旧计划仍在。`24:00`、准确开始/结束边界和空档由 `Scripts/run-core-checks.sh` 检查。

已保存的模拟器截图：`Screenshots/nextbeat-home-current.png`、`Screenshots/nextbeat-widget-refined-light.png`、`Screenshots/nextbeat-widget-refined-dark.png` 和 `Screenshots/nextbeat-widget-refined-large-text.png`。此前版本截图也保留在 `Screenshots/` 供对比。你可用 `xcrun simctl io booted screenshot Screenshots/nextbeat-new.png` 重新截图。

## iPhone 安装：个人免费 Apple 账号

无需预先购买 Apple Developer Program 会员。Apple 当前的 [iOS 能力表](https://developer.apple.com/help/account/reference/supported-capabilities-ios) 将 App Groups 列在免费 Apple Developer 账号可用能力中；仍须以 Xcode 对你的设备签名结果为准。

1. 在 Xcode 打开 **Xcode → Settings → Accounts**，用你自己的 Apple 账号登录。若账号没有付费会员，Xcode 会显示 **Personal Team**。无需把账号或密码写进项目。
2. 在项目导航器点最上方 **NextBeat**，分别选 **NextBeat** 与 **NextBeatWidget** 两个 target。在 **Signing & Capabilities** 中都勾选 **Automatically manage signing**，并选同一个 Team。
3. 把两个 target 的 **Bundle Identifier** 改成你自己的唯一值，例如 `com.你的代号.nextbeat` 与 `com.你的代号.nextbeat.widget`。两者须不同，Widget ID 建议以 App ID 加 `.widget` 结尾。当前 `com.example.nextbeat` 仅为占位符。
4. 在项目的 **Build Settings** 搜索 `APP_GROUP_IDENTIFIER`，将当前 `group.com.example.nextbeat` 改为唯一 ID，例如 `group.com.你的代号.nextbeat`。确认两个 target 的 **App Groups** capability 都勾选了同一个 Group。`App/NextBeat.entitlements` 与 `Widget/NextBeatWidget.entitlements` 使用此 build setting；两份 Info.plist 的 `NextBeatAppGroup` 也使用它。若 Xcode 没有显示 App Groups 行，请给两个 target 都点 **+ Capability → App Groups** 并选择同一 Group。
5. 用 USB 连接 iPhone，解锁并在手机上点“信任此电脑”（如果出现）。在 Xcode 顶部运行目的地选你的 iPhone；如 Xcode 要求注册设备或修复签名，按它的提示操作。不要选择付费服务，除非你自己决定加入。
6. 在 iPhone **设置 → 隐私与安全性 → 开发者模式** 打开开关，按提示重启并再次确认。这个选项可能在首次与 Xcode 配对后才出现。回到 Xcode 按 **⌘R**；App 和 Widget 会一起安装。
7. 在 iPhone 主屏幕长按空白处，点 **编辑/添加小组件**（具体文字取决于 iOS 版本），搜索 **NextBeat**。iOS 27 选择纵向超大号；较旧的 iOS 选择普通大号。点小组件会打开 App。
8. 首次运行若 App 显示共享存储错误，先检查两个 target 的 Team、Bundle ID、App Groups ID 和签名是否一致，再重新运行。不能把数据改存到 App 的私有目录来掩盖错误。

Apple 的 [免费个人账号说明](https://developer.apple.com/help/account/basics/about-your-developer-account)指出：个人签发的设备安装 provisioning profile **7 天后过期**，届时需在 Xcode 重新构建并安装；每台设备最多 3 个此类 App，设备及 App ID 也有免费额度限制。重装时保持相同 Bundle ID 和 App Group ID，可避免改变存储位置；操作前建议从 App 的“导出 JSON”备份计划。Xcode 在签名时如报告 App Groups 对该账号不可用，应把具体错误回传核查，不能声称 Widget 已可靠共享数据。

## 开发命令

- `Scripts/run-core-checks.sh`：在只有命令行 Swift 工具时检查模型、时区、`24:00`、边界、timeline、原子替换与多周保存。
- `swift test`：运行共享模型的 XCTest。
- `xcodebuild -project NextBeat.xcodeproj -scheme NextBeat -destination 'platform=iOS Simulator,name=iPhone 17' test`：运行 App 界面测试。Debug 界面测试使用启动环境变量把测试 JSON 预填入导入页；正式运行和 Release 包不会读取这一测试变量。
- `xcodegen generate`：按 `project.yml` 重新生成 `NextBeat.xcodeproj`。仓库已包含生成好的项目，普通使用不需要安装 XcodeGen。若你在 Xcode 手动改了签名，再运行此命令会覆盖项目配置；需要保留时请同步修改 `project.yml`。
- `xcodebuild -project NextBeat.xcodeproj -scheme NextBeat -destination 'platform=iOS Simulator,name=你的模拟器名称' build`：编译 App 和 Widget。

## GitHub 同步

项目对应私有仓库：[Blue4u0610/NextBeat](https://github.com/Blue4u0610/NextBeat)。完成一轮可构建的功能修改后，在本目录运行 `git add .`、`git commit -m "说明本轮改动"`、`git push`。`DerivedData/`、测试结果和本机 Xcode 用户设置已被 `.gitignore` 排除；截图和可直接打开的 Xcode 项目会随源码上传。
