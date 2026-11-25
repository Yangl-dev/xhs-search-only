import SwiftUI

// 界面风格「圆润」：浅灰的底、白色的大圆角卡片、圆里的实心图标，各个开关开没开一眼看到。
// 颜色、字号、尺寸和小部件见 DesignC+Kit.swift；搜索页顶栏和网页配色见 DesignC+Web.swift；一共要提供哪几块界面见 UIStyle.swift

enum DesignC {}

// MARK: - 首页

extension DesignC {
    /// 原生搜索首页：像一个小小的控制中心，整页居中排。最大的一块是搜索卡；下面一块是今天用了多久（开关都在设置里）；
    /// 再下面是最近搜索和只出现一次的提示。键盘几乎一直弹着，所以键盘以上是单独排的一屏：搜索卡、三个小方块、
    /// 收成一排的最近搜索；提示卡在下一屏，往上滑能看到
    struct Home: View {
        @ObservedObject var browser: Browser
        @ObservedObject private var usage = UsageTimer.shared
        @ObservedObject private var keyboard = Keyboard.shared
        @State private var query = UIDemo.query
        @FocusState private var focused: Bool
        /// 首页下沿在屏幕上的位置：用来算键盘盖住了多少
        @State private var bottomEdge: CGFloat = 0
        /// 滚动区有多高
        @State private var scrollHeight: CGFloat = 0

        /// 滚动区最下面被键盘盖住的高度
        private var covered: CGFloat { keyboard.covers(below: bottomEdge) }

        /// 滚动区里键盘以上、真正看得见的那么高（键盘收着时就是一直到底栏上沿）
        private var visibleHeight: CGFloat { max(0, scrollHeight - covered) }

        /// 键盘弹着、又有最近搜索时，键盘以上剩的地方放不下提示卡，只会在键盘边上露出一条。
        /// 这时让上面几块占满键盘以上的一整屏（在这一屏里上下居中），提示卡整张排到下一屏
        private var firstScreen: CGFloat? {
            guard covered > 0, !browser.recommendationTipDone, !browser.recentSearches.isEmpty else { return nil }
            return max(0, visibleHeight - Metrics.gap * 2)
        }

        private var canSubmit: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

