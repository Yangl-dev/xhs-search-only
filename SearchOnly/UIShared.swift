import SwiftUI

// 几套界面设计共用的小工具，不带任何一套的视觉风格。各套设计（DesignA.swift、DesignC.swift …）都可以用。
// 对比期间这个文件是公用的：做某一套设计时不要改它

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// 浅色、深色模式各一个颜色
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

extension Animation {
    /// 短而平的过渡，各处通用
    static let quick = Animation.easeOut(duration: 0.2)
}

/// 小红书网页自己的样子：网页那一块永远是它自己的颜色（跟随系统深浅色），
/// 紧挨着网页的原生界面（底栏、消息页顶上的切换、进度条）要跟它接得上，别出现一条色差
enum WebPage {
    /// 网页底色：浅色模式纯白，深色模式 #0A0A0A（实测）
    static let background = Color(light: 0xFFFFFF, dark: 0x0A0A0A)
    /// 小红书的品牌红，网页里的红色都是它
    static let red = Color(hex: 0xFF2442)
}

/// 网页配色：一套界面风格希望小红书网页长成什么样，写成一组数值。
/// 它们会变成网页里的一组变量（--xso-bg、--xso-surface …），xhs-rules.js 按小红书的页面结构把这些变量用上去。
/// 各套设计只管给数值，不碰小红书的页面结构；紧挨网页的原生界面（底栏、顶栏）也用同一组颜色，接起来没有色差
struct WebSkin {
    /// 浅色、深色模式各一个颜色
    struct Tone {
        var light: UInt32
        var dark: UInt32
        var color: Color { Color(light: light, dark: dark) }
    }

    /// 页面底色
    var background: Tone
    /// 卡片、浮层的底色
    var surface: Tone
    /// 主要文字、次要文字
    var text: Tone
    var textSecondary: Tone
    /// 细分隔线
    var hairline: Tone
    /// 输入框、小标签这类浅色块
    var fill: Tone
    /// 强调色（小红书原来是红色的地方）
    var accent: Tone
    /// 圆角（单位是网页的 px，和 pt 一样大）：笔记卡片、卡片里的图、按钮和输入框（999 = 胶囊）
    var cardRadius = 8
    var mediaRadius = 8
    var controlRadius = 999
    /// 标题用的字体。目前用不上：宋体、圆体是系统按需下载的字体，只有 app 自己的界面能用，网页那个进程里没有，
    /// 所以网页里的字一律还是苹方
    var displayFont: String?
    /// 卡片的阴影和描边（CSS 写法，可以用 var(--xso-line) 这些变量）；深色模式下阴影不画
    var cardShadow = "none"
    var cardBorder = "none"
    /// 笔记卡片上下之间多留的缝：卡片有底色、描边或阴影时要留一点，不然挨在一起
    var cardGap = 0

    // 笔记详情页
    /// 文字链接：正文里的话题标签、评论里的「展开 N 条回复」。小红书原来是一种深蓝 / 浅蓝
    var link = Tone(light: 0x13386C, dark: 0xC7DAEF)
    /// 压在强调色上的字（实心的「关注」、评论的「发送」）
    var onAccent = Tone(light: 0xFFFFFF, dark: 0xFFFFFF)
    /// 「关注」按钮：true 是强调色实心，false 是强调色描边（小红书原来是描边）
    var followFilled = false
    /// 笔记的图、正文、评论、底部操作条各放进一张卡片（底色、阴影跟笔记卡片一样，圆角取 cardRadius），四周留 12 的缝；
    /// false 就是小红书原来那样整页铺满、中间用分隔线隔开
    var notePanels = false
    /// 笔记顶上作者那一行（往下滑时停在顶上）底下画一条细线
    var noteHeaderRule = false

    /// 小红书网页原本的样子（不改任何东西时的参照）
    static let xiaohongshu = WebSkin(
        background: Tone(light: 0xFFFFFF, dark: 0x0A0A0A), surface: Tone(light: 0xFFFFFF, dark: 0x1A1A1A),
        text: Tone(light: 0x333333, dark: 0xE6E6E6), textSecondary: Tone(light: 0x8C8C8C, dark: 0x8C8C8C),
        hairline: Tone(light: 0xEAEAEA, dark: 0x303030), fill: Tone(light: 0xF5F5F5, dark: 0x1C1C1C),
        accent: Tone(light: 0xFF2442, dark: 0xFF2442))

