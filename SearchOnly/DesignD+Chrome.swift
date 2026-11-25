import SwiftUI

// 「极简」里挨着网页或盖在网页上的几块：底栏、消息页切换、使用时间提醒、登录提示、浮动按钮、进度条。
// 规范和小部件见 DesignD.swift

extension DesignD {
    /// 底部导航栏：四个细线图标，不带字。选中的是墨色、下面一小段红线，其余是灰的。
    /// 首页就是搜索，所以首页的图标是一个小搜索框。底色跟网页一样，上面一条细线。
    /// 四个图标对着屏幕正中间左右各两个：把屏幕宽度分成五份，图标落在四条分界线上，
    /// 图标之间、图标到屏幕两边都是一样远。要是只把宽度切成四格，两头的图标会贴着边、中间又隔得太开
    struct TabBar: View {
        @ObservedObject var browser: Browser

        var body: some View {
            GeometryReader { geo in
                entries
                    // 每格占五分之一的宽度，两头各空半格
                    .padding(.horizontal, geo.size.width / 10)
            }
            .frame(height: Metrics.tabBar)
            .background(Palette.background.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rule() }
        }

        private var entries: some View {
            HStack(spacing: 0) {
                entry("首页", selected: browser.currentTab == .home, action: { browser.showSearchHome() }) {
                    SearchFieldGlyph()
                }
                entry("问 AI", selected: browser.currentTab == .ai, action: { browser.openAIChat() }) {
                    SparkGlyph()
                }
                entry("消息", selected: browser.currentTab == .messages, action: { browser.openChats() }) {
                    Image(systemName: "bubble.left").font(Typo.iconTab)
                }
                entry("我", selected: browser.currentTab == .me, action: { Task { await browser.openProfile() } }) {
                    Image(systemName: "person").font(Typo.iconTab)
                }
            }
        }