        var body: some View {
            ScrollView {
                VStack(spacing: Metrics.gap) {
                    VStack(spacing: Metrics.gap) {
                        topRow
                        searchCard
                        tiles
                        if !browser.recentSearches.isEmpty {
                            recent
                        } else if browser.recommendationTipDone {
                            emptyHint
                        }
                    }
                    .frame(minHeight: firstScreen)
                    if !browser.recommendationTipDone { Tip(browser: browser) }
                }
                .padding(.horizontal, Metrics.gutter)
                // 上下留一样多，整块居中时两头才对得上；留得少一点，键盘弹着时键盘以上也放得下
                .padding(.vertical, Metrics.gap)
                .frame(maxWidth: Metrics.maxWidth)
                .frame(maxWidth: .infinity)
                // 东西不多，整块（字标到最近搜索）在看得见的地方里上下居中：上下的空一样多。
                // 键盘弹着时就在键盘以上居中，整块往上挪；放不下时从顶上排，照常能滑
                .frame(minHeight: visibleHeight)
                // 键盘盖住多少，底下就多垫多少：键盘弹着时也能把最后一块滑到键盘上面来
                .padding(.bottom, covered)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { scrollHeight = $0 }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            // 往上滑时，内容伸进状态栏下面一截再淡出去：渐隐那一截画在滚动区上沿的外面，停着时不会淡掉字标
            .scrollClipDisabled()
            .overlay { EdgeFade(edge: .top).padding(.top, -Metrics.fadeTop) }
            .overlay { EdgeFade(edge: .bottom).padding(.bottom, covered) }
            // 滚动区其实一直铺到底栏上沿，键盘是盖在它上面的；新系统的键盘半透明，底下的红色会透上来一团，
            // 所以被键盘盖住的那一截不画。上头放出渐隐那一截，再往上就不画了
            .mask { Rectangle().padding(.top, -Metrics.fadeTop).padding(.bottom, covered) }
            // 点空白处收起键盘，露出底栏
            .contentShape(Rectangle())
            .onTapGesture { focused = false }
            .background(Palette.canvas.ignoresSafeArea())
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { bottomEdge = $0 }
            .animation(.quick, value: covered)
            .animation(.quick, value: browser.recentSearches)
            .animation(.quick, value: browser.recommendationTipDone)
            .onAppear {
                focused = true
                usage.tick() // 「今天」那一块显示到这一刻
                #if DEBUG
                mark("native search home shown")
                #endif
            }
            .onChange(of: browser.focusRequest) { focused = true }
        }

        /// 顶上一行：字标在正中，圆形的设置按钮在右边（跟卡片右边对齐）。它跟下面的卡片排在一起，一起居中、一起滑。
        /// 下面最近搜索那张卡也是这个排法：名字在正中，圆按钮在右头
        private var topRow: some View {
            HStack(spacing: Space.s8) {
                // 字标写的是「小红书」三个字；自己用没问题，以后上架要换成自己的名字
                Yuan("小红书", size: Typo.display)
                    .foregroundStyle(Palette.red)
                Yuan("只搜", size: Typo.caption)
                    .foregroundStyle(Palette.redText)
                    .padding(.horizontal, Space.s8)
                    .frame(height: Metrics.tag)
                    .background(Palette.tint, in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                Button { browser.showsSettings = true } label: {
                    Disc(systemImage: "gearshape.fill")
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("设置")
                .padding(.trailing, -Metrics.overhang(Metrics.pill)) // 这一行已经在左右留白里面了
            }
            .overlay(alignment: .leading) {
                // 朋友发来的笔记怎么在只搜里打开：写在首页上，不然没人知道有这个功能（2026-11-23）。跟右边的圆按钮一样的白底小块
                Button { browser.showsLinkGuide = true } label: {
                    HStack(spacing: Space.s4) {
                        Image(systemName: "link")
                            .font(.system(size: Metrics.iconSmall, weight: .semibold))
                        Yuan("链接", size: Typo.caption)
                    }
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, Space.s12)
                    .frame(height: Metrics.pill)
                    .background { Capsule().fill(Palette.card).modifier(Lifted(.bar)) }
                    .frame(height: Metrics.touch)
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("打开链接")
                .accessibilityHint("看怎么打开朋友发来的小红书笔记")
            }
            .frame(height: Metrics.topBar)
        }

        /// 搜索卡：一句话（兼着显示「正在打开…」这类状态）+ 输入框，输入框右头是圆形的搜索按钮。里面的东西都居中
        private var searchCard: some View {
            VStack(spacing: Space.s12) {
                HStack(spacing: Space.s8) {
                    if browser.isSearching {
                        ProgressView().controlSize(.small).tint(Palette.red)
                    }
                    Yuan(status, size: Typo.title)
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                // 「取消」挂在这一行的右头、不占位置：一句话照旧在正中，两边让出一样宽免得碰上
                .padding(.horizontal, focused ? Metrics.touch : 0)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    if focused {
                        // 不想搜了：点「取消」收起键盘（点卡片外的空白处、往下滑也能收）
                        Button { focused = false } label: {
                            Text("取消")
                                .font(Typo.plain(Typo.body))
                                .foregroundStyle(Palette.textSecondary)
                                .frame(height: Metrics.touch)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .transition(.opacity)
                    }
                }
                .animation(.quick, value: status)
                .animation(.quick, value: focused)
                field
            }
            .padding(Metrics.pad)
            .frame(maxWidth: .infinity)
            .modifier(Card(radius: Metrics.radiusHero))
            // 点卡片上别的地方也是要打字
            .onTapGesture { focused = true }
        }

        private var status: String {
            if browser.isSearching { return "正在打开…" }
            if browser.searchStalled { return "加载有点慢，再搜一次试试" }
            return "想找什么，直接搜"
        }

        /// 输入框：字在胶囊的正中。右头是搜索按钮，左头空出一样宽；打了字以后清除的小叉挨着搜索按钮，
        /// 字的两边各让出一个小叉的宽度，所以字一直在正中、不会被小叉盖住
        private var field: some View {
            HStack(spacing: 0) {
                TextField("", text: $query, prompt: Text("搜索笔记、地点、好物").foregroundStyle(Palette.textFaint))
                    .font(Typo.plain(Typo.body))
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                    .submitLabel(.search)
                    .focused($focused)
                    .onSubmit(submit)
                    .padding(.horizontal, query.isEmpty ? 0 : Metrics.glyphSmall)
                    .overlay(alignment: .trailing) {
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: Metrics.icon))
                                    .foregroundStyle(Palette.textFaint)
                                    .frame(width: Metrics.glyphSmall, height: Metrics.touch)
                                    .modifier(TouchTarget(visibleWidth: Metrics.glyphSmall, visibleHeight: Metrics.touch))
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("清除")
                        }
                    }
                    .padding(.leading, Metrics.touch)
                Button(action: submit) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: Metrics.icon, weight: .bold))
                        .foregroundStyle(canSubmit ? Color.white : Palette.red)
                        .frame(width: Metrics.touch, height: Metrics.touch)
                        .background {
                            // 没打字时是淡红的，打了字亮成渐变
                            if canSubmit {
                                Circle().fill(Palette.gradient).modifier(Lifted(.glow))
                            } else {
                                Circle().fill(Palette.tint)
                            }
                        }
                }
                .buttonStyle(PressableStyle())
                .disabled(!canSubmit)
                .accessibilityLabel("搜索")
            }
            .padding(.horizontal, Metrics.overhang(Metrics.field) + Space.s12 / 2) // 搜索按钮跟输入框的圆头同心
            .frame(height: Metrics.field)
            .background(Palette.well, in: Capsule())
            .tint(Palette.red)
            .animation(.quick, value: canSubmit)
            .animation(.quick, value: query.isEmpty)
        }

        /// 今天用了多久，占满一行（点它去设置）。「封面先模糊」这类开关原来也在这一排，2026-11-16 起都只放在设置里
        private var tiles: some View {
            usageTile
                .fixedSize(horizontal: false, vertical: true)
        }

        /// 今天用了多久。它不是开关，是去设置的入口：永远是一个圆环（没设每日提醒时是空的一圈），小字后面跟一个小箭头
        private var usageTile: some View {
            let limit = usage.limitMinutes
            return Button { browser.showsSettings = true } label: {
                TileBody(caption: "今天", leadsOn: true) {
                    Ring(fraction: limit > 0 ? Double(usage.todayMinutes) / Double(limit) : 0)
                        .overlay {
                            Image(systemName: "clock.fill")
                                .font(.system(size: Metrics.iconSmall))
                                .foregroundStyle(Palette.icon)
                        }
                } title: {
                    Yuan("\(usage.todayMinutes) 分钟")
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .modifier(Tile())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("今天用了 \(usage.todayMinutes) 分钟，打开设置")
        }

        /// 最近搜索：名字在正中，清空的圆按钮在右头，词一行行居中排。
        /// 键盘收着时一排排不下就换行；键盘弹着时地方只够一排，只放排得下的前几个，后面跟一颗「+N」
        private var recent: some View {
            VStack(spacing: Space.s8) {
                Yuan("最近搜索")
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: Metrics.glyphSmall)
                    .overlay(alignment: .trailing) {
                        Button { browser.clearRecentSearches() } label: {
                            Glyph(systemImage: "trash.fill", size: Metrics.glyphSmall)
                                .frame(width: Metrics.touch, height: Metrics.touch)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("清空最近搜索")
                        .padding(.trailing, -Metrics.overhang(Metrics.glyphSmall)) // 清空按钮的圆跟卡片右边留的白，和上下一样
                    }
                if covered > 0 {
                    recentRow
                } else {
                    CenteredFlow { ForEach(browser.recentSearches, id: \.self) { chip($0) } }
                }
            }
            .padding(Metrics.pad)
            .frame(maxWidth: .infinity)
            .modifier(Card())
        }

        /// 键盘弹着时的那一排：从最新的排起，排得下几个放几个；没放下的收在最后一颗「+N」里，点它收起键盘、全部摊开
        private var recentRow: some View {
            let terms = browser.recentSearches
            return ViewThatFits(in: .horizontal) {
                ForEach((1...max(terms.count, 1)).reversed(), id: \.self) { count in
                    HStack(spacing: Space.s8) {
                        ForEach(terms.prefix(count), id: \.self) { chip($0) }
                        if count < terms.count {
                            Button { focused = false } label: {
                                Text("+\(terms.count - count)")
                                    .font(Typo.digits(Typo.body))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .buttonStyle(PillStyle(kind: .quiet))
                            .accessibilityLabel("还有 \(terms.count - count) 个，收起键盘看全部")
                        }
                    }
                    .fixedSize() // 每颗就是字那么宽，不要撑开去占满一行
                }
            }
        }

        private func chip(_ term: String) -> some View {
            Button {
                query = term
                browser.search(term)
            } label: {
                Text(term)
                    .font(Typo.plain(Typo.body))
                    .lineLimit(1)
                    .frame(maxWidth: Metrics.chipWidth) // 太长的词截断，别把卡片撑破
            }
            .buttonStyle(PillStyle(kind: .quiet))
        }

        /// 还没搜过、提示也关掉了的时候，方块下面不留一片空白：说一句这里以后会有什么
        private var emptyHint: some View {
            VStack(spacing: Space.s8) {
                Glyph(systemImage: "clock.arrow.circlepath", tone: .onCanvas)
                Text("搜过的词会留在这里")
                    .font(Typo.plain())
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Space.s24 - Metrics.gap)
        }

        private func submit() { browser.search(query) }
    }

    /// 小方块里的内容，居中排：上面一个圆（图标或圆环），下面一行名字、一行小字
    struct TileBody<Badge: View, Title: View>: View {
        let caption: String
        var captionColor = Palette.textSecondary
        /// 小字后面跟一个小箭头：这一块点了是去别处，不是开关
        var leadsOn = false
        @ViewBuilder let badge: Badge
        @ViewBuilder let title: Title

        var body: some View {
            VStack(spacing: 0) {
                badge
                title
                    .padding(.top, Space.s8)
                HStack(spacing: Space.s2) {
                    Text(caption)
                        .font(Typo.plain())
                        .foregroundStyle(captionColor)
                    if leadsOn {
                        Image(systemName: "chevron.right")
                            .font(Typo.plain(Typo.small, weight: .semibold))
                            .imageScale(.small)
                            .foregroundStyle(Palette.textFaint)
                    }
                }
                .padding(.top, Space.s2)
            }
            .padding(.horizontal, Metrics.tileSide)
            .padding(.vertical, Metrics.tilePad)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    /// 网友建议：在小红书设置里关掉个性化推荐，推荐流就变得很无聊，连官方 app 也不想刷了。
    /// 这是帐号级的设置，只能用户自己去关，这里只提示一次。跟首页别的卡片一样居中排
    struct Tip: View {
        @ObservedObject var browser: Browser

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: Space.s8) {
                    Glyph(systemImage: "lightbulb.fill", tone: .onTint, size: Metrics.glyphSmall)
                    Yuan("再进一步：关掉「个性化推荐」")
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                // 居中的几行字自己按句子断好行（字里带换行）：让系统断，最后一行会只剩几个字
                Text("在小红书 app 的「设置 → 隐私设置」里关掉它，\n位置可能因版本略有不同。\n推荐流会变平淡，连官方 app 也不太想刷了。")
                    .font(Typo.plain())
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Metrics.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.s8)
                HStack(spacing: Space.s8) {
                    Button {
                        if let url = URL(string: "xhsdiscover://") { UIApplication.shared.open(url) }
                    } label: {
                        Yuan("打开小红书")
                    }
                    .buttonStyle(TipButtonStyle(filled: true))
                    Button { browser.recommendationTipDone = true } label: {
                        // 跟左边那颗一样宽（垫一份看不见的同样的字）：两颗按钮正好分在中线两边
                        Yuan("打开小红书")
                            .hidden()
                            .overlay { Yuan("知道了") }
                    }
                    .buttonStyle(TipButtonStyle(filled: false))
                }
                .padding(.top, Space.s12)
            }
            .padding(Metrics.pad)
            .frame(maxWidth: .infinity)
            .modifier(Card(fill: Palette.tint, elevation: nil))
        }
    }

    /// 提示卡（淡红底）上的两个按钮：一个白底红字，一个只有字
    struct TipButtonStyle: ButtonStyle {
        let filled: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(filled ? Palette.redText : Palette.textSecondary)
                .padding(.horizontal, Space.s16)
                .frame(height: Metrics.pill)
                .background(filled ? Palette.tintGlyph : .clear, in: Capsule())
                .modifier(TouchTarget(visibleHeight: Metrics.pill))
                .opacity(configuration.isPressed ? Metrics.pressedOpacity : 1)
                .animation(.quick, value: configuration.isPressed)
        }
    }
}