    private func variables(dark: Bool) -> String {
        func hex(_ tone: Tone) -> String { String(format: "#%06X", dark ? tone.dark : tone.light) }
        var lines = [
            "--xso-bg: \(hex(background))", "--xso-surface: \(hex(surface))", "--xso-text: \(hex(text))",
            "--xso-text-2: \(hex(textSecondary))", "--xso-line: \(hex(hairline))", "--xso-fill: \(hex(fill))",
            "--xso-accent: \(hex(accent))", "--xso-card-shadow: \(dark ? "none" : cardShadow)",
            "--xso-link: \(hex(link))", "--xso-on-accent: \(hex(onAccent))",
        ]
        if !dark {
            lines += ["--xso-radius-card: \(cardRadius)px", "--xso-radius-media: \(mediaRadius)px", "--xso-radius-control: \(controlRadius)px",
                      "--xso-card-border: \(cardBorder)", "--xso-card-gap: \(cardGap)px"]
            // 下面这些只是指向上面的颜色，深色模式跟着变，不用再写一遍
            lines += [
                "--xso-follow-bg: \(followFilled ? "var(--xso-accent)" : "transparent")",
                "--xso-follow-fg: \(followFilled ? "var(--xso-on-accent)" : "var(--xso-accent)")",
                "--xso-header-rule: \(noteHeaderRule ? "1px solid var(--xso-line)" : "none")",
                "--xso-panel-bg: \(notePanels ? "var(--xso-surface)" : "transparent")",
                "--xso-panel-inset: \(notePanels ? 12 : 0)px",
                "--xso-panel-radius: \(notePanels ? cardRadius : 0)px",
                "--xso-panel-shadow: \(notePanels ? "var(--xso-card-shadow)" : "none")",
                "--xso-panel-rule: \(notePanels ? "none" : "1px solid var(--xso-line)")",
                "--xso-panel-divider: \(notePanels ? "none" : "block")",
            ]
        }
        return lines.joined(separator: "; ")
    }

    /// 四套风格的变量，按 <html data-xso-style="…"> 区分
    static var allCSS: String {
        UIStyle.allCases.map { style in
            let skin = style.webSkin
            return """
                html[data-xso-style="\(style.rawValue)"] { \(skin.variables(dark: false)) }
                @media (prefers-color-scheme: dark) { html[data-xso-style="\(style.rawValue)"] { \(skin.variables(dark: true)) } }
                """
        }.joined(separator: "\n")
    }

    /// 同上，写成可以直接放进脚本里的字符串
    static var allCSSLiteral: String {
        (try? JSONEncoder().encode(allCSS)).flatMap { String(data: $0, encoding: .utf8) } ?? "''"
    }
}

/// 搜索页顶栏的占位：某套设计还没做自己的顶栏时先用它（返回 + 正在搜的词）
struct PlaceholderResultsBar: View {
    @ObservedObject var browser: Browser

    var body: some View {
        HStack(spacing: 4) {
            Button { browser.goBack() } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("返回")
            Button { browser.showSearchHome() } label: {
                Text(browser.currentKeyword ?? "").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).frame(height: 44)
            }
        }
        .foregroundStyle(.primary)
        .padding(.trailing, 16)
        .background(browser.style.webSkin.background.color.ignoresSafeArea(edges: .top))
    }
}

/// 按下时轻轻变淡、缩一点
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.quick, value: configuration.isPressed)
    }
}

/// 一行排不下就换行的排列：最近搜索的小标签用
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var items: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !row.items.isEmpty && row.width + spacing + size.width > width {
                rows.append(row)
                row = Row(y: row.y + row.height + spacing)
            }
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append(index)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

