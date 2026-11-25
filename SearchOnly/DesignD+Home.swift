import SwiftUI

// 「极简」的原生搜索首页。规范和小部件见 DesignD.swift

extension DesignD {
    /// 原生搜索首页：左右都对着屏幕正中间那一条竖线。最上面是一个小小的名字和设置入口；
    /// 搜索框、状态行（「正在打开…」，平时空着）、最近搜索（一块一块的词，一行放几块、每行居中，跟小红书自己的搜索页一个意思）
    /// 合成一摞，放在中间那片空地的正中间：东西不多，不让下面空出一大块（2026-11-16 用户要的）。
    /// 键盘弹起时这一摞跟着挪到键盘上方那片空地的正中间。
    /// 「今天用了多久」只在键盘收着、地方够的时候出现，放在最底下或最上面（见 usageOnTop）；
    /// 推荐设置的提示放在最底下（键盘上面或底栏上面），不跟搜索框抢第一眼。
    /// 带小记号的东西（转圈 + 状态、放大镜 + 占位字）都是记号和字合起来居中
    struct Home: View {
        @ObservedObject var browser: Browser
        @ObservedObject private var usage = UsageTimer.shared
        @State private var query = UIDemo.query
        @FocusState private var focused: Bool
        /// 键盘顶边在屏幕上的位置（还没收到过键盘的消息时是无穷大）、首页底边在屏幕上的位置：
        /// 两个一减就是键盘盖住了首页多高。
        /// App 的骨架让整个界面不躲键盘（底栏要留在原地），所以首页得自己把下面的东西收到键盘上面
        @State private var keyboardTop = CGFloat.infinity
        @State private var bottomEdge: CGFloat = 0
        /// 一打开键盘就会弹，所以键盘的消息还没来时先当它弹着，免得先按「没键盘」摆一遍再缩回去
        @State private var expectsKeyboard = true
        /// 最近搜索那些词块全摆开有多高（量出来的）：放得下就全摆开，放不下就只露整行、其余滚着看
        @State private var chipsHeight: CGFloat = 0

        private var keyboardUp: Bool { keyboardTop == .infinity ? expectsKeyboard : keyboardTop < bottomEdge }

        /// 「今天用了多久」放最上面（名字下面）还是最底下（提示上面）。两种都做了让用户比一比；
        /// 调试时可以用启动参数 `-xso.dUsageOnTop YES` 换到上面
        private static let usageOnTop = UserDefaults.standard.bool(forKey: "xso.dUsageOnTop")