        /// 一格：图标在中间，选中时下面多一小段红线。
        /// 用线不用圆点：这套界面里「选中」都是字下面一条线；圆点挨着聊天气泡还会被当成「有未读」
        private func entry(_ title: String, selected: Bool, action: @escaping () -> Void,
                           @ViewBuilder icon: () -> some View) -> some View {
            Button {
                hideKeyboard()
                action()
            } label: {
                icon()
                    .foregroundStyle(selected ? Palette.ink : Palette.faint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(Palette.mark)
                            .frame(width: Metrics.space12, height: Metrics.underline)
                            .padding(.bottom, Metrics.space4)
                            .opacity(selected ? 1 : 0)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(Press())
            .accessibilityLabel(title)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    /// 「消息」页顶上的切换：靠左的两个词，选中的是墨色、字下面压一条 2pt 的墨线。
    /// 墨线贴着字、不贴底边：底边那条细线是留给网页的加载进度走的（见 LoadingBar）。
    /// 小红书网页版把私信和通知拆成了两个页面（/chat 和 /notification），这里用切换接起来
    struct MessagesSwitcher: View {
        @ObservedObject var browser: Browser
        @Namespace private var underline

        private var onChats: Bool { browser.currentPath?.hasPrefix("/chat") == true }
        /// 每个词左右各留这么多，点起来够宽
        private let itemPadding = Metrics.space12

        var body: some View {
            HStack(spacing: 0) {
                item("私信", selected: onChats) { browser.openChats() }
                item("评论和通知", selected: !onChats) { browser.openNotifications() }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.gutter - itemPadding)
            .frame(height: Metrics.touch)
            .background(Palette.background.ignoresSafeArea(edges: .top))
            .overlay(alignment: .bottom) { Rule() }
            .animation(.quick, value: onChats)
        }

        private func item(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                UnderlinedLabel(selected: selected) {
                    Text(title).font(selected ? Typo.bodyMedium : Typo.body)
                } placeholder: {
                    Text(title).font(Typo.bodyMedium)
                } underline: {
                    Rectangle().fill(Palette.ink).matchedGeometryEffect(id: "underline", in: underline)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, itemPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    /// 用到每日上限时的提醒：整屏换成底色，只有一个很大的细数字、一句平和的话，
    /// 和拇指边上一个墨色的按钮。不说教。
    /// 顶上的名字、正中间那条线、「今天」压着大数字，都跟首页一个位置，像首页换了一张脸
    struct UsageReminder: View {
        @ObservedObject var usage: UsageTimer
        let openSettings: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                Text("只搜")
                    .font(Typo.smallMedium)
                    .foregroundStyle(Palette.secondary)
                    .frame(height: Metrics.touch)
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    UsageDial(minutes: usage.todayMinutes, size: .large) { Text("分钟") }
                    TickBar(fraction: 1)
                        .padding(.top, Metrics.space16)
                    Text("到了你设的 \(Text(verbatim: String(usage.limitMinutes)).font(Typo.monoInput)) 分钟。找到想要的了吗？")
                        .font(Typo.input)
                        .foregroundStyle(Palette.ink)
                        .padding(.top, Metrics.space28)
                    Text("之后每多用 \(Text(verbatim: "10").font(Typo.monoSmall)) 分钟会再提醒一次。")
                        .font(Typo.small)
                        .foregroundStyle(Palette.secondary)
                        .padding(.top, Metrics.space8)
                }
                .multilineTextAlignment(.center)
                // 上面一份空、下面两份空：数字落在屏幕中间偏上
                Spacer(minLength: 0)
                Spacer(minLength: 0)
                Button("知道了") { usage.alertShown = false }
                    .buttonStyle(BoxButton())
                    .padding(.horizontal, Metrics.boxInset - Metrics.gutter)
                Button {
                    usage.alertShown = false
                    openSettings()
                } label: {
                    Text("调整提醒时间")
                        .font(Typo.small)
                        .foregroundStyle(Palette.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Metrics.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(Press())
                .padding(.top, Metrics.space4)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, Metrics.space8)
            .frame(maxWidth: Metrics.maxWidth)
            .frame(maxWidth: .infinity)
            .background(Palette.background.ignoresSafeArea())
            // 键盘别盖住按钮
            .onAppear { hideKeyboard() }
        }
    }

    /// 登录要扫码时浮在登录页顶部的帮忙提示（逻辑见 LoginHelp.swift）：
    /// 一块描了墨线的平板，没有阴影；两个按钮一个实心、一个描边
    struct LoginBanner: View {
        @ObservedObject var browser: Browser

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Metrics.space8) {
                    Text("需要扫码确认登录")
                        .font(Typo.bodyMedium)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                    Button {
                        browser.loginHelpDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(Typo.iconSmall)
                            .foregroundStyle(Palette.ink)
                            .frame(width: Metrics.touch, height: Metrics.touch, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(Press())
                    .accessibilityLabel("关闭")
                }
                .frame(height: Metrics.touch)
                Text(browser.loginHelpMessage)
                    .font(Typo.small)
                    .foregroundStyle(Palette.secondary)
                    .lineSpacing(Metrics.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Metrics.space8) {
                    scanButton(.weChat, filled: true)
                    scanButton(.xiaohongshu, filled: false)
                }
                .padding(.top, Metrics.space12)
            }
            .padding(.horizontal, Metrics.boxPadding)
            .padding(.bottom, Metrics.boxPadding)
            .background(Palette.background, in: shape)
            .overlay { shape.strokeBorder(Palette.ink, lineWidth: Metrics.line) }
            .padding(.horizontal, Metrics.boxInset)
            .padding(.top, Metrics.space8)
            .frame(maxWidth: Metrics.maxWidth)
        }

        private func scanButton(_ app: ScanApp, filled: Bool) -> some View {
            Button("用\(app.name)确认") {
                Task { await browser.saveLoginQR(andOpen: app) }
            }
            .buttonStyle(BoxButton(filled: filled, height: Metrics.touch, radius: Metrics.radiusSmall))
        }
    }

    /// 整页加载时网页顶上的进度：一条 1pt 的墨线，往上挪一条线的位置。
    /// 在消息页它正好盖在切换条底边那条灰细线上，看起来是那条细线从左往右变黑，不会多出一条线
    struct LoadingBar: View {
        let progress: Double

        var body: some View {
            GeometryReader { geo in
                Rectangle()
                    .fill(Palette.ink)
                    .frame(width: geo.size.width * progress)
                    .animation(.easeOut(duration: 0.25), value: progress)
            }
            .frame(height: Metrics.line)
            .offset(y: -Metrics.line)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
    }
}