// MARK: - 底栏和消息页的切换

extension DesignC {
    /// 底部导航栏：浅灰的底上一颗白色的大胶囊，里面四格实心图标 + 小字，选中的图标坐在一颗淡红的小胶囊里。
    /// 它紧挨着网页，底色跟网页一样（网页也是这套浅灰），所以看上去大胶囊是直接浮在页面上的；
    /// 原生首页和所有网页共用，亮哪一格看当前页面（见 Browser.currentTab）
    struct TabBar: View {
        @ObservedObject var browser: Browser
        @ObservedObject private var keyboard = Keyboard.shared
        /// 底栏上沿在屏幕上的位置
        @State private var topEdge: CGFloat = 0
        /// 屏幕底下有没有留给横条的那一截。没有的手机（带主屏幕按钮的）上，大胶囊自己离屏幕底边留一点
        @State private var hasBottomInset = true

        /// 底栏占的高度：大胶囊加它上面的空
        private static let height = Metrics.chromeGap + Metrics.tabBar

        /// 键盘是不是盖在底栏上。新系统的键盘是半透明的，底栏上的东西会从键盘底下透出来一团一团的，所以键盘盖着时先不画它们
        private var underKeyboard: Bool { keyboard.covers(below: topEdge + Self.height) > Self.height / 2 }