/// 系统自带、但用到时才下载的中文字体：宋体（STSongti-SC-Regular / Bold / Black / Light）、圆体（STYuanti-SC-Regular / Bold）、
/// 楷体（STKaitiSC-Regular）……手机上默认只有苹方。这些字体由 iOS 自己从苹果下载、装在系统里（不占 app 的体积），
/// 第一次用要联网等几秒到几十秒，之后一直都在。还没下好时 font(_:size:) 先给系统字体，下好了界面自动换上
@MainActor
final class OnDemandFonts: ObservableObject {
    static let shared = OnDemandFonts()
    /// 已经能用的字体名
    @Published private(set) var ready: Set<String> = []
    private var requested: Set<String> = []

    /// 要用这些字体：有的直接记下，没有的让系统去下载
    func request(_ names: [String]) {
        let new = names.filter { !requested.contains($0) }
        guard !new.isEmpty else { return }
        requested.formUnion(new)
        recheck()
        let missing = new.filter { !ready.contains($0) }
        guard !missing.isEmpty else { return }
        let descriptors = missing.map { CTFontDescriptorCreateWithAttributes([kCTFontNameAttribute: $0] as CFDictionary) }
        CTFontDescriptorMatchFontDescriptorsWithProgressHandler(descriptors as CFArray, nil) { state, _ in
            if state == .didFinish || state == .didFailWithError {
                #if DEBUG
                mark("on-demand fonts \(missing.joined(separator: ",")) → \(state == .didFinish ? "finished" : "failed")")
                #endif
                Task { @MainActor in OnDemandFonts.shared.recheck() }
            }
            return true
        }
    }

    private func recheck() {
        let now = Set(requested.filter { UIFont(name: $0, size: 12) != nil })
        if now != ready { ready = now }
    }

    /// 这个字体下好了就用它，没下好先用后备字体
    func font(_ name: String, size: CGFloat, fallback: Font) -> Font {
        ready.contains(name) ? .custom(name, fixedSize: size) : fallback
    }
}

/// 收起键盘
@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

extension UserDefaults {
    /// 没存过就用默认值的开关。用 bool(forKey:) 读，这样调试时的启动参数（`-xso.grayscale YES`）也认
    func flag(_ key: String, default value: Bool) -> Bool {
        object(forKey: key) == nil ? value : bool(forKey: key)
    }
}

/// 截图用的调试入口（只在 DEBUG 版里起作用）：启动参数 `-uiDemo <状态>` 把界面直接摆到某个状态，不用手点。
/// 状态：home-idle（首页收起键盘）、searching / stalled（首页的两种提示）、settings、settings-bottom（设置滑到底）、
/// link-guide（首页左上角「打开链接」的说明页）、
/// results（搜索结果页：顶栏 + 占位的笔记卡片）、
/// messages / notifications（消息页，网页部分换成一页占位内容）、loading（网页顶上的进度条）、
/// reminder（使用时间提醒）、login（扫码登录提示）。
/// 另有 `-uiDemoQuery <词>`：首页搜索框里预先填好这个词
enum UIDemo {
    #if DEBUG
    static let state = UserDefaults.standard.string(forKey: "uiDemo")
    static let query = UserDefaults.standard.string(forKey: "uiDemoQuery") ?? ""

    @MainActor
    static func run(browser: Browser, usage: UsageTimer) async {
        guard let state else { return }
        try? await Task.sleep(for: .seconds(1.5))
        switch state {
        case "home-idle":
            hideKeyboard()
        case "searching":
            browser.isSearching = true
        case "stalled":
            browser.searchStalled = true
        case "settings", "settings-bottom":
            hideKeyboard()
            browser.showsSettings = true
        case "link-guide":
            hideKeyboard()
            browser.showsLinkGuide = true
        case "results":
            hideKeyboard()
            await browser.demoWebPage(path: "/search_result?keyword=%E6%89%8B%E5%86%B2%E5%92%96%E5%95%A1") // 搜的是「手冲咖啡」
        case "messages", "notifications", "loading":
            hideKeyboard()
            await browser.demoWebPage(path: state == "notifications" ? "/notification" : "/chat")
            if state == "loading" {
                try? await Task.sleep(for: .seconds(1.5))
                browser.demoLoading(0.6)
            }
        case "reminder":
            usage.demoReminder(minutes: 31)
        case "login":
            await browser.demoWebPage(path: "/login")
            browser.demoLoginBanner()
        default:
            break
        }
    }