        var body: some View {
            // 外面套一层「给多大就多大」的壳，里面的内容按「总高度 − 键盘盖住的高度」排。
            // 不能直接在底下垫一块留白：那样首页会变得比键盘上方的空当还高，整个界面被顶到状态栏底下
            GeometryReader { geo in
                // 键盘收着、整页够高（放得下搜索那一摞再加一个表盘）才放；放底下时还要等提示看过了，免得底下挤着两样
                let showsUsage = !keyboardUp && geo.size.height >= Metrics.usageRoom * 3
                    && (Self.usageOnTop || browser.recommendationTipDone)
                VStack(spacing: 0) {
                    topBar
                    if Self.usageOnTop && showsUsage {
                        usageReadout
                            .padding(.top, Metrics.space8)
                            .transition(.opacity)
                    }
                    GeometryReader { area in
                        middle(available: area.size.height)
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // 上下左右都居中
                    }
                    if !Self.usageOnTop && showsUsage {
                        usageReadout
                            .padding(.bottom, Metrics.space28)
                            .transition(.opacity)
                    }
                    if !browser.recommendationTipDone {
                        RecommendationTip(browser: browser, compact: keyboardUp) { focused = false }
                            .padding(.horizontal, Metrics.boxInset)
                            .padding(.bottom, Metrics.boxInset)
                    }
                }
                .frame(maxWidth: Metrics.maxWidth)
                .frame(maxWidth: .infinity)
                .frame(height: max(0, geo.size.height - max(0, bottomEdge - keyboardTop)))
                .contentShape(Rectangle())
                .onTapGesture { focused = false } // 点空白处收起键盘，露出底栏
            }
            .background(Palette.background.ignoresSafeArea())
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { bottomEdge = $0 }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                // 跟着键盘一起动：这条曲线和系统键盘升降的节奏基本一致
                withAnimation(.interpolatingSpring(mass: 3, stiffness: 1000, damping: 500, initialVelocity: 0)) {
                    keyboardTop = frame.minY
                }
            }
            .animation(.quick, value: browser.recentSearches)
            .animation(.quick, value: browser.recommendationTipDone)
            .animation(.quick, value: keyboardUp)
            .onAppear {
                focused = true
                #if DEBUG
                mark("native search home shown")
                #endif
            }
            .onChange(of: browser.focusRequest) { focused = true }
            .onChange(of: focused) {
                // 焦点没了（用户自己收了键盘、提醒盖上来了），就不用再等键盘
                if !focused { withAnimation(.quick) { expectsKeyboard = false } }
            }
            .task {
                // 万一键盘一直没弹出来（比如接着外接键盘），过一会儿就按「没键盘」摆。
                // 等得宽一点：冷启动时网页也在加载，键盘可能慢
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.quick) { expectsKeyboard = false }
            }
        }

        // MARK: 顶上：名字和设置

        /// 名字在正中间，设置的齿轮顶着右边线
        private var topBar: some View {
            Text("只搜")
                .font(Typo.smallMedium)
                .foregroundStyle(Palette.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.touch)
                .overlay(alignment: .trailing) {
                    Button { browser.showsSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(Typo.iconMedium)
                            .foregroundStyle(Palette.ink)
                            .frame(width: Metrics.touch, height: Metrics.touch, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(Press())
                    .accessibilityLabel("设置")
                }
                .overlay(alignment: .leading) {
                    // 朋友发来的笔记怎么在只搜里打开：写在首页上，不然没人知道有这个功能（2026-11-23）。顶着左边线，和齿轮对称
                    Button { browser.showsLinkGuide = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link").font(Typo.iconSmall)
                            Text("打开链接").font(Typo.small)
                        }
                        .foregroundStyle(Palette.ink)
                        .frame(height: Metrics.touch)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(Press())
                    .accessibilityHint("看怎么打开朋友发来的小红书笔记")
                }
                .padding(.horizontal, Metrics.gutter)
        }

        // MARK: 中间那一摞：搜索框、状态行、最近搜索

        /// available 是名字（或表盘）下面、表盘（或提示、键盘、底栏）上面空着的高度。
        /// 一摞的高度按内容来，最近搜索太多放不下时只露整行、其余滚着看，一摞永远不比空地高
        private func middle(available: CGFloat) -> some View {
            let terms = browser.recentSearches
            let fixed = Metrics.control + Metrics.header // 搜索框 + 状态那一行
            // 词块一行连空隙正好是 touch 那么高；放不下时只露整行，不露半行
            let rows = max(1, Int((available - fixed - Metrics.header + Metrics.chipGap) / Metrics.touch))
            let fits = CGFloat(rows) * Metrics.touch - Metrics.chipGap
            // 还没量到实际高度的那一下，先按放得下的高度摆
            let listHeight = chipsHeight > 0 ? min(chipsHeight, fits) : fits
            return VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, Metrics.boxInset)
                statusRow
                if !terms.isEmpty {
                    recent(terms, height: listHeight)
                }
            }
        }

        /// 细细的大数字，像表盘：小字「今天」压在上面，单位垫在下面，设了上限再加一排刻度。
        /// 跟提醒页那个大数字是同一个排法
        private var usageReadout: some View {
            let limit = usage.limitMinutes
            return VStack(spacing: Metrics.space12) {
                UsageDial(minutes: usage.todayMinutes, size: .medium) {
                    if limit > 0 {
                        Text("/ \(Text(verbatim: String(limit)).font(Typo.monoSmall)) 分钟")
                    } else {
                        Text("分钟")
                    }
                }
                if limit > 0 {
                    TickBar(fraction: Double(usage.todayMinutes) / Double(limit))
                        .frame(width: Metrics.usageTicks)
                }
            }
            .accessibilityElement(children: .combine)
        }

        /// 最近搜索：标题一直在，下面的词块能滚；高度只取整行，不会露半行
        private func recent(_ terms: [String], height: CGFloat) -> some View {
            /// 「清空」两个字的宽度（小字是 12pt），和它能点的范围比字宽出来的那一截（左右各这么多）
            let clearWidth: CGFloat = 24
            let reach = (Metrics.touch - clearWidth) / 2
            return VStack(spacing: 0) {
                // 「最近 5」和「清空」并排，合起来居中，中间隔开一档。
                // 「清空」是能点的，用墨色；前面两样只是说明，用灰的
                HStack(spacing: Metrics.space12) {
                    HStack(spacing: Metrics.space4) {
                        Text("最近")
                        Text(verbatim: String(terms.count))
                            .font(Typo.monoLabel)
                    }
                    .foregroundStyle(Palette.secondary)
                    Button { browser.clearRecentSearches() } label: {
                        Text("清空")
                            .foregroundStyle(Palette.ink)
                            .frame(width: Metrics.touch, height: Metrics.touch)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(Press())
                    .accessibilityLabel("清空最近搜索")
                    // 占的位置只算字那么宽：不然这一行会往左偏
                    .padding(.horizontal, -reach)
                }
                .font(Typo.label)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.header)
                // 这一行看着矮，「清空」能点的范围比它高：垫到词块上面，下面多出来的那一点才点得到
                .zIndex(1)
                // 最新的排在最前面（左上），跟小红书一样；词多了往下滚着看旧的
                ScrollView {
                    CenteredFlow {
                        ForEach(terms, id: \.self) { term in
                            chip(term)
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chipsHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .frame(height: height)
            }
        }

        /// 一块词：细细的灰线框，墨色的字，框跟字一样贴身。
        /// 不用墨色线框：一屏好几块墨框会跟上面的搜索框抢；也不垫底色，免得一块块像按钮堆。
        /// 词太长就从中间截断，最宽到一整行
        private func chip(_ term: String) -> some View {
            let shape = RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
            return Button {
                query = term
                browser.search(term)
            } label: {
                Text(term)
                    .font(Typo.body)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, Metrics.space12)
                    .frame(height: Metrics.inner)
                    .overlay { shape.strokeBorder(Palette.stroke, lineWidth: Metrics.line) }
                    // 块看着矮，能点的范围上下各多出半个空隙，一行正好是 touch 那么高
                    .contentShape(Rectangle().inset(by: -Metrics.chipGap / 2))
            }
            .buttonStyle(ChipPress(shape: shape))
        }

        // MARK: 搜索框下面那一行：平时空着，忙的时候显示状态（「封面先模糊」这类开关都在设置里）

        private var statusRow: some View {
            let stalled = browser.searchStalled && !browser.isSearching
            // 「正在打开…」只有几秒；「加载有点慢」会留到下一次搜索开始（或搜索页打开）
            // 平时这一行空着、高度照留：「正在打开…」出来时下面的最近搜索不会跳
            return Color.clear
            .overlay {
                if browser.isSearching {
                    HStack(spacing: Metrics.markGap) {
                        BusyMark()
                        Text("正在打开…")
                    }
                    .foregroundStyle(Palette.secondary)
                    .transition(.opacity)
                } else if stalled {
                    Text("加载有点慢，再搜一次试试")
                        .foregroundStyle(Palette.ink)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .font(Typo.small)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.header) // 比能点的东西矮一档：平时空着，搜索框和最近搜索之间不留太大的缝
            .animation(.quick, value: browser.isSearching)
            .animation(.quick, value: browser.searchStalled)
        }

        // MARK: 搜索框

        private var hasText: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

        /// 搜索框：左右各一格（一样宽），字在两格中间，所以字永远对着屏幕正中间。
        /// 空着的时候两格都空，中间是放大镜带着占位字；打了字，放大镜让开，左边一格是清除、右边一格是提交
        private var searchBar: some View {
            let shape = RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            return HStack(spacing: 0) {
                slot {
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark")
                                .font(Typo.iconSmall)
                                .foregroundStyle(Palette.secondary)
                                .frame(width: Metrics.touch, height: Metrics.control)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(Press())
                        .accessibilityLabel("清除")
                        .transition(.opacity)
                    }
                }
                HStack(spacing: Metrics.markGap) {
                    if query.isEmpty {
                        Image(systemName: "magnifyingglass")
                            .font(Typo.iconMedium)
                            .foregroundStyle(Palette.ink)
                    }
                    field
                }
                .frame(maxWidth: .infinity)
                // 字很长的时候别顶着两头的按钮
                .padding(.horizontal, Metrics.space4)
                slot {
                    if hasText {
                        Button(action: submit) {
                            Image(systemName: "arrow.right")
                                .font(Typo.iconMedium)
                                .foregroundStyle(Palette.onInk)
                                .frame(width: Metrics.inner, height: Metrics.inner)
                                .background(Palette.ink, in: RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous))
                                .frame(width: Metrics.touch, height: Metrics.control)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(Press())
                        .accessibilityLabel("搜索")
                        .transition(.opacity)
                    } else if focused {
                        // 不想搜了：点「取消」收起键盘（还没打字时才有；打了字这一格是提交，点空白处也能收）
                        Button { focused = false } label: {
                            Text("取消")
                                .font(Typo.small)
                                .foregroundStyle(Palette.secondary)
                                .fixedSize()
                                .frame(width: Metrics.touch, height: Metrics.control)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(Press())
                        .transition(.opacity)
                    }
                }
            }
            // 提交按钮那块墨色离搜索框的上、下、右三边一样远
            .padding(.horizontal, (Metrics.control - Metrics.inner) / 2 - (Metrics.touch - Metrics.inner) / 2)
            .frame(height: Metrics.control)
            .background(Palette.background, in: shape)
            .overlay { shape.strokeBorder(Palette.ink, lineWidth: Metrics.line) }
            .contentShape(shape)
            .onTapGesture { focused = true } // 点在框上任何地方都是要打字
            .animation(.quick, value: hasText)
            .animation(.quick, value: focused)
        }

        /// 搜索框两头的格子：有没有按钮都占一样的位置
        private func slot(@ViewBuilder content: () -> some View) -> some View {
            Color.clear
                .frame(width: Metrics.touch, height: Metrics.control)
                .overlay { content() }
        }

        /// 输入的地方。打了字以后它占满两格中间，字在里面居中（居中、字太长时怎么滚都交给系统的输入框）。
        /// 空着的时候不能这样：居中的输入框会把光标劈在占位字正中间。
        /// 所以空着时它只有占位字那么宽（宽度是垫在底下那行看不见的字量出来的）、字靠左：
        /// 光标停在占位字前面，放大镜、光标、占位字合起来居中
        private var field: some View {
            let empty = query.isEmpty
            return Text(Self.prompt)
                .font(Typo.input)
                .lineLimit(1)
                .hidden()
                .frame(maxWidth: empty ? nil : .infinity)
                .overlay {
                    TextField("", text: $query, prompt: Text(Self.prompt).foregroundStyle(Palette.secondary))
                        .font(Typo.input)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(empty ? .leading : .center)
                        .tint(Palette.mark) // 红色的光标：整个界面唯一的颜色
                        .submitLabel(.search)
                        .focused($focused)
                        .onSubmit(submit)
                        // 空着时输入框比占位字往右多出一点（不算进宽度）：免得占位字正好卡着边、被截掉一截
                        .padding(.trailing, empty ? -Metrics.space4 : 0)
                }
        }

        private static let prompt = "搜索小红书"

        private func submit() { browser.search(query) }
    }

    /// 词块按下去：框里垫一层浅灰，跟整行能点的东西按下去一个样子
    private struct ChipPress<S: Shape>: ButtonStyle {
        let shape: S

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(configuration.isPressed ? Palette.fill : .clear, in: shape)
        }
    }

    /// 网友建议：在小红书设置里关掉个性化推荐，推荐流就变得很无聊，连官方 app 也不想刷了。
    /// 这是帐号级的设置，只能用户自己去关，这里只提示一次。
    /// 键盘弹着时地方小，缩成矮矮的一行、字也轻一档，不跟上面的搜索框抢；点一下收起键盘，整段和两个按钮就出来了。
    /// 里面的字跟首页别的东西一样居中；正文自己断成三行，免得最后一行只剩两三个字
    struct RecommendationTip: View {
        @ObservedObject var browser: Browser
        let compact: Bool
        let expand: () -> Void

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            VStack(spacing: 0) {
                Text("再进一步：关掉「个性化推荐」")
                    .font(compact ? Typo.small : Typo.bodyMedium)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? Metrics.inner : Metrics.touch)
                    .overlay(alignment: .trailing) {
                        if compact {
                            Image(systemName: "chevron.down")
                                .font(Typo.iconSmall)
                                .foregroundStyle(Palette.secondary)
                        }
                    }
                if !compact {
                    Text("在小红书 app 的「设置 → 隐私设置」里关掉它\n（位置可能因版本略有不同）\n推荐流会变得平淡，连官方 app 也不太想刷了。")
                        .font(Typo.small)
                        .foregroundStyle(Palette.secondary)
                        .lineSpacing(Metrics.lineSpacing)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Metrics.space8) {
                        Button {
                            if let url = URL(string: "xhsdiscover://") { UIApplication.shared.open(url) }
                        } label: {
                            action("打开小红书", color: Palette.ink)
                        }
                        Button { browser.recommendationTipDone = true } label: {
                            action("知道了", color: Palette.secondary)
                        }
                    }
                    .buttonStyle(Press())
                    .padding(.top, Metrics.space2)
                }
            }
            .padding(.horizontal, Metrics.boxPadding)
            .frame(maxWidth: .infinity)
            .background(Palette.background, in: shape)
            .overlay { shape.strokeBorder(Palette.stroke, lineWidth: Metrics.line) }
            // 收起来时看着矮，能点的范围上下各多出一点
            .contentShape(compact ? AnyShape(Rectangle().inset(by: (Metrics.inner - Metrics.touch) / 2)) : AnyShape(shape))
            .onTapGesture { if compact { expand() } }
            .accessibilityAddTraits(compact ? .isButton : [])
        }

        private func action(_ title: String, color: Color) -> some View {
            Text(title)
                .font(Typo.smallMedium)
                .foregroundStyle(color)
                .padding(.horizontal, Metrics.space8)
                .frame(minWidth: Metrics.touch)
                .frame(height: Metrics.touch)
                .contentShape(Rectangle())
        }
    }
}
