import SwiftUI

// 界面风格「原味」：跟小红书一个路子——白底、浅灰实心的搜索框、只有文字的底栏、一点红。
// 颜色、字号、圆角和小部件见 DesignA+Theme.swift；搜索页顶栏和网页配色见 DesignA+Web.swift；一共哪几块界面见 UIStyle.swift

enum DesignA {}

extension DesignA {
    /// 整页加载时网页顶上的细进度条：小红书的页面要先白一会儿才画出来，有它就知道是在加载、不是卡住了
    struct LoadingBar: View {
        let progress: Double

        var body: some View {
            GeometryReader { geo in
                // 左头平贴屏幕边，只有往前走的那一头是圆的
                UnevenRoundedRectangle(bottomTrailingRadius: Theme.loadingHeight / 2, topTrailingRadius: Theme.loadingHeight / 2)
                    .fill(Theme.brand)
                    .frame(width: geo.size.width * progress)
                    .animation(Theme.animation, value: progress)
            }
            .frame(height: Theme.loadingHeight)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
    }

    /// 用到每日上限时盖在最上面的提醒卡：语气平和，不说教，一个主要按钮
    struct UsageReminder: View {
        @ObservedObject var usage: UsageTimer
        let openSettings: () -> Void

        var body: some View {
            ZStack {
                Theme.scrim.ignoresSafeArea()
                VStack(spacing: 0) {
                    Image(systemName: "hourglass")
                        .font(.system(size: Theme.iconLarge, weight: .medium))
                        .foregroundStyle(Theme.brand)
                        .frame(width: 56, height: 56)
                        .background(Theme.brandSoft, in: Circle())
                    Text("今天已经用了 \(usage.todayMinutes) 分钟")
                        .font(.system(size: Theme.sizeTitle, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 16)
                    Text("到了你设的 \(usage.limitMinutes) 分钟。找到想要的了吗？")
                        .font(.system(size: Theme.sizeBody))
                        .foregroundStyle(Theme.textBody)
                        .multilineTextAlignment(.center)
                        .lineSpacing(Theme.lineSpacing)
                        .padding(.top, 8)
                    Text("之后每多用 10 分钟会再提醒一次")
                        .font(.system(size: Theme.sizeCaption))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                    Button("知道了") { usage.alertShown = false }
                        .buttonStyle(PillButtonStyle())
                        .padding(.top, 24)
                    Button {
                        usage.alertShown = false
                        openSettings()
                    } label: {
                        Text("调整提醒时间")
                            .font(.system(size: Theme.sizeBody))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.controlHeight)
                    }
                    .buttonStyle(TapStyle())
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 8) // 下面那个文字按钮自己有 44 高，卡片底下少留一点
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
                // 跟扫码提示一样描一圈细线：深色模式下后面压暗的首页跟卡片差不多深，靠它分出边
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: Theme.hairlineWidth))
                .frame(maxWidth: Theme.reminderWidth)
                .padding(.horizontal, 32)
            }
            // 键盘别盖住提醒卡
            .onAppear { hideKeyboard() }
        }
    }

    /// 登录要扫码时浮在登录页顶部的帮忙提示（逻辑见 LoginHelp.swift）
    struct LoginBanner: View {
        @ObservedObject var browser: Browser

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: Theme.sizeHeadline, weight: .medium))
                        .foregroundStyle(Theme.brand)
                    Text("需要扫码确认登录")
                        .font(.system(size: Theme.sizeHeadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button {
                        browser.loginHelpDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: Theme.iconSmall, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Theme.surfaceFill, in: Circle())
                    }
                    .buttonStyle(TapStyle(horizontal: 8, vertical: 8))
                    .accessibilityLabel("关闭")
                }
                // 标题行按文字的高度算，关闭按钮比文字高出来的部分不占地方
                .frame(height: 24)
                Text(browser.loginHelpMessage)
                    .font(.system(size: Theme.sizeBody))
                    .foregroundStyle(Theme.textBody)
                    .lineSpacing(Theme.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                // 只有红色这一个鲜艳颜色：小红书那个是红的，微信那个用浅灰的次要按钮，不铺微信绿
                HStack(spacing: 12) {
                    scanButton(.weChat, secondary: true)
                    scanButton(.xiaohongshu)
                }
                .padding(.top, 16)
            }
            .padding(Theme.cardPadding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
            // 深色模式下投影看不见，靠这圈细线跟网页分开
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: Theme.hairlineWidth))
            // 先合成一整块再投影：不然卡片里的字和按钮各投各的影子，卡面会发灰
            .compositingGroup()
            .shadow(color: Theme.shadow, radius: Theme.shadowRadius, y: Theme.shadowY)
            .frame(maxWidth: Theme.contentMaxWidth)
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
        }

        private func scanButton(_ app: ScanApp, secondary: Bool = false) -> some View {
            Button("用\(app.name)确认") {
                Task { await browser.saveLoginQR(andOpen: app) }
            }
            .buttonStyle(PillButtonStyle(secondary: secondary))
        }
    }

    /// 原生搜索首页：只有一个主角——搜索框。字标和一句话在上面，下面是最近搜索（「封面先模糊」这类开关都在设置里），
    /// 全都沿着屏幕中线居中排；设置收进右上角。打开 app 立刻就有，不用等网页；网页在底下照常加载。
    /// 键盘几乎一直弹着，所以内容从上往下排、放在可滚动的区域里，不会被挤到状态栏底下
    struct Home: View {
        @ObservedObject var browser: Browser
        @ObservedObject private var usage = UsageTimer.shared
        @State private var query = UIDemo.query
        @FocusState private var focused: Bool
        /// 键盘上沿在屏幕上的位置（KeyboardTop 量的）。键盘收着时是下面可滚动那一块的底边；刚打开还没量到时先当它在屏幕外面
        @State private var keyboardTop = CGFloat.infinity
        /// 搜索那一块（字标到最近搜索）和提示卡各有多高：量出来，用来算提示卡在键盘上面露不露得全
        @State private var mainHeight: CGFloat = 0
        @State private var tipHeight: CGFloat = 0

        /// 齿轮画出来有多宽（iconMedium 这个大小时）
        private static let gearWidth: CGFloat = 17
        /// 搜索那一块和提示卡之间隔多远
        private static let tipGap: CGFloat = 32
        /// 提示卡下面至少要留出这么多才算露得全；露不全时排到键盘上沿下面这么远
        private static let tipMargin: CGFloat = 16
        /// 提示卡折到键盘后面时，原地那一行入口和上面的小标签隔多远
        private static let hintGap: CGFloat = 8
        /// 底部「今天用了多久」那一块大约多高（含上下留白）：搜索那一块下面空得出这么多才放
        private static let usageRoom: CGFloat = 160

        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    // 朋友发来的笔记怎么在只搜里打开：写在首页上，不然没人知道有这个功能（2026-11-23）。左边跟搜索框的左边缘对齐
                    Button { browser.showsLinkGuide = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: Theme.iconMedium, weight: .medium))
                            Text("打开链接")
                                .font(.system(size: Theme.sizeCaption, weight: .medium))
                        }
                        .foregroundStyle(Theme.textBody)
                        .frame(height: Theme.controlHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TapStyle())
                    .accessibilityHint("看怎么打开朋友发来的小红书笔记")
                    .padding(.leading, Theme.gutter)
                    Spacer()
                    Button { browser.showsSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: Theme.iconMedium, weight: .medium))
                            .foregroundStyle(Theme.textBody)
                            .frame(width: Theme.controlHeight, height: Theme.controlHeight)
                    }
                    .buttonStyle(TapStyle())
                    .accessibilityLabel("设置")
                }
                // 齿轮的右边缘跟搜索框的右边缘对齐：齿轮在 44 见方的可点范围正中，两边各空出一截，往右让出这一截
                .padding(.trailing, Theme.gutter - (Theme.controlHeight - Self.gearWidth) / 2)

                GeometryReader { geo in
                    // 键盘盖住了这一块底下多少，上面看得见的还剩多高
                    let covered = max(geo.frame(in: .global).maxY - keyboardTop, 0)
                    let viewport = max(geo.size.height - covered, 0)
                    // 键盘弹着、提示卡在键盘上面露不全：整张排到键盘后面（往上滑能看到），原地留一行入口，
                    // 免得只在键盘上沿露出一条边。键盘收着时不这样，内容多了就照常往下滑
                    let folded = !browser.recommendationTipDone && covered > 0
                        && mainHeight + Self.tipGap + tipHeight + Self.tipMargin > viewport
                    // 折叠时提示卡排在搜索那一块下面多远：正好让卡片的上沿落在键盘上沿以下 tipMargin
                    let tipTop = folded ? max(viewport + Self.tipMargin - mainHeight, Self.tipGap) : Self.tipGap
                    ScrollView {
                        VStack(spacing: 0) {
                            VStack(spacing: 0) {
                                header
                                    .padding(.top, 32)
                                searchBar
                                    .padding(.top, 24)
                                if !browser.recentSearches.isEmpty {
                                    recent.padding(.top, 32)
                                }
                            }
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { mainHeight = $0 }
                            // 入口那一行挂在这一块的底边外面，不占排版的位置：卡片滑上来以后，中间不会多空出一行
                            .overlay(alignment: .bottom) {
                                if folded {
                                    // 往下挪出去的距离：间隔 + 这一行自己的高度
                                    let below = Self.hintGap + Theme.controlHeight
                                    tipHint
                                        .modifier(FadesAsCardAppears(keyboardTop: keyboardTop, cardBelow: tipTop - below, margin: Self.tipMargin))
                                        .offset(y: below)
                                }
                            }
                            if !browser.recommendationTipDone {
                                RecommendationTip(browser: browser)
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tipHeight = $0 }
                                    .padding(.top, tipTop)
                            }
                        }
                        .padding(.horizontal, Theme.gutter)
                        .padding(.bottom, 24)
                        .frame(maxWidth: Theme.contentMaxWidth)
                        // 内容再少也铺满看得见的区域：点哪块空白都能收起键盘
                        .frame(maxWidth: .infinity, minHeight: viewport, alignment: .top)
                        .contentShape(Rectangle())
                        .onTapGesture { focused = false } // 点空白处收起键盘，露出底栏
                        // 手指拖着收键盘、拖到提示卡排得下的那一刻：卡片滑到位，不是一下跳过去
                        .animation(Theme.animation, value: folded)
                    }
                    // 底栏不跟着键盘动，系统不会替这里让出键盘的位置（实测）：键盘盖住多少就垫多少，
                    // 滑到底时最后一样东西正好停在键盘上面
                    .contentMargins(.bottom, covered, for: .scrollContent)
                    .scrollDismissesKeyboard(.interactively)
                    .scrollBounceBehavior(.basedOnSize)
                    // iOS 26 的键盘是半透明的，后面有东西会透出一团影子：键盘上沿以下的一律不画
                    .mask(alignment: .top) { Rectangle().frame(height: viewport) }
                    // 今天用了多久：放在最底下（2026-11-22 用户要的，跟「极简」一样）。键盘收着、提示卡看过了、
                    // 搜索那一块下面空得出地方才放，不跟搜索框和最近搜索挤
                    .overlay(alignment: .bottom) {
                        if !focused && covered == 0 && browser.recommendationTipDone && mainHeight + Self.usageRoom < viewport {
                            usageReadout
                                .padding(.bottom, 28)
                                .transition(.opacity)
                        }
                    }
                    .animation(Theme.animation, value: focused)
                    .background {
                        KeyboardTop { top, animated in
                            // 键盘自己弹出、收起时这里跟着用动画变；跟着手指走的时候一点点跟，不加动画，免得慢半拍
                            withTransaction(Transaction(animation: animated ? Theme.animation : nil)) { keyboardTop = top }
                        }
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .animation(Theme.animation, value: browser.recentSearches)
            .animation(Theme.animation, value: browser.recommendationTipDone)
            .onAppear {
                focused = true
                #if DEBUG
                mark("native search home shown")
                #endif
            }
            .onChange(of: browser.focusRequest) { focused = true }
        }

        /// 首页底部的「今天用了多久」：小字「今天」、大数字、单位；设了每日提醒再加一条红色进度（和设置页里那条一样）
        private var usageReadout: some View {
            let limit = usage.limitMinutes
            return VStack(spacing: 4) {
                Text("今天")
                    .font(.system(size: Theme.sizeCaption))
                    .foregroundStyle(Theme.textSecondary)
                Text(verbatim: String(usage.todayMinutes)) // 数字不走本地化：上千以后中间不多一个分隔符
                    .font(.system(size: Theme.sizeDisplay, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text(limit > 0 ? "/ \(limit) 分钟" : "分钟")
                    .font(.system(size: Theme.sizeCaption))
                    .foregroundStyle(Theme.textSecondary)
                if limit > 0 {
                    let fraction = min(Double(usage.todayMinutes) / Double(limit), 1)
                    Capsule().fill(Theme.fill)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Theme.brand).frame(width: max(120 * fraction, Theme.progressHeight))
                        }
                        .frame(width: 120, height: Theme.progressHeight)
                        .padding(.top, 8)
                }
            }
            .animation(Theme.animation, value: usage.todayMinutes)
            .accessibilityElement(children: .combine)
        }

        /// 提示卡被键盘挡着时原地留的一行：点一下收起键盘，整张卡片就露出来。
        /// 旁白不读它：卡片本身就排在后面，读得到，不用把同一句标题读两遍
        private var tipHint: some View {
            Button { focused = false } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: Theme.sizeBody, weight: .medium))
                        .foregroundStyle(Theme.brand)
                    Text("再进一步：关掉「个性化推荐」")
                        .font(.system(size: Theme.sizeBody))
                        .foregroundStyle(Theme.textBody)
                    Image(systemName: "chevron.down")
                        .font(.system(size: Theme.iconSmall, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(height: Theme.controlHeight)
            }
            .buttonStyle(TapStyle())
            .accessibilityHidden(true)
        }

        private var header: some View {
            VStack(spacing: 8) {
                // 设计稿用的是小红书的字标；自己用没问题，以后上架要换成自己的名字
                Text("小红书")
                    .font(.system(size: Theme.sizeDisplay, weight: .heavy))
                    .foregroundStyle(Theme.brand)
                HStack(spacing: 8) {
                    // 字号是固定的，转圈也固定大小，不跟着系统的大字号变大
                    if browser.isSearching { ProgressView().controlSize(.mini).dynamicTypeSize(.large) }
                    Text(status)
                }
                .font(.system(size: Theme.sizeBody))
                .foregroundStyle(Theme.textSecondary)
                .animation(Theme.animation, value: status)
            }
        }

        private var status: String {
            if browser.isSearching { return "正在打开…" }
            if browser.searchStalled { return "加载有点慢，再搜一次试试" }
            return "想找什么，直接搜"
        }

        private var searchBar: some View {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: Theme.sizeHeadline, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    TextField("", text: $query, prompt: Text("搜索笔记、地点、好物").foregroundStyle(Theme.textPlaceholder))
                        .font(.system(size: Theme.sizeHeadline))
                        .foregroundStyle(Theme.textPrimary)
                        .submitLabel(.search)
                        .focused($focused)
                        .onSubmit(submit)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: Theme.sizeHeadline))
                                .foregroundStyle(Theme.textPlaceholder)
                        }
                        .buttonStyle(TapStyle(horizontal: 16, vertical: 16))
                        .accessibilityLabel("清除")
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: Theme.controlHeight)
                .background(Theme.fill, in: Capsule())
                // 整个胶囊（连放大镜和四周的留白）点了都开始输入，不用对准那一行字
                .contentShape(Capsule())
                .onTapGesture { focused = true }
                if canSubmit {
                    Button("搜索", action: submit)
                        .font(.system(size: Theme.sizeHeadline, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                        .buttonStyle(TapStyle(horizontal: 12, vertical: 16))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else if focused {
                    // 不想搜了：点「取消」收起键盘（还没打字时才有；打了字这个位置是「搜索」，点空白处也能收）
                    Button("取消") { focused = false }
                        .font(.system(size: Theme.sizeHeadline))
                        .foregroundStyle(Theme.textBody)
                        .buttonStyle(TapStyle(horizontal: 12, vertical: 16))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .tint(Theme.brand)
            .animation(Theme.animation, value: query.isEmpty)
            .animation(Theme.animation, value: canSubmit)
            .animation(Theme.animation, value: focused)
        }

        /// 输入了字（不算空格）才出现「搜索」按钮
        private var canSubmit: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

        private var recent: some View {
            VStack(spacing: 12) {
                // 小标题在正中间，垃圾桶紧跟在它右边；左边垫一个看不见的同样大的，标题才不会被挤偏
                HStack(spacing: 8) {
                    trash.hidden()
                    Text("最近搜索")
                        .font(.system(size: Theme.sizeBody, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Button { browser.clearRecentSearches() } label: { trash }
                        .buttonStyle(TapStyle(horizontal: 16, vertical: 16))
                        .accessibilityLabel("清空最近搜索")
                }
                CenteredFlow(spacing: 8) {
                    ForEach(browser.recentSearches, id: \.self) { term in
                        Chip(title: term) {
                            query = term
                            browser.search(term)
                        }
                    }
                }
            }
        }

        private var trash: some View {
            Image(systemName: "trash")
                .font(.system(size: Theme.sizeBody, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }

        private func submit() { browser.search(query) }
    }

    /// 网友建议：在小红书设置里关掉个性化推荐，推荐流就变得很无聊，连官方 app 也不想刷了。
    /// 这是帐号级的设置，只能用户自己去关，这里只提示一次
    struct RecommendationTip: View {
        @ObservedObject var browser: Browser

        var body: some View {
            // 跟首页别的东西一样居中排；说明按句子断成三行，每行都是完整的一句
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: Theme.sizeBody, weight: .medium))
                        .foregroundStyle(Theme.brand)
                    Text("再进一步：关掉「个性化推荐」")
                        .font(.system(size: Theme.sizeBody, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Text("在小红书 app 的「设置 → 隐私设置」里关掉它，\n位置可能因版本略有不同。\n推荐流会变得平淡，连官方 app 也不太想刷了。")
                    .font(.system(size: Theme.sizeCaption))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Theme.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                HStack(spacing: 24) {
                    Button("打开小红书") {
                        if let url = URL(string: "xhsdiscover://") { UIApplication.shared.open(url) }
                    }
                    .font(.system(size: Theme.sizeBody, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                    Button("知道了") { browser.recommendationTipDone = true }
                        .font(.system(size: Theme.sizeBody))
                        .foregroundStyle(Theme.textBody)
                }
                .buttonStyle(TapStyle(horizontal: 12, vertical: 16))
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.cardPadding)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        }
    }

    /// 设置页：首页右上角的齿轮打开。分四组：界面风格、首页、少一点干扰、使用时间。
    /// 不用系统的分组列表，自己排：圆角、留白跟提醒卡这些是同一套，在哪个版本的 iOS 上都是一个样子
    struct SettingsSheet: View {
        @ObservedObject var browser: Browser
        @ObservedObject private var usage = UsageTimer.shared
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            VStack(spacing: 0) {
                ZStack {
                    Text("设置")
                        .font(.system(size: Theme.sizeHeadline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Button("完成") { dismiss() }
                        .font(.system(size: Theme.sizeHeadline, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                        .buttonStyle(TapStyle(horizontal: 16, vertical: 16))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, Theme.gutter + Theme.cardPadding)
                }
                .frame(height: Theme.controlHeight)
                .padding(.top, 16) // 给顶上的小横条让出位置

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            group("界面风格", footer: "四套风格随时可以换，换风格时桌面图标也跟着换。") {
                                ForEach(UIStyle.allCases) { style in
                                    if style != UIStyle.allCases.first { divider(inset: Self.thumbnail) }
                                    styleRow(style)
                                }
                            }
                            group("少一点干扰") {
                                toggle("circle.lefthalf.filled", "灰度模式", "图片和视频都变成黑白", $browser.grayscale)
                                divider(inset: SettingIcon.size)
                                toggle("eye.slash", "封面先模糊", "看标题决定点不点，点进去是清楚的", $browser.blurImages)
                                divider(inset: SettingIcon.size)
                                toggle("play.rectangle", "视频点了才播", "打开视频笔记不会自己开始播放", $browser.tapToPlay)
                            }
                            group("使用时间", footer: "只算 app 开着的时间，每天零点重新算。到点提醒一次，之后每多用 10 分钟再提醒一次。") {
                                usageSummary
                                divider(inset: nil)
                                limitRow
                            }
                            note("只搜是小红书网页版外面的一层壳：不调用私有接口、不抓取数据，也不读取或保存你的账号密码。设置和使用时间只存在这台手机上。")
                                .padding(.top, 24)
                                .id("end")
                        }
                        .padding(.horizontal, Theme.gutter)
                        .padding(.bottom, 24)
                        .frame(maxWidth: Theme.contentMaxWidth)
                        .frame(maxWidth: .infinity)
                    }
                    // 内容滑到标题底下时淡出去，不是齐刷刷被切掉
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [Theme.groupedBackground, Theme.groupedBackground.opacity(0)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 12)
                            .allowsHitTesting(false)
                    }
                    .task {
                        // 截图用：直接滑到底（等排好再滑）
                        guard UIDemo.state == "settings-bottom" else { return }
                        try? await Task.sleep(for: .seconds(0.5))
                        proxy.scrollTo("end", anchor: .bottom)
                    }
                }
            }
            .background(Theme.groupedBackground.ignoresSafeArea())
            .presentationBackground(Theme.groupedBackground)
            .presentationDragIndicator(.visible)
            .onAppear { usage.tick() } // 「今天已用」显示到这一刻
        }

        /// 界面风格那几行前面的图标小图有多大
        private static let thumbnail: CGFloat = 40
        /// 一行里前面的图标和文字隔多远；分隔线从文字开始，也按它算
        private static let rowGap: CGFloat = 12

        /// 一组：小标题 + 一张卡片 + 可有可无的一句说明
        private func group(_ title: String, footer: String? = nil, @ViewBuilder rows: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: Theme.sizeCaption, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Theme.cardPadding)
                VStack(spacing: 0, content: rows)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
                if let footer { note(footer) }
            }
            .padding(.top, 24)
        }

        /// 卡片外面的说明文字
        private func note(_ text: String) -> some View {
            Text(text)
                .font(.system(size: Theme.sizeCaption))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(Theme.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.cardPadding)
        }

        /// 行与行之间的细线：左边从文字开始（让过前面 inset 宽的图标；上面那行没有图标就传 nil），右边到卡片的留白为止
        private func divider(inset: CGFloat?) -> some View {
            Hairline()
                .padding(.leading, Theme.cardPadding + (inset.map { $0 + Self.rowGap } ?? 0))
                .padding(.trailing, Theme.cardPadding)
        }

        /// 一种界面风格：图标小图 + 名字 + 一句话，选中的打勾
        private func styleRow(_ style: UIStyle) -> some View {
            let selected = browser.style == style
            // 小图的圆角按 iOS 桌面图标的比例来
            let shape = RoundedRectangle(cornerRadius: Self.thumbnail * 0.2237, style: .continuous)
            return Button { browser.style = style } label: {
                HStack(spacing: Self.rowGap) {
                    Image(style.previewImage)
                        .resizable()
                        .frame(width: Self.thumbnail, height: Self.thumbnail)
                        .clipShape(shape)
                        .overlay(shape.strokeBorder(Theme.outline, lineWidth: Theme.outlineWidth))
                    VStack(alignment: .leading, spacing: Theme.titleGap) {
                        HStack {
                            Text(style.name)
                                .font(.system(size: Theme.sizeHeadline, weight: selected ? .semibold : .regular))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: Theme.sizeBody, weight: .semibold))
                                    .foregroundStyle(Theme.brand)
                            }
                        }
                        Detail(text: style.summary)
                    }
                }
                .padding(.horizontal, Theme.cardPadding)
                .padding(.vertical, 12)
            }
            .buttonStyle(RowButtonStyle())
            .accessibilityAddTraits(selected ? .isSelected : [])
        }

        private func toggle(_ icon: String, _ title: String, _ detail: String, _ isOn: Binding<Bool>) -> some View {
            Toggle(isOn: isOn) {
                HStack(spacing: Self.rowGap) {
                    SettingIcon(systemImage: icon)
                    VStack(alignment: .leading, spacing: Theme.titleGap) {
                        Text(title)
                            .font(.system(size: Theme.sizeHeadline))
                            .foregroundStyle(Theme.textPrimary)
                        Detail(text: detail)
                    }
                }
            }
            .tint(Theme.brand)
            .padding(.trailing, Self.switchOverhang)
            .padding(.horizontal, Theme.cardPadding)
            .padding(.vertical, 12)
        }

        /// iOS 26 的开关画出来比它占的位置宽，右边多出 2pt；补回来，开关的右边缘才跟分隔线、「完成」对齐
        private static var switchOverhang: CGFloat {
            if #available(iOS 26, *) { 2 } else { 0 }
        }

        /// 今天用了多少：大数字 + 一条进度（没设上限就只显示数字）
        private var usageSummary: some View {
            let limit = usage.limitMinutes
            return VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(usage.todayMinutes)")
                        .font(.system(size: Theme.sizeDisplay, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("分钟")
                        .font(.system(size: Theme.sizeBody))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(limit == 0 ? "今天" : "今天 · 满 \(limit) 分钟提醒")
                        .font(.system(size: Theme.sizeCaption))
                        .foregroundStyle(Theme.textSecondary)
                }
                if limit > 0 {
                    GeometryReader { geo in
                        let fraction = min(Double(usage.todayMinutes) / Double(limit), 1)
                        Capsule().fill(Theme.surfaceFill)
                            .overlay(alignment: .leading) {
                                Capsule().fill(Theme.brand).frame(width: max(geo.size.width * fraction, Theme.progressHeight))
                            }
                    }
                    .frame(height: Theme.progressHeight)
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }

        /// 每日提醒：点右边的时间弹出菜单来选
        private var limitRow: some View {
            HStack(spacing: Self.rowGap) {
                SettingIcon(systemImage: "bell")
                Text("每日提醒")
                    .font(.system(size: Theme.sizeHeadline))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Menu {
                    Picker("每日提醒", selection: $usage.limitMinutes) {
                        ForEach(UsageTimer.limitChoices, id: \.self) { minutes in
                            Text(limitName(minutes)).tag(minutes)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(limitName(usage.limitMinutes))
                            .font(.system(size: Theme.sizeHeadline))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: Theme.iconSmall, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textBody)
                    // 选的是「关」时只有一个字宽，能点的范围也要够 44
                    .frame(minWidth: Theme.controlHeight, minHeight: Theme.controlHeight, alignment: .trailing)
                    .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.vertical, 8)
        }

        private func limitName(_ minutes: Int) -> String {
            minutes == 0 ? "关" : "\(minutes) 分钟"
        }
    }

    /// 底部导航栏：跟小红书 app 一样只有文字，选中的加粗变深，不加别的记号。
    /// 四格等宽，整排往里收一个页面留白：这样两头的空和字与字之间的空差不多大，四个词看着是匀的。
    /// 原生首页和所有网页共用，亮哪一格看当前页面（见 Browser.currentTab）
    struct TabBar: View {
        @ObservedObject var browser: Browser

        var body: some View {
            HStack(spacing: 0) {
                tab("首页", .home) { browser.showSearchHome() }
                tab("问 AI", .ai) { browser.openAIChat() }
                tab("消息", .messages) { browser.openChats() }
                tab("我", .me) { Task { await browser.openProfile() } }
            }
            .padding(.horizontal, Theme.gutter)
            .frame(height: Theme.tabBarHeight)
            .background(Theme.background.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Hairline() }
        }

        private func tab(_ title: String, _ tab: Browser.Tab, action: @escaping () -> Void) -> some View {
            let selected = browser.currentTab == tab
            return Button {
                hideKeyboard()
                action()
            } label: {
                Text(title)
                    .font(.system(size: Theme.sizeHeadline, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(TapStyle())
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    /// 「消息」页顶上的切换：跟小红书 app 顶部的标签一样，文字 + 选中下面一条红色短线。
    /// 小红书 App 的消息页上面是赞和收藏、新增关注、评论和@，下面是私信；网页版把这两块拆成了两个页面
    /// （/chat 和 /notification），这里用切换接起来，两边都走站内跳转
    struct MessagesSwitcher: View {
        @ObservedObject var browser: Browser
        @Namespace private var underline

        private var onChats: Bool { browser.currentPath?.hasPrefix("/chat") == true }

        var body: some View {
            HStack(spacing: 32) {
                item("私信", selected: onChats) { browser.openChats() }
                item("评论和通知", selected: !onChats) { browser.openNotifications() }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Theme.controlHeight)
            .background(Theme.background.ignoresSafeArea(edges: .top))
            .overlay(alignment: .bottom) { Hairline() }
            .animation(Theme.animation, value: onChats)
        }

        private func item(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: Theme.sizeHeadline, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                    .frame(height: Theme.controlHeight)
                    .overlay(alignment: .bottom) {
                        if selected {
                            Capsule()
                                .fill(Theme.brand)
                                .frame(width: Theme.underlineSize.width, height: Theme.underlineSize.height)
                                // 离文字近一点、离底下的分隔线远一点：加载时进度条贴着分隔线走，两条红线不挤在一起
                                .padding(.bottom, 8)
                                .matchedGeometryEffect(id: "underline", in: underline)
                        }
                    }
            }
            // 能点的范围左右各多出半个间隔，两个标签之间不留点不到的缝
            .buttonStyle(TapStyle(horizontal: 16))
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}