    /// 网页部分的占位内容：一页灰色的列表骨架，颜色跟小红书网页一样（深色模式也跟着变）。
    /// 模拟器里没登录小红书，真实页面要么是登录框、要么是别人的内容，不适合拿来截图；
    /// 而且模拟器里的网页显示不了中文（全是方块），所以占位页上不放字
    static let placeholderPage = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          /* 颜色、圆角都取当前风格的网页配色变量（见 WebSkin），取不到就用小红书原样 */
          :root { --bg: var(--xso-bg, #fff); --card: var(--xso-surface, #fff); --a: #ececec; --b: #f3f3f3; }
          @media (prefers-color-scheme: dark) { :root { --bg: var(--xso-bg, #0a0a0a); --card: var(--xso-surface, #1a1a1a); --a: #2a2a2a; --b: #202020; } }
          body { margin: 0; padding-top: 8px; background: var(--bg); }
          .row { display: flex; gap: 12px; padding: 13px 16px; align-items: center; }
          .row i { width: 44px; height: 44px; border-radius: 50%; background: var(--a); flex: none; }
          .row b, .card b { display: block; height: 12px; width: 38%; border-radius: 6px; background: var(--a); }
          .row s, .card s { display: block; height: 10px; width: 72%; border-radius: 5px; background: var(--b); margin-top: 10px; }
          .row div { flex: 1; }
          .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; padding: 4px 10px; }
          .card { background: var(--card); border-radius: var(--xso-radius-card, 8px); box-shadow: var(--xso-card-shadow, none);
                  border: var(--xso-card-border, none); overflow: hidden; padding-bottom: 12px; }
          .card u { display: block; background: var(--a); border-radius: var(--xso-radius-media, 8px); }
          .card b { width: 80%; margin: 10px 10px 0; } .card s { width: 50%; margin: 8px 10px 0; }
        </style></head><body>
        <script>
          // 搜索结果页画成两列卡片，其余页面画成列表
          if (location.pathname.startsWith('/search_result')) {
            const heights = [210, 160, 180, 230, 170, 200, 220, 150];
            document.write('<div class="grid">' + [0, 1].map((c) => '<div>' + heights.filter((_, i) => i % 2 === c)
              .map((h) => `<div class="card" style="margin-bottom:10px"><u style="height:${h}px"></u><b></b><s></s></div>`).join('') + '</div>').join('') + '</div>');
          } else {
            document.write('<div class="row"><i></i><div><b></b><s></s></div></div>'.repeat(12));
          }
        </script>
        </body></html>
        """
    #else
    static let state: String? = nil
    static let query = ""
    #endif
}

/// 搜索结果页顶栏里的搜索框（2026-11-22 用户要的）：显示正在搜的词，点一下就能直接改、按「搜索」重新搜，
/// 不用先跳回首页。三套风格的顶栏都用它，字体颜色由各套传进来。
/// 没改完就点了别处（键盘收起），框里换回正在搜的那个词
struct KeywordField: View {
    @ObservedObject var browser: Browser
    var font: Font
    var color: Color
    var placeholder: Color
    var alignment: TextAlignment = .leading

    @State private var text = ""
    @FocusState private var focused: Bool

    private var keyword: String { browser.currentKeyword ?? "" }

    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $text, prompt: Text("搜索笔记、地点、好物").foregroundStyle(placeholder))
                .font(font)
                .foregroundStyle(color)
                .tint(color)
                .multilineTextAlignment(alignment)
                .lineLimit(1)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(submit)
                .accessibilityLabel("搜索")
                .accessibilityValue(text)
            if focused && !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(font)
                        .foregroundStyle(placeholder)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空")
            }
        }
        .onAppear { text = keyword }
        .onChange(of: browser.currentKeyword) { if !focused { text = keyword } }
        .onChange(of: focused) { if !focused { text = keyword } }
    }

    private func submit() {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            text = keyword
            return
        }
        #if DEBUG
        mark("search again from results bar")
        #endif
        browser.search(query)
    }
}

/// 防滑门卫拦下一次「下一条」时，顶上浮出来的一句话
struct GuardNotice: View {
    let text: String?

    var body: some View {
        Group {
            if let text {
                Label(text, systemImage: "hand.raised.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.8), in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.quick, value: text)
    }
}
