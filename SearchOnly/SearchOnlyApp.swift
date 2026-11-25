import SwiftUI
import WebKit

enum Config {
    static let homeURL = URL(string: "https://www.xiaohongshu.com/explore")!
    // 小红书单独的登录页：只有二维码和手机号登录，没有推荐流
    static let loginURL = URL(string: "https://www.xiaohongshu.com/login")!
    // 调试用：启动参数 `-startURL <网址>` 可以直接打开某个页面
    static let debugStartURL = UserDefaults.standard.string(forKey: "startURL").flatMap(URL.init(string:))

    // 桌面 Safari 的 UA：拿到功能完整的桌面版网页，而不是推你下载 app 的手机版
    static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15"

    /// 小红书网页的页面结构（选择器等）都在 xhs-rules.js 里，改版时只改那一个文件
    static let xhsRules = Bundle.main.url(forResource: "xhs-rules", withExtension: "js")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "const XSO_RULES = {};"

    /// 外部链接交给 Safari 前去掉的追踪参数（utm_ 开头的，加上这些常见的）
    static let trackingParameters: Set<String> = [
        "fbclid", "gclid", "dclid", "msclkid", "igshid", "igsh", "mc_cid", "mc_eid", "spm",
        "xhsshare", "apptime", "appuid", "share_id", "share_from_user_hidden", "share_source",
    ]