        var body: some View {
            HStack(spacing: 0) {
                tab("首页", "house.fill", .home) { browser.showSearchHome() }
                tab("问 AI", "sparkles", .ai) { browser.openAIChat() }
                tab("消息", "message.fill", .messages) { browser.openChats() }
                tab("我", "person.fill", .me) { Task { await browser.openProfile() } }
            }
            .padding(.horizontal, Space.s8)
            .frame(height: Metrics.tabBar)
            .frame(maxWidth: Metrics.maxWidth)
            .background { Capsule().fill(Palette.card).modifier(Lifted(.tile)) }
            .opacity(underKeyboard ? 0 : 1)
            // 大胶囊的两头跟首页卡片的两条边对齐
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.chromeGap)
            .padding(.bottom, hasBottomInset ? 0 : Metrics.chromeGap)
            .frame(maxWidth: .infinity)
            .background(webSkin.background.color.ignoresSafeArea(edges: .bottom))
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { topEdge = $0 }
            .onGeometryChange(for: Bool.self) { $0.safeAreaInsets.bottom > 0 } action: { hasBottomInset = $0 }
            .animation(.quick, value: underKeyboard)
        }

        private func tab(_ title: String, _ systemImage: String, _ tab: Browser.Tab, action: @escaping () -> Void) -> some View {
            let selected = browser.currentTab == tab
            return Button {
                hideKeyboard()
                action()
            } label: {
                VStack(spacing: Space.s2) {
                    Image(systemName: systemImage)
                        .font(.system(size: Metrics.icon, weight: .semibold))
                        .frame(width: Metrics.tabCapsule.width, height: Metrics.tabCapsule.height)
                        .background(selected ? Palette.tint : .clear, in: Capsule())
                    Text(title)
                        .font(Typo.plain(Typo.small, weight: selected ? .semibold : .medium))
                }
                .foregroundStyle(selected ? Palette.red : Palette.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .animation(.quick, value: selected)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    /// 「消息」页顶上的切换：跟底栏一个做法，浅灰的底上一颗白色的胶囊，选中的那边是一块淡红的滑块、红字。
    /// 小红书 App 的消息页上面是赞和收藏、新增关注、评论和@，下面是私信；网页版把这两块拆成了两个页面
    /// （/chat 和 /notification），这里用切换接起来，两边都走站内跳转
    struct MessagesSwitcher: View {
        @ObservedObject var browser: Browser
        @Namespace private var slider

        private var onChats: Bool { browser.currentPath?.hasPrefix("/chat") == true }

        var body: some View {
            HStack(spacing: 0) {
                segment("私信", selected: onChats) { browser.openChats() }
                segment("评论和通知", selected: !onChats) { browser.openNotifications() }
            }
            .padding(Space.s4)
            .background { Capsule().fill(Palette.card).modifier(Lifted(.bar)) }
            .frame(maxWidth: Metrics.switcherWidth)
            .padding(.horizontal, Metrics.gutter)
            .frame(maxWidth: .infinity)
            .padding(.top, Space.s4)
            .padding(.bottom, Space.s12) // 底下多留一点：加载时进度条就在这下面，离远些才不像哪一格的下划线
            .background(webSkin.background.color.ignoresSafeArea(edges: .top))
            .animation(.snappy(duration: 0.25), value: onChats)
        }

        private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Yuan(title)
                    .foregroundStyle(selected ? Palette.redText : Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Metrics.compact)
                    .background {
                        if selected {
                            Capsule()
                                .fill(Palette.tint)
                                .matchedGeometryEffect(id: "thumb", in: slider)
                        }
                    }
                    .modifier(TouchTarget(visibleHeight: Metrics.compact))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

// MARK: - 设置

extension DesignC {
    /// 设置页：首页右上角的齿轮（或「今天」那一块）打开。灰底上几张大卡片：界面风格、首页、少一点干扰、使用时间
    struct SettingsSheet: View {
        @ObservedObject var browser: Browser
        @ObservedObject private var usage = UsageTimer.shared
        @Environment(\.dismiss) private var dismiss

        /// 标题那一行和第一个小标题之间
        private static let titleGap = Space.s16

        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    Yuan("设置", size: Typo.title)
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Button { dismiss() } label: {
                        Yuan("完成")
                    }
                    .buttonStyle(PillStyle(kind: .soft, height: Metrics.compact))
                }
                .frame(height: Metrics.touch)
                .padding(.leading, Metrics.gutter + Metrics.inset)
                .padding(.trailing, Metrics.gutter)
                .padding(.top, Space.s24)
                .zIndex(1) // 标题这一行画在滚动区的上面

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            header("界面风格", first: true)
                            styleGrid
                            note("四套风格随时可以换。\n换风格时，桌面图标也跟着换。")

                            header("少一点干扰")
                            VStack(spacing: 0) {
                                toggle("circle.lefthalf.filled", "灰度模式", "图片和视频都变成黑白", $browser.grayscale)
                                toggle("eye.slash.fill", "封面先模糊", "看标题决定点不点，点进笔记是清楚的", $browser.blurImages)
                                toggle("play.fill", "视频点了才播", "打开视频笔记不会自己开始播放", $browser.tapToPlay)
                            }
                            .modifier(GroupCard())

                            header("使用时间")
                            usageCard
                            note("只算 app 开着的时间，每天零点重新算。\n到点提醒一次，之后每多用 10 分钟再提醒一次。")

                            privacy
                                .padding(.top, Space.s24)
                                .id("bottom")
                        }
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.top, Metrics.fadeTop)
                        .padding(.bottom, Space.s32)
                        .frame(maxWidth: Metrics.maxWidth)
                        .frame(maxWidth: .infinity)
                    }
                    .overlay { EdgeFade(edge: .top) }
                    .task {
                        // 截图用：直接滑到底（等内容排好再滑）
                        guard UIDemo.state == "settings-bottom" else { return }
                        try? await Task.sleep(for: .seconds(0.5))
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                // 往上伸进标题那一行一点：渐隐从那里开始，内容停着的位置不变
                .padding(.top, Self.titleGap - Metrics.fadeTop)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .presentationBackground(Palette.canvas)
            .presentationCornerRadius(Metrics.radiusSheet)
            .presentationDragIndicator(.visible)
            .onAppear { usage.tick() } // 「今天已用」显示到这一刻
        }

        private func header(_ title: String, first: Bool = false) -> some View {
            Yuan(title, size: Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.leading, Metrics.inset)
                .padding(.top, first ? 0 : Space.s24)
                .padding(.bottom, Space.s8)
        }

        /// 卡片下面的一段说明。在句号后面自己断好行（传进来的字里带换行）：让系统断，会把词从中间劈开
        private func note(_ text: String) -> some View {
            Text(text)
                .font(Typo.plain())
                .foregroundStyle(Palette.textSecondary)
                .lineSpacing(Metrics.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Metrics.inset)
                .padding(.top, Space.s12)
        }

        // MARK: 界面风格

        /// 两个一行；同一行的两块一样高
        private var styleGrid: some View {
            let styles = UIStyle.allCases
            return Grid(horizontalSpacing: Metrics.gap, verticalSpacing: Metrics.gap) {
                ForEach(Array(stride(from: 0, to: styles.count, by: 2)), id: \.self) { start in
                    GridRow {
                        ForEach(styles[start..<min(start + 2, styles.count)]) { style in styleTile(style) }
                    }
                }
            }
        }

        /// 一种界面风格：图标小图 + 名字 + 两行说明，选中的有一圈红边和右上角的勾
        private func styleTile(_ style: UIStyle) -> some View {
            let selected = browser.style == style
            let thumbShape = RoundedRectangle(cornerRadius: Metrics.radiusThumb, style: .continuous)
            return Button { browser.style = style } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Image(style.previewImage)
                            .resizable()
                            .frame(width: Metrics.thumb, height: Metrics.thumb)
                            .clipShape(thumbShape)
                            .overlay(thumbShape.strokeBorder(Palette.thumbEdge, lineWidth: 1))
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: Metrics.iconLarge, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Palette.red : Palette.switchOff)
                    }
                    Yuan(style.name)
                        .foregroundStyle(Palette.text)
                        .padding(.top, Space.s12)
                    VStack(alignment: .leading, spacing: Metrics.lineSpacing) {
                        let lines = summaryLines(style.summary)
                        ForEach(lines, id: \.self) { line in
                            Text(line)
                                .lineLimit(lines.count == 1 ? 2 : 1) // 没有标点可断的说明，让它自己折成两行，别截掉
                                .minimumScaleFactor(0.95)
                        }
                    }
                    .font(Typo.plain(Typo.small))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, Space.s4)
                }
                .padding(.horizontal, Metrics.pad)
                .padding(.vertical, Metrics.tilePad)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .modifier(Tile())
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: Metrics.radiusTile, style: .continuous)
                            .strokeBorder(Palette.red, lineWidth: 2)
                    }
                }
            }
            .buttonStyle(PressableStyle())
            .animation(.quick, value: selected)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }

        /// 说明在第一个冒号或逗号后面断成两行。方块窄，让系统自己断会把词从中间劈开
        private func summaryLines(_ summary: String) -> [String] {
            guard let mark = summary.firstIndex(where: { $0 == "：" || $0 == "，" }) else { return [summary] }
            return [String(summary[...mark]), String(summary[summary.index(after: mark)...])]
        }

        // MARK: 开关

        /// 一行开关：图标圆（开着是淡红圆 + 红图标）+ 名字 + 一句说明；整块的红只在右边的开关上
        private func toggle(_ icon: String, _ title: String, _ detail: String, _ isOn: Binding<Bool>) -> some View {
            Toggle(isOn: isOn) {
                HStack(spacing: Space.s12) {
                    Glyph(systemImage: icon, tone: isOn.wrappedValue ? .soft : .rest)
                    VStack(alignment: .leading, spacing: Space.s2) {
                        Yuan(title)
                            .foregroundStyle(Palette.text)
                        Text(detail)
                            .font(Typo.plain())
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .toggleStyle(SwitchStyle())
            .padding(.vertical, Space.s12)
        }

        // MARK: 使用时间

        /// 今天用了多少：圆环里一个大数字，旁边一句话；下面一排圆选每日提醒的时间
        private var usageCard: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Space.s16) {
                    Dial(minutes: usage.todayMinutes, limit: usage.limitMinutes, size: Metrics.dialSmall)
                    VStack(alignment: .leading, spacing: Space.s4) {
                        Yuan("今天", size: Typo.title)
                            .foregroundStyle(Palette.text)
                        Text(usageLine)
                            .font(Typo.plain())
                            .foregroundStyle(Palette.textSecondary)
                            .lineSpacing(Metrics.lineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                HStack(alignment: .firstTextBaseline) {
                    Yuan("每日提醒")
                        .foregroundStyle(Palette.text)
                    Spacer()
                    // 下面那排数字的单位
                    Yuan("分钟", size: Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.top, Space.s16)
                HStack(spacing: 0) {
                    ForEach(UsageTimer.limitChoices, id: \.self) { minutes in
                        if minutes != UsageTimer.limitChoices.first { Spacer(minLength: 0) }
                        limitOption(minutes)
                    }
                }
                .padding(.top, Space.s8)
            }
            .padding(Metrics.pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(Card())
        }

        private var usageLine: String {
            let limit = usage.limitMinutes, used = usage.todayMinutes
            if limit == 0 { return "没开提醒，用多久都不打扰" }
            if used < limit { return "再用 \(limit - used) 分钟提醒" }
            return "已经过了 \(limit) 分钟的提醒"
        }

        /// 每日提醒的一个选项：一颗圆，0 是「关」，其余是分钟数
        private func limitOption(_ minutes: Int) -> some View {
            let selected = usage.limitMinutes == minutes
            return Button { usage.limitMinutes = minutes } label: {
                Yuan(minutes == 0 ? "关" : "\(minutes)")
                    .foregroundStyle(selected ? Color.white : Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: Metrics.pill, height: Metrics.pill)
                    .background(selected ? Palette.red : Palette.well, in: Circle())
                    .modifier(TouchTarget(visibleWidth: Metrics.pill, visibleHeight: Metrics.pill))
            }
            .buttonStyle(PressableStyle())
            .animation(.quick, value: selected)
            .accessibilityLabel(minutes == 0 ? "关" : "\(minutes) 分钟")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }

        // MARK: 隐私说明

        private var privacy: some View {
            HStack(alignment: .top, spacing: Space.s12) {
                Glyph(systemImage: "lock.fill", tone: .onCanvas)
                // 也是自己按标点断的行，免得「密码」这样的词被劈开
                Text("只搜是小红书网页版外面的一层壳：\n不调用私有接口、不抓取数据，\n也不读取或保存你的账号密码。\n设置和使用时间只存在这台手机上。")
                    .font(Typo.plain())
                    .foregroundStyle(Palette.textSecondary)
                    .lineSpacing(Metrics.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Metrics.inset)
        }
    }

    /// 设置里装几行开关的卡片
    struct GroupCard: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(.horizontal, Metrics.pad)
                .padding(.vertical, Space.s4)
                .modifier(Card())
        }
    }
}

// MARK: - 提醒、登录提示、浮着的按钮、进度条

extension DesignC {
    /// 用到每日上限时盖在最上面的提醒：跟设置页一样，一整幅圆角面板从屏幕底下升起来（拇指够得着），
    /// 圆环走满，语气平和，一个主要按钮
    struct UsageReminder: View {
        @ObservedObject var usage: UsageTimer
        let openSettings: () -> Void
        @State private var raised = false

        var body: some View {
            ZStack(alignment: .bottom) {
                Palette.scrim.ignoresSafeArea()
                VStack(spacing: 0) {
                    Dial(minutes: usage.todayMinutes, limit: usage.limitMinutes, size: Metrics.dialLarge)
                    Yuan("今天的 \(usage.limitMinutes) 分钟到了", size: Typo.title)
                        .foregroundStyle(Palette.text)
                        .padding(.top, Space.s16)
                    Text("找到想要的了吗？")
                        .font(Typo.plain(Typo.body))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, Space.s8)
                    Text("之后每多用 10 分钟会再提醒一次")
                        .font(Typo.plain())
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, Space.s4)
                    Button { usage.alertShown = false } label: {
                        Yuan("知道了")
                    }
                    .buttonStyle(PillStyle(kind: .primary, height: Metrics.control, wide: true))
                    .padding(.top, Space.s24)
                    Button {
                        usage.alertShown = false
                        openSettings()
                    } label: {
                        Yuan("调整提醒时间")
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: Metrics.touch)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, Space.s8)
                }
                .padding(.horizontal, Space.s24)
                .padding(.top, Space.s32)
                .padding(.bottom, Space.s12)
                .frame(maxWidth: Metrics.maxWidth)
                .frame(maxWidth: .infinity)
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: Metrics.radiusSheet, topTrailingRadius: Metrics.radiusSheet, style: .continuous)
                        .fill(Palette.card)
                        .padding(.bottom, -Space.s32) // 升上来时会多冲一点再落回去，底下多垫一截，别露出缝
                        .ignoresSafeArea(edges: .bottom)
                }
                .offset(y: raised ? 0 : Space.s32)
            }
            .onAppear {
                hideKeyboard() // 键盘别盖住提醒
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) { raised = true }
            }
        }
    }

    /// 登录要扫码时浮在登录页顶部的帮忙提示（逻辑见 LoginHelp.swift）：一张白卡片，排法跟首页的提示卡一样
    /// （左边图标圆，标题、正文、按钮都从标题那条线起），两个一样重的胶囊按钮。
    /// 底下的登录页有白色的大块，所以除了影子还有一圈淡边
    struct LoginBanner: View {
        @ObservedObject var browser: Browser

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
            HStack(alignment: .top, spacing: Space.s12) {
                Glyph(systemImage: "qrcode.viewfinder", tone: .soft)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: Space.s8) {
                        Yuan("需要扫码确认登录")
                            .foregroundStyle(Palette.text)
                        Spacer(minLength: 0)
                        Button { browser.loginHelpDismissed = true } label: {
                            Glyph(systemImage: "xmark", size: Metrics.glyphSmall)
                                .frame(width: Metrics.touch, height: Metrics.touch)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("关闭")
                    }
                    .frame(height: Metrics.glyph)
                    .padding(.trailing, -Metrics.overhang(Metrics.glyphSmall))
                    Text(browser.loginHelpMessage)
                        .font(Typo.plain())
                        .foregroundStyle(Palette.textSecondary)
                        .lineSpacing(Metrics.lineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.s4)
                    HStack(spacing: Space.s8) {
                        scanButton(.weChat)
                        scanButton(.xiaohongshu)
                    }
                    .padding(.top, Space.s12)
                }
            }
            .padding(Metrics.pad)
            .background { shape.fill(Palette.card).modifier(Lifted(.float)) }
            .overlay { shape.strokeBorder(Palette.edge, lineWidth: 1) }
            .frame(maxWidth: Metrics.maxWidth)
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Space.s8)
        }

        private func scanButton(_ app: ScanApp) -> some View {
            Button {
                Task { await browser.saveLoginQR(andOpen: app) }
            } label: {
                Yuan("用\(app.name)确认")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(PillStyle(kind: .soft, wide: true))
        }
    }

    /// 整页加载时网页顶上的进度条：小红书的页面要先白一会儿才画出来，有它就知道是在加载、不是卡住了。
    /// 从屏幕左边长出来，所以左头是平的，只有往前走的那一头是圆的
    struct LoadingBar: View {
        let progress: Double

        var body: some View {
            GeometryReader { geo in
                UnevenRoundedRectangle(bottomTrailingRadius: Metrics.bar / 2, topTrailingRadius: Metrics.bar / 2)
                    .fill(Palette.gradient)
                    .frame(width: max(geo.size.width * progress, Metrics.bar))
                    .animation(.easeOut(duration: 0.25), value: progress)
            }
            .frame(height: Metrics.bar)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
    }
}