    static func withoutTracking(_ url: URL) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = parts.queryItems else { return url }
        let kept = items.filter { !$0.name.lowercased().hasPrefix("utm_") && !trackingParameters.contains($0.name.lowercased()) }
        guard kept.count != items.count else { return url }
        parts.queryItems = kept.isEmpty ? nil : kept
        return parts.url ?? url
    }

    // 只有这些域名（含子域名）在 app 里打开，其余链接交给 Safari
    static let allowedHosts = ["xiaohongshu.com", "xhslink.com"]

    /// 「内容页」（一条笔记）的网址路径，正则，给防滑门卫 xso-guard.js 用：笔记只能是你自己点进去的。
    /// 括号里抓的是笔记 id：同一条笔记有好几种网址写法（/discovery/item/<id> 打开后改成 /explore/<id>），按 id 认才不会把同一条当成「下一条」
    static let contentPattern = #"^/(?:explore|discovery/item|search_result)/([0-9a-f]{24})"#

    /// 小红书海外版 rednote.com 的分享链接，换成 www.xiaohongshu.com 同一个路径。
    /// 不把 rednote.com 加进放行名单：没登录时网页会显示海外版
    static func canonical(_ url: URL) -> URL {
        guard let host = url.host?.lowercased(), host == "rednote.com" || host.hasSuffix(".rednote.com"),
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        parts.host = "www.xiaohongshu.com"
        parts.scheme = "https"
        return parts.url ?? url
    }

    // 带斜杠的网址：不带的话小红书会先重定向到 http，被 iOS 拦下
    /// 待在小红书首页时挡掉的东西：图片和视频（推荐流被原生首页盖着，下载了也看不见）。只是不下载，不改任何请求。
    /// 「是不是在首页」由 WebKit 自己按网页当前的网址判断（if-top-url，站内跳转改了网址也立刻算数），
    /// 不再由 app 在换页时挂上、撤下：以前 app 收到「网址变了」再撤规则，中间有一小段时间差，
    /// 从首页第一次搜索、点「我」时，新页面最先发出的那批图片会被挡掉，而且不会重新下载，看起来就是有的图加载不出来。
    /// 网址只认首页本身（/explore、/，可带 ? 参数），/explore/<笔记 ID> 是笔记页，不挡
    static let homeMediaBlockRules = #"""
        [{"trigger": {"url-filter": ".*", "resource-type": ["image", "media"],
                      "if-top-url": ["^https?://www\\.xiaohongshu\\.com/(explore)?([?#].*)?$"]},
          "action": {"type": "block"}}]
        """#

    /// 一直挡掉的：小红书网页的埋点、性能上报这些统计请求（每翻一页、点一下都会发，占网速也占网页的主线程）。
    /// 名单取自公开的过滤规则 AdGuard Tracking Protection、AdGuard DNS filter、EasyPrivacy 里写明是小红书统计的那几条；
    /// 只挡这些，安全验证（as.、edith-seb.）和正常的数据接口（edith. 的其余路径）都不碰，免得被当成机器人要验证码。
    /// 内容拦截规则不支持「或」，所以一个域名一条
    static let trackerBlockRules: String = {
        let hosts = ["t2", "apm-fe", "apm-track", "apm-native", "lng", "spider-tracker"].map { #"^https?://\#($0)\.xiaohongshu\.com/"# }
        let paths = [#"^https?://edith\.xiaohongshu\.com/api/sns/web/v1/note/metrics_report"#,
                     #"^https?://[^/]*xiaohongshu\.com/api/(v2/)?collect"#]
        let rules = (hosts + paths).map { pattern -> [String: Any] in
            ["trigger": ["url-filter": pattern], "action": ["type": "block"]]
        }
        let data = (try? JSONSerialization.data(withJSONObject: rules)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }()

    static func searchURL(_ query: String) -> URL? {
        var parts = URLComponents(string: "https://www.xiaohongshu.com/search_result/")
        parts?.queryItems = [URLQueryItem(name: "keyword", value: query), URLQueryItem(name: "source", value: "web_explore_feed")]
        return parts?.url
    }
}

/// 网页和原生界面之间共享的状态
@MainActor
final class Browser: ObservableObject {
    /// 整个 app 只有一个：Siri / 快捷指令、长按图标、桌面小组件都要从外面找到它
    static let shared = Browser()

    /// 原生搜索页是否盖在网页上面：之后跟着网页里的搜索框走（脚本会通知）
    @Published var showsSearch: Bool
    /// 每加一，原生搜索框就重新获得焦点、弹出键盘（从小组件、长按图标进来时用）
    @Published var focusRequest = 0
    /// 冷启动时网页窗口还没建好就要搜（Siri、最近搜索），先记下来，建好再搜
    private var pendingQuery: String?
    @Published var isSearching = false
    @Published var searchStalled = false
    /// 整页加载的进度（0–1），nil 表示没在整页加载：网页顶上的细进度条看它
    @Published private(set) var loadProgress: Double?
    private var loadGeneration = 0

    func loadStarted() {
        loadGeneration += 1
        loadProgress = 0.1
        #if DEBUG
        mark("loading bar shown")
        #endif
    }

    func loadProgressed(_ progress: Double) {
        guard let current = loadProgress else { return }
        loadProgress = max(current, min(progress, 0.95))
    }

    /// 新页面解析完了（xso-page.js 一开始跑就会通知）：进度条走满再收起
    func pageReady() {
        guard loadProgress != nil else { return }
        #if DEBUG
        mark("loading bar done")
        #endif
        loadProgress = 1
        let generation = loadGeneration
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            if generation == loadGeneration { loadProgress = nil }
        }
    }
    weak var webView: WKWebView? {
        didSet {
            homeMediaBlocked = false // 新网页窗口还没挂上拦截规则
            installTrackerBlocker()
            updateHomeMediaBlocker()
        }
    }
    /// 网页窗口打开时加载的地址：登录过就是首页（被搜索框盖住），没登录过就直接是登录页
    private(set) var startURL: URL
    /// 每加一，SwiftUI 就丢掉旧的网页窗口、建一个全新的（新的网页进程），用来从卡死里恢复
    @Published private(set) var webViewID = 0
    private var searchWatchdog: Task<Void, Never>?

    // 只在网页里起作用的几个开关：存在 app 里，同步到小红书网页的 localStorage（换页、重开都读得到），
    // 要靠样式实现的再挂到 <html> 的属性上（样式见 xhs-rules.js，页面一开始就按 localStorage 挂好）
    // 「只看图文」（每次搜索替用户点「图文」并藏掉标签那排）2026-11-16 按用户的意思去掉了：视频也是获取信息的方式，
    // 而且视频点开是全屏、看完退出，没有往下刷的信息流。要加回来见 git 历史（提交 662288f 及以前）
    /// 灰度模式：网页里的图片和视频变黑白，原生界面也一起变灰，看着没那么抓人。默认关
    @Published var grayscale = UserDefaults.standard.bool(forKey: "xso.grayscale") {
        didSet { UserDefaults.standard.set(grayscale, forKey: "xso.grayscale"); syncPageSettings() }
    }
    /// 搜索结果的封面图先模糊，看标题决定点不点；点进笔记就是清楚的。默认关
    @Published var blurImages = UserDefaults.standard.bool(forKey: "xso.blurImages") {
        didSet { UserDefaults.standard.set(blurImages, forKey: "xso.blurImages"); syncPageSettings() }
    }
    /// 视频点了才播（见 xso-page.js），默认开
    @Published var tapToPlay = UserDefaults.standard.flag("xso.tapToPlay", default: true) {
        didSet { UserDefaults.standard.set(tapToPlay, forKey: "xso.tapToPlay"); syncPageSettings() }
    }

    func syncPageSettings() {
        func flag(_ on: Bool) -> Int { on ? 1 : 0 }
        webView?.evaluateJavaScript("""
            localStorage.setItem('xsoGray', '\(flag(grayscale))');
            localStorage.setItem('xsoBlur', '\(flag(blurImages))');
            localStorage.setItem('xsoTapToPlay', '\(flag(tapToPlay))');
            document.documentElement.setAttribute('data-xso-style', '\(style.rawValue)');
            document.documentElement.toggleAttribute('data-xso-gray', \(grayscale));
            document.documentElement.toggleAttribute('data-xso-blur', \(blurImages));
            """)
    }

    /// 先登录再搜索：记住这台手机上是否已经登录过
    private static let loggedInKey = "xso.loggedIn"
    var isLoggedIn: Bool {
        get { UserDefaults.standard.bool(forKey: Self.loggedInKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.loggedInKey) }
    }

    init() {
        let loggedIn = UserDefaults.standard.bool(forKey: Self.loggedInKey)
        showsSearch = loggedIn
        startURL = Config.debugStartURL ?? (loggedIn ? Config.homeURL : Config.loginURL)
        prepareHomeMediaBlocker()
        prepareTrackerBlocker()
        restoreIconIfStyleRemoved()
        // 「首页空白模式」开关 2026-11-22 删了（关掉就是原版小红书网页，用户想不到用处），现在一直是空白首页
        UserDefaults.standard.removeObject(forKey: "xso.blankHome")
    }

    /// 存着的风格已经删掉了（比如「纸页」，2026-11-22 删）：界面回到「原味」，桌面上还是那套的图标，也换回默认的
    private func restoreIconIfStyleRemoved() {
        guard let saved = UserDefaults.standard.string(forKey: "xso.uiStyle"), UIStyle(rawValue: saved) == nil else { return }
        UserDefaults.standard.removeObject(forKey: "xso.uiStyle")
        Task {
            try? await Task.sleep(for: .seconds(1)) // 等界面出来再换，系统「图标已更改」的提示才弹得出来
            guard UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != style.iconName else { return }
            try? await UIApplication.shared.setAlternateIconName(style.iconName)
        }
    }

    /// 原生首页底下垫着的小红书首页：推荐流虽然被盖住看不见，图片照样下载（实测 180 张，拖到 40 秒才加载完，
    /// 还和第一次搜索抢网速）。待在首页时挡掉图片和视频，一离开首页就放开（见 Config.homeMediaBlockRules）。
    /// 规则一直挂着（以前的「首页空白模式」开关已删）
    private var homeMediaBlocker: WKContentRuleList?
    private var homeMediaBlocked = false

    private func prepareHomeMediaBlocker() {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "xso-home-media", encodedContentRuleList: Config.homeMediaBlockRules
        ) { [weak self] list, _ in
            Task { @MainActor in
                self?.homeMediaBlocker = list
                self?.updateHomeMediaBlocker()
            }
        }
    }

    /// 统计请求的拦截规则（见 Config.trackerBlockRules）：编译好以后挂到每个网页窗口上，一直挂着
    private var trackerBlocker: WKContentRuleList?

    private func prepareTrackerBlocker() {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "xso-trackers", encodedContentRuleList: Config.trackerBlockRules
        ) { [weak self] list, error in
            Task { @MainActor in
                #if DEBUG
                if let error { mark("tracker rules failed: \(error.localizedDescription)") }
                #endif
                self?.trackerBlocker = list
                self?.installTrackerBlocker()
            }
        }
    }

    private func installTrackerBlocker() {
        guard let trackerBlocker, let controller = webView?.configuration.userContentController else { return }
        controller.add(trackerBlocker)
    }

    func updateHomeMediaBlocker() {
        guard let homeMediaBlocker, !homeMediaBlocked, let controller = webView?.configuration.userContentController else { return }
        homeMediaBlocked = true
        controller.add(homeMediaBlocker)
        #if DEBUG
        mark("home media blocked")
        #endif
    }

    /// 登录过期时要去的页面（比如正在搜的词）：登录好了直接打开它，不用再搜一遍
    private var afterLogin: URL?

    /// 发现没登录（首页底下弹出了登录框，或者搜索时小红书说没登录）：直接带去登录页，而不是让人搜了半天才发现要登录
    func requireLogin() {
        isLoggedIn = false
        isSearching = false
        searchWatchdog?.cancel()
        #if DEBUG
        mark("not logged in → open login page")
        #endif
        watchLoad(of: Config.loginURL)
        webView?.load(URLRequest(url: Config.loginURL))
    }

    /// 上一次被转去 rednote.com 的网址和时间：同一个网址 1 分钟内又被转走，就不再带去登录，免得来回跳
    private var lastAbroad: (url: URL, at: Date)?

    /// 小红书把要打开的页面整页转去了海外版 rednote.com（没登录时会这样）：先登录，登录好了直接打开它。
    /// 登录后还被转走（比如别的原因），回原生搜索首页，不再循环
    func redirectedAbroad(_ url: URL) {
        #if DEBUG
        // 截图模式（-uiDemo）：模拟器没登录，底下的首页一加载就会被转走；别带去登录页，不然摆好的界面被登录页换掉
        if UIDemo.state != nil {
            mark("redirected to rednote (ui demo) → stay")
            return
        }
        #endif
        if let last = lastAbroad, last.url == url, Date.now.timeIntervalSince(last.at) < 60 {
            #if DEBUG
            mark("redirected to rednote again → stop, show search home")
            #endif
            loadWatchdog?.cancel()
            showsSearch = true
            pageReady()
            return
        }
        lastAbroad = (url, .now)
        afterLogin = url
        requireLogin()
    }

    /// 网页进程有时会卡死：一开始跳转就整个不动，在它里面重新加载也没用。
    /// 这时丢掉整个网页窗口，换一个全新的去加载（登录状态在 cookie 里，不受影响）
    func rebuildWebView(loading url: URL) {
        #if DEBUG
        mark("rebuild web view → \(url.path)")
        #endif
        loadWatchdog?.cancel()
        startURL = url
        webViewID += 1
    }

    /// 跳转看门狗：一要求加载某个页面就开始计时（网页卡死时连「开始加载」都不会通知），
    /// 5 秒还没开始显示（正常 1 秒内）就先问网页一声：还能回话说明只是网慢，再等 10 秒；
    /// 不回话（网页进程卡死了）或者再等也没显示，才换一个全新的网页窗口去加载同一个地址。
    /// 网页窗口整个 app 只有一个，平时切页面、切标签都不会换，只有真卡死才换
    private var loadWatchdog: Task<Void, Never>?

    func watchLoad(of url: URL) {
        loadWatchdog?.cancel()
        loadWatchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, !Task.isCancelled else { return }
            if let webView = self.webView, await Self.pageResponds(webView) {
                #if DEBUG
                mark("page didn't start showing in 5s, but still responds → wait")
                #endif
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
            }
            #if DEBUG
            mark("page stuck")
            #endif
            self.rebuildWebView(loading: url)
        }
    }

    /// 网页进程还活着吗：让它算个 1，1 秒内没回来就算卡死
    private static func pageResponds(_ webView: WKWebView) async -> Bool {
        await answer(within: 1) { done in
            webView.evaluateJavaScript("1") { _, error in done(error == nil) }
        } ?? false
    }

    /// 网页卡死时，调它的 JS 永远不会返回：最多等这么多秒，没回来就当 nil。
    /// `start` 里用 WebKit 带回调的那种调用，回调只捎着 `done`、不捎网页窗口：超时以后看门狗换了新窗口，
    /// 卡死的旧窗口不会被这次没回来的调用拽着不放（窗口释放时 WebKit 会用一个错误结束这次调用）。
    /// 以前是 `Task { await webView.evaluateJavaScript(...) }`，那个 Task 永远等不到结果，旧窗口和它的网页进程就一直漏着
    private static func answer<T>(within seconds: Double, _ start: (@escaping @MainActor (T?) -> Void) -> Void) async -> T? {
        await withCheckedContinuation { continuation in
            var answered = false
            let finish: @MainActor (T?) -> Void = { result in
                guard !answered else { return }
                answered = true
                continuation.resume(returning: result)
            }
            start(finish)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                finish(nil)
            }
        }
    }

    func loadSettled() {
        loadWatchdog?.cancel()
    }

    private var passedLoginPage = false
    private static func isLoginPage(_ path: String) -> Bool { path == "/login" || path.hasPrefix("/website-login") }

    /// 网址变化：从登录页跳走，说明登录好了。不等小红书自己跳转（那一步会卡住），
    /// 直接显示原生搜索框，并用新的网页窗口在底下加载首页
    func pathChanged(from old: String?, to new: String?) {
        currentPath = new
        // 登录时小红书可能先转去安全验证（/website-login/…，验证码之类），那还没登录好，接着等。
        // 只有到过登录页、又离开了登录和验证这一串页面，才算登录成功；平时看笔记中途弹出的安全验证，做完回来不算
        if new == "/login" { passedLoginPage = true }
        // app 自己发起的跳转（搜索、重建窗口）不算，只有小红书在登录页上自己跳走才算登录成功
        guard let old, Self.isLoginPage(old), let new, !Self.isLoginPage(new) else { return }
        defer { passedLoginPage = false } // 离开了这一串页面，不管算不算登录成功，下次都要重新到过登录页
        guard passedLoginPage, !isSearching else { return }
        isLoggedIn = true
        #if DEBUG
        mark("left login page → logged in")
        #endif
        showsSearch = true
        rebuildWebView(loading: afterLogin ?? Config.homeURL)
        afterLogin = nil
    }

    /// 网页里的搜索框撤掉了（搜索页开始显示），搜索就算完成
    func searchPageShown() {
        isSearching = false
        searchStalled = false
        searchWatchdog?.cancel()
    }

    // 登录要扫码时用的状态，逻辑在 LoginHelp.swift
    @Published var loginQR: UIImage?
    @Published var loginHelpStatus = LoginHelpStatus.ready
    @Published var loginHelpDismissed = false
    var scanPromptVisible = false
    var qrScanTimer: Timer?
    /// 上一次找到的二维码内容：内容没变就不换图，界面不用跟着重画
    var loginQRPayload: String?

    /// 从小组件、长按图标「搜索」进来：盖上原生搜索页并弹出键盘（没登录时留在登录页）
    func showSearchHome() {
        guard isLoggedIn else { return }
        showsSearch = true
        focusRequest += 1
    }

    /// 网页窗口建好了：处理冷启动时排队的搜索
    func webViewReady() {
        if let query = pendingQuery {
            pendingQuery = nil
            search(query)
        }
        if let url = pendingLink {
            pendingLink = nil
            open(url)
        }
    }

    /// 「打开链接」打开的小红书链接（朋友分享的笔记）。网页窗口还没建好就先记下来
    private var pendingLink: URL?

    func openLink(_ url: URL) {
        guard webView != nil else {
            pendingLink = url
            return
        }
        // 一律整页加载，不走站内跳转（2026-11-23）：从首页站内跳到一条笔记，小红书过一秒会自己再跳回 /explore
        // （它要把推荐流垫在笔记后面），这一跳被页面白名单拦下、换成原生搜索首页，结果刚打开的笔记被首页盖住。
        // 整页加载的笔记页没有这一跳
        isSearching = true
        go(to: url, inPage: false)
    }

    /// 最近搜索（最多 10 个），只存在这台手机上：原生首页列出来，前 3 个做长按图标的快捷操作
    private static let recentKey = "xso.recentSearches"
    @Published private(set) var recentSearches = UserDefaults.standard.stringArray(forKey: recentKey) ?? [] {
        didSet {
            UserDefaults.standard.set(recentSearches, forKey: Self.recentKey)
            QuickActions.update(recent: Array(recentSearches.prefix(3)))
        }
    }

    private func rememberRecent(_ query: String) {
        var recent = recentSearches
        recent.removeAll { $0 == query }
        recent.insert(query, at: 0)
        recentSearches = Array(recent.prefix(10))
    }

    func clearRecentSearches() { recentSearches = [] }

    /// 防滑门卫刚拦下一次「下一条」时顶上显示的一句话，过一会儿自己消失
    @Published private(set) var guardNotice: String?
    private var guardNoticeTask: Task<Void, Never>?

    func noteBlocked() {
        guardNotice = "已拦下：这一条不是你点开的"
        guardNoticeTask?.cancel()
        guardNoticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.guardNotice = nil
        }
    }

    /// 「设置」页开着没有（首页右上角、使用时间提醒都能打开它）
    @Published var showsSettings = false {
        didSet { if showsSettings && !oldValue { settingsStyle = style } }
    }
    /// 「打开朋友发来的笔记」的说明页开着没有（首页左上角「打开链接」点开，见 ClipboardLink.swift 里的 LinkGuide）
    @Published var showsLinkGuide = false
    /// 设置页是按打开它时的风格画的：在设置里换了风格，正在收起的那一页还是旧风格，不会半路变成新风格的设置页闪一下
    private(set) var settingsStyle: UIStyle = .a

    /// 界面风格：几套设计都保留，在设置里切换（见 UIStyle.swift）。换的时候收起设置页露出新界面，桌面图标也跟着换
    @Published var style = UIStyle(rawValue: UserDefaults.standard.string(forKey: "xso.uiStyle") ?? "") ?? .a {
        didSet {
            guard style != oldValue else { return }
            UserDefaults.standard.set(style.rawValue, forKey: "xso.uiStyle")
            showsSettings = false
            // 网页的配色也跟着换：当前页面当场换；网页窗口里注入的脚本记的还是旧风格，
            // 所以换一个新的网页窗口（这时人在设置页，网页被首页盖着，看不出来）
            syncPageSettings()
            rebuildWebView(loading: Config.homeURL)
            let icon = style.iconName
            Task {
                // 等设置页收完再换图标：系统会弹一个「图标已更改」的提示，和正在收起的页面撞在一起会弹不出来
                try? await Task.sleep(for: .seconds(0.7))
                guard UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != icon else { return }
                do {
                    try await UIApplication.shared.setAlternateIconName(icon)
                } catch {
                    #if DEBUG
                    mark("icon change failed: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    #if DEBUG
    // 截图用（见 UIDemo）：不经过真实的跳转，直接把界面摆到某个状态
    /// 网页部分换成一页占位内容，并当作在 path 这个页面上
    func demoWebPage(path: String) async {
        let page = UIDemo.placeholderPage
        for _ in 0..<2 {
            webView?.loadHTMLString(page, baseURL: URL(string: "https://www.xiaohongshu.com" + path))
            try? await Task.sleep(for: .seconds(0.8))
            showsSearch = false
        }
    }

    func demoLoading(_ progress: Double) { loadProgress = progress }

    func demoLoginBanner() {
        showsSearch = false
        loginHelpDismissed = false
        loginQR = UIImage(systemName: "qrcode")
    }
    #endif

    /// 网页当前的路径（含站内跳转），底部导航栏用它决定哪一格亮
    @Published private(set) var currentPath: String?
    /// 自己的用户 ID：点过「我」以后记下，用来认出「这是我的主页」
    private(set) var myUserID: String?

    enum Tab { case home, ai, messages, me }

    /// 底部导航栏该亮哪一格：原生搜索首页、搜索结果、笔记都算「首页」，和小红书 app 一样
    var currentTab: Tab {
        if showsSearch { return .home }
        let path = currentPath ?? ""
        if path.hasPrefix("/ai_chat") { return .ai }
        if path.hasPrefix("/notification") || path.hasPrefix("/chat") { return .messages }
        if let id = myUserID, path.hasPrefix("/user/profile/\(id)") { return .me }
        return .home
    }

    /// 网页当前在搜什么词（从网址里读），搜索页顶栏显示它
    @Published private(set) var currentKeyword: String?

    func urlChanged(to url: URL?) {
        let keyword = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
            .queryItems?.first { $0.name == "keyword" }?.value
        if keyword != currentKeyword { currentKeyword = keyword }
    }

    /// 「一级页面」：从首页搜索、点底栏直接到的那几页。在这些页面上「返回」= 回原生首页；
    /// 再往里点进去的页面（笔记、某个会话、别人的主页）才是真的退回上一页
    var isRootPage: Bool {
        guard let path = currentPath else { return true }
        if ["/search_result", "/search_result/", "/ai_chat", "/ai_chat/", "/chat", "/chat/", "/notification", "/notification/", "/explore", "/"].contains(path) { return true }
        if let id = myUserID, path == "/user/profile/\(id)" { return true }
        return false
    }

    /// 返回：侧滑和搜索页顶栏的返回按钮都走这里
    func goBack() {
        guard !showsSearch, currentPath != "/login" else { return }
        if !isRootPage, let webView, webView.canGoBack {
            webView.goBack()
        } else {
            showSearchHome()
        }
    }

    /// 搜索页顶上的原生顶栏（返回 + 搜的词）：只在搜索结果页显示
    var showsResultsBar: Bool {
        guard !showsSearch, let path = currentPath else { return false }
        return path == "/search_result" || path == "/search_result/"
    }

    /// 「消息」页顶上的「私信 | 评论和通知」切换条：只在两个列表页上显示，点进某个会话后让给会话自己的标题栏
    var showsMessagesSwitcher: Bool {
        guard !showsSearch, let path = currentPath else { return false }
        return ["/chat", "/chat/", "/notification", "/notification/"].contains(path)
    }

    /// 底部导航栏显示的时候：登录了，登录页上不显示
    var showsTabBar: Bool {
        isLoggedIn && currentPath != "/login"
    }

    /// 底部导航栏和收藏入口：都是打开小红书网页上一个放行的页面
    func openWeb(_ address: String) {
        guard let url = URL(string: address) else { return }
        open(url)
    }

    func open(_ url: URL) {
        isSearching = true
        go(to: url)
    }

    /// 打开小红书的一个页面：能用小红书自己的路由切就切（和在网页里点链接一样，页面不整个重新加载，
    /// 旧页面一直显示到新页面画出来，没有白屏）；切不了（没登录、网页还没启动好、小红书改版、
    /// 发布页这种别的子域名）就退回整页加载
    private func go(to url: URL, inPage: Bool = true) {
        guard let webView else { return }
        // 连着搜、或者搜完马上点底栏：只算最后一次。前一次还在等网页的话，回来以后什么都不做，
        // 不然先发的后回来，会把人从新页面拽回旧页面，或者在已经回到首页以后又把首页收掉
        navigation?.cancel()
        Self.navigationSeq += 1
        let seq = Self.navigationSeq
        navigation = Task {
            let route = inPage ? await Self.routeInPage(webView, to: url, seq: seq) : .failed
            guard !Task.isCancelled else { return }
            switch route {
            case .routed:
                #if DEBUG
                mark("routed in page → \(url.path)")
                #endif
                // 放行的页面不会再发「搜索框撤掉了」（它本来就没盖着），原生首页由这里收起
                showsSearch = false
                searchPageShown()
                pageReady() // 站内切过去了：要是之前有整页加载的进度条还挂着，收掉
                loadSettled()
                return
            case .loggedOut:
                // 小红书网页的登录过期了（隔一段时间没用就会这样，cookie 本身一直保存着）：
                // 先去登录，登录好了直接打开刚才要去的页面
                #if DEBUG
                mark("logged out → login first, then \(url.path)")
                #endif
                afterLogin = url
                requireLogin()
                return
            case .failed:
                break
            }
            // 跳不了可能是网页卡死了（调 JS 没回来）：那就别在它里面加载，直接换新窗口
            let responds = await Self.pageResponds(webView)
            guard !Task.isCancelled else { return }
            guard responds else {
                rebuildWebView(loading: url)
                return
            }
            #if DEBUG
            mark("full load → \(url.path)")
            #endif
            watchLoad(of: url)
            webView.load(URLRequest(url: url))
        }
    }

    private enum RouteResult: String { case routed, loggedOut, failed }
    private var navigation: Task<Void, Never>?
    /// 每次跳转的编号，传给网页：网页里还在等路由的旧跳转看到编号变了就不跳
    private static var navigationSeq = 0

    /// 在网页里调小红书的 Vue 路由跳转。只读页面自己已有的路由对象，不发任何请求。
    /// failed 表示没跳（交给整页加载）；loggedOut 表示小红书网页说没登录
    private static func routeInPage(_ webView: WKWebView, to url: URL, seq: Int) async -> RouteResult {
        guard url.host == "www.xiaohongshu.com" else { return .failed }
        let target = url.path + (url.query.map { "?" + $0 } ?? "")
        // 等网页启动最多 8 秒、跳转本身最多 3 秒（见下面），再留 1 秒余量；网页卡死时到点就退回整页加载，由看门狗接手
        let result: String? = await answer(within: 12) { done in
            webView.callAsyncJavaScript("""
                \(Config.xhsRules)
                if (location.hostname !== 'www.xiaohongshu.com') return 'failed';
                window.__xsoNavSeq = seq;
                // 网页窗口刚换新（比如刚换了界面风格）时小红书的网页还在启动，路由还没有：等它最多 8 秒。
                // 以前是马上退回整页加载，等于把还在启动的网页扔掉从头再来一遍，更慢，进度条还会停在半截
                for (let i = 0; i < 80 && !(XSO_RULES.vue()?.$router && XSO_RULES.user()); i++) {
                    await new Promise((r) => setTimeout(r, 100));
                }
                const router = XSO_RULES.vue()?.$router;
                const user = XSO_RULES.user();
                if (window.__xsoNavSeq !== seq) return 'failed'; // 等的时候又发起了新的跳转：这次作废
                if (!router || !user) return 'failed';
                if (user.loggedIn === false) return 'loggedOut';
                // 只跳小红书路由表里真有的页面，落到兜底的 404 路由就不跳。
                // 用 replace 不用 push：app 自己发起的跳转（搜索、点底栏）不进返回历史，
                // 历史里只留用户在网页里点进去的页面（笔记、某个会话），「返回」才不会在几个栏目之间来回跳
                if (router.resolve(target).matched.some((r) => r.path.includes(':catchAll'))) return 'failed';
                window.__xsoNavOK = Date.now(); // app 自己要去的页面，防滑门卫放行（见 xso-guard.js）
                const failure = await Promise.race([router.replace(target), new Promise((r) => setTimeout(() => r('timeout'), 3000))]);
                // 同一个网址再搜一次（duplicated = 16）也算到了
                if (failure && failure.type !== 16) return 'failed';
                // 等新页面先画一帧，再收起原生首页，免得闪一下底下的网页（页面不画时最多等 0.1 秒）
                await new Promise((r) => { requestAnimationFrame(() => setTimeout(r)); setTimeout(r, 100); });
                return 'routed';
                """, arguments: ["target": target, "seq": seq], in: nil, in: .page) { done((try? $0.get()) as? String) }
        }
        return result.flatMap(RouteResult.init(rawValue:)) ?? .failed
    }

    /// 小红书的 AI 问答（点点）：也是带着问题来找答案，和搜索一样放行
    func openAIChat() { openWeb("https://www.xiaohongshu.com/ai_chat") }
    /// 「消息」= 小红书网页的通知页（评论、点赞、关注）
    func openNotifications() { openWeb("https://www.xiaohongshu.com/notification") }
    /// 「私信」= 小红书网页的私信页（会话列表，点进去是对话）。和 App 一样，点「消息」先看到私信
    func openChats() { openWeb("https://www.xiaohongshu.com/chat") }

    /// 「关掉个性化推荐」的提示：看过点「知道了」就不再显示
    @Published var recommendationTipDone = UserDefaults.standard.bool(forKey: "xso.recommendationTipDone") {
        didSet { UserDefaults.standard.set(recommendationTipDone, forKey: "xso.recommendationTipDone") }
    }

    /// 打开自己的主页（「我」），favorites 为 true 时直接到「收藏」标签。
    /// 用户 ID 从小红书网页自己的状态里取（登录后才有）
    func openProfile(favorites: Bool = false) async {
        guard let webView else { return }
        let id = try? await webView.callAsyncJavaScript("""
            \(Config.xhsRules)
            const user = XSO_RULES.user();
            return user?.loggedIn ? (user.userInfo?.userId ?? null) : null;
            """, contentWorld: .page) as? String
        guard let id else {
            searchStalled = true // 借用这个提示：没取到就让用户再试一次
            return
        }
        myUserID = id
        if favorites {
            // ?tab=fav 是小红书主页自己的参数；再留个记号，万一没生效就替用户点「收藏」（见 WebView）
            _ = try? await webView.callAsyncJavaScript("localStorage.setItem('xsoOpenFav', '1')", contentWorld: .page)
            openWeb("https://www.xiaohongshu.com/user/profile/\(id)?tab=fav")
        } else {
            openWeb("https://www.xiaohongshu.com/user/profile/\(id)")
        }
    }

    func search(_ query: String) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let url = Config.searchURL(query) else { return }
        guard webView != nil else {
            pendingQuery = query
            return
        }
        rememberRecent(query)
        syncPageSettings() // 保险：确保网页这边的开关和 app 里一致
        isSearching = true
        searchStalled = false
        // 卡住时网页窗口会被换新、自动重试（见 WebView 的跳转看门狗）；20 秒还不行就别一直显示「正在搜索」
        searchWatchdog?.cancel()
        searchWatchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard let self, !Task.isCancelled, self.isSearching else { return }
            #if DEBUG
            mark("search still not shown after 20s → give up")
            #endif
            self.isSearching = false
            self.searchStalled = true
        }
        go(to: url)
    }
}

@main
struct SearchOnlyApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var browser = Browser.shared
    @StateObject private var usage = UsageTimer.shared
    @Environment(\.scenePhase) private var scenePhase

    #if DEBUG
    init() {
        // 调试版：日志默认写进 Documents/console.log，平时自己用的时候出了问题，事后用 devicectl 取回来看（超过 2MB 就从头写）。
        // 用 devicectl --console 启动、想直接在电脑上看日志时加 `-logToFile NO`
        if UserDefaults.standard.flag("logToFile", default: true) {
            let path = URL.documentsDirectory.appending(path: "console.log").path
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            freopen(path, size > 2_000_000 ? "w" : "a", stdout)
            setvbuf(stdout, nil, _IOLBF, 0)
        }
        mark("app init")
        // 调试：`-listFonts YES` 打印几种中文字体在这台设备上有没有；再加 `-requestFonts 名字,名字` 试着让系统下载
        if UserDefaults.standard.bool(forKey: "listFonts") {
            let names = ["STSongti-SC-Regular", "STSongti-SC-Bold", "STSongti-SC-Black", "STSongti-SC-Light", "STKaitiSC-Regular",
                         "STYuanti-SC-Regular", "STYuanti-SC-Bold", "STFangsong", "STHeitiSC-Medium", "PingFangSC-Semibold"]
            mark("fonts " + names.map { "\($0)=\(UIFont(name: $0, size: 12) != nil)" }.joined(separator: " "))
            if let wanted = UserDefaults.standard.string(forKey: "requestFonts") {
                OnDemandFonts.shared.request(wanted.split(separator: ",").map(String.init))
                DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                    mark("fonts after 20s: " + OnDemandFonts.shared.ready.sorted().joined(separator: ","))
                }
            }
            mark("families " + UIFont.familyNames.filter { $0.contains("SC") || $0.contains("Song") || $0.contains("Kai") || $0.contains("Yuan") }.joined(separator: ", "))
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            XHSRoot(browser: browser)
            // 桌面 / 锁屏小组件打开 searchonly://search
            .onOpenURL { url in
                if url.scheme == "searchonly" { browser.showSearchHome() }
            }
            .onChange(of: scenePhase) { _, phase in
                #if DEBUG
                mark("app \(phase)")
                #endif
                if phase == .active {
                    browser.returnedFromScanning()
                    ClipboardLink.shared.check() // 复制了朋友发来的笔记链接再回来：顶上提示粘贴打开
                }
            }
            .overlay(alignment: .top) { ClipboardLinkBanner(clip: ClipboardLink.shared) }
            // 每日使用计时：只算在前台的时间
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { usage.becameActive() } else { usage.resignedActive() }
            }
            // 用到每日上限：盖一层安静的提醒（不是系统弹窗）
            .overlay {
                if usage.alertShown {
                    browser.style.usageReminder(usage) {
                        browser.showsSettings = true
                    }
                    .transition(.opacity)
                }
            }
            .animation(.quick, value: usage.alertShown)
            #if DEBUG
            .task { await UIDemo.run(browser: browser, usage: usage) }
            // 调试：`-appearance light`（或 dark）不管系统设置，强制用浅色 / 深色，网页也跟着
            .preferredColorScheme(UserDefaults.standard.string(forKey: "appearance").flatMap { $0 == "light" ? .light : $0 == "dark" ? .dark : nil })
            #endif
        }
    }
}

/// 整个 app 的界面：原生首页、网页、导航栏、设置
struct XHSRoot: View {
    @ObservedObject var browser: Browser

    var body: some View {
            VStack(spacing: 0) {
            #if NATIVE_SEARCH
            if browser.showsMessagesSwitcher { browser.style.messagesSwitcher(browser).grayscale(browser.grayscale ? 1 : 0) }
            if browser.showsResultsBar { browser.style.resultsBar(browser).grayscale(browser.grayscale ? 1 : 0) }
            #endif
            ZStack {
                WebView(url: browser.startURL, browser: browser)
                    .id(browser.webViewID) // 换 id = 换一个全新的网页窗口
                    .ignoresSafeArea(edges: .bottom)
                if let progress = browser.loadProgress, !browser.showsSearch {
                    browser.style.loadingBar(progress: progress)
                }
                #if NATIVE_SEARCH
                if browser.showsSearch { browser.style.home(browser).grayscale(browser.grayscale ? 1 : 0) }
                #endif
                // 放在顶部：底部是小红书登录框的手机号输入栏，不能挡住
                if browser.loginQR != nil && !browser.showsSearch && !browser.loginHelpDismissed {
                    browser.style.loginBanner(browser)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.quick, value: browser.loginQR != nil)
            #if NATIVE_SEARCH
            // 底部导航栏：原生首页和所有网页共用一个，和小红书 app 一样一直在（小红书网页自己的那排已经被脚本藏掉）
            if browser.showsTabBar { browser.style.tabBar(browser).grayscale(browser.grayscale ? 1 : 0) }
            #endif
            }
            // 没有原生顶栏的网页上，状态栏那一条露出的是这里的底色：用当前风格的网页底色，和网页接上
            .background(browser.style.webSkin.background.color.ignoresSafeArea())
            .ignoresSafeArea(.keyboard, edges: .bottom) // 键盘弹出时导航栏留在原地，不跟着往上顶
            #if NATIVE_SEARCH
            .sheet(isPresented: $browser.showsSettings) { browser.settingsStyle.settings(browser) }
            #endif
            .sheet(isPresented: $browser.showsLinkGuide) { LinkGuide() }
            // 防滑门卫拦下了一次「下一条」（见 xso-guard.js）
            .overlay(alignment: .top) { GuardNotice(text: browser.guardNotice) }
    }
}
