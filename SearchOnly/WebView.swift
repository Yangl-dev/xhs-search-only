import SwiftUI
import WebKit
import os

/// 只装小红书网页版的 WebView：页面一开始就注入「只留搜索」脚本，小红书以外的链接交给 Safari。
struct WebView: UIViewRepresentable {
    let url: URL
    let browser: Browser

    func makeCoordinator() -> Coordinator { Coordinator(browser: browser) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // 只拦有声音的自动播放。原来是 .all（静音的也要用户点过才准播）：笔记里左右滑不算「点」，
        // 翻过去的 Live 图一律不动。静音的视频笔记自己播起来时，xso-page.js 的「视频点了才播」照旧会当场暂停
        config.mediaTypesRequiringUserActionForPlayback = .audio

        // 和 Safari 里用的是同一个脚本文件，原样注入
        if let scriptURL = Bundle.main.url(forResource: "xhs-search-only.user", withExtension: "js"),
           let source = try? String(contentsOf: scriptURL, encoding: .utf8) {
            config.userContentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        // 隐藏样式一开始就插进页面（这时还没有任何内容），小红书的东西画出来之前就已经生效，不会先露一下再消失
        config.userContentController.addUserScript(.withRules("""
            const style = document.createElement('style');
            style.textContent = XSO_RULES.css;
            document.documentElement.append(style);
            // 一直是空白首页（开关 2026-11-22 删了）；以前关过开关的，网页里记的「关」也清掉，「只留搜索」脚本就照常拦
            localStorage.removeItem('xsoBlankHome');
            document.documentElement.setAttribute('data-xso-blank', '');
            if (localStorage.getItem('xsoGray') === '1') document.documentElement.setAttribute('data-xso-gray', '');
            if (localStorage.getItem('xsoBlur') === '1') document.documentElement.setAttribute('data-xso-blur', '');
            // 网页配色跟着界面风格走：每套风格的颜色、圆角、字体是一组变量（见 WebSkin），页面结构上的用法在 xhs-rules.js
            const skins = document.createElement('style');
            skins.textContent = \(WebSkin.allCSSLiteral);
            document.documentElement.append(skins);
            document.documentElement.setAttribute('data-xso-style', '\(browser.style.rawValue)');
            """, at: .atDocumentStart))
        // 去微信/小红书扫码期间，别让网页知道自己被切到了后台：小红书一看到「隐藏」就停止轮询「确认了吗」，
        // 在 iOS 上回来后也不再继续，用户确认了也登录不进去。app 在跳出去之前打开这个开关，登录完再关掉。
        config.userContentController.addUserScript(WKUserScript(source: """
            (() => {
              const proto = Document.prototype;
              const hidden = Object.getOwnPropertyDescriptor(proto, 'hidden');
              const state = Object.getOwnPropertyDescriptor(proto, 'visibilityState');
              Object.defineProperty(proto, 'hidden', { configurable: true,
                get() { return window.__xsoKeepVisible ? false : hidden.get.call(this); } });
              Object.defineProperty(proto, 'visibilityState', { configurable: true,
                get() { return window.__xsoKeepVisible ? 'visible' : state.get.call(this); } });
              for (const type of ['visibilitychange', 'pagehide', 'blur', 'freeze']) {
                addEventListener(type, (e) => {
                  if (window.__xsoKeepVisible && (e.target === window || e.target === document)) e.stopImmediatePropagation();
                }, true);
              }
            })();
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        // 防滑门卫：笔记只能是自己点开的，网页自己换到下一条就退回去（见 xso-guard.js）
        if let guardScript = WKUserScript.guardScript() {
            config.userContentController.addUserScript(guardScript)
            config.userContentController.add(context.coordinator, name: "xsoGuard")
        }
        // 打开收藏、扫码检测、筛选、Live 图这几个小帮手都在 xso-page.js 里，页面解析完才开始
        config.userContentController.add(context.coordinator, name: "xsoScan")
        config.userContentController.add(context.coordinator, name: "xsoReady")
        config.userContentController.add(context.coordinator, name: "xsoGoHome")
        if let pageURL = Bundle.main.url(forResource: "xso-page", withExtension: "js"),
           let source = try? String(contentsOf: pageURL, encoding: .utf8) {
            config.userContentController.addUserScript(.withRules(source, at: .atDocumentEnd))
        }
        #if NATIVE_SEARCH
        // 脚本会在网页里的搜索框出现或撤掉时发消息过来，原生搜索页跟着显示或隐藏
        config.userContentController.add(context.coordinator, name: "xsoGate")
        #endif
        #if INSTANT_GATE
        // 改法 B：WebKit 在页面上字太少（不到约 200 个）时先不画，要等整页解析完。
        // 往网页搜索框背后塞一段几乎透明的字凑够门槛，让它一插进页面就能画出来。
        config.userContentController.addUserScript(WKUserScript(source: """
            const pad = document.createElement('div');
            pad.setAttribute('aria-hidden', 'true');
            pad.style.cssText = 'position:absolute;inset:0;z-index:-1;overflow:hidden;font-size:12px;' +
              'color:rgba(127,127,127,0.01);pointer-events:none;user-select:none;-webkit-user-select:none';
            pad.textContent = '搜'.repeat(300);
            document.getElementById('xso-gate')?.append(pad);
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        #endif

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = Config.desktopUserAgent
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // 侧滑返回自己接管（见 Browser.goBack）：系统自带的手势只会按网页的历史一页页退，
        // 而站内跳转会把「我、消息、问 AI」都记进历史，退起来就在几个栏目之间乱跳
        webView.allowsBackForwardNavigationGestures = false
        let backSwipe = UIScreenEdgePanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.backSwiped(_:)))
        backSwipe.edges = .left
        backSwipe.delegate = context.coordinator
        webView.addGestureRecognizer(backSwipe)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(browser.style.webSkin.background.color) // 网页还没画出来时露出的底色
        #if DEBUG
        webView.isInspectable = true // 连上 Mac 后可以在 Safari「开发」菜单里调试。只在调试版开：正式版开着的话，接上 Mac 就能读到小红书的登录 cookie
        #endif

        // 没有地址栏，下拉刷新是页面卡住时唯一的重来办法
        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.reload(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        context.coordinator.sidewaysLock = webView.scrollView.lockSideways()

        #if DEBUG
        // 调试：把网址变化（含站内跳转）和页面报错打到控制台，
        // 用 `xcrun devicectl device process launch --console` 启动就能看到。网址只记域名和路径（`URL.forLog`），搜索词、xsec_token 这些参数不记。
        config.userContentController.add(context.coordinator, name: "log")
        // 调试：网页里的脚本发 `webkit.messageHandlers.snap.postMessage('名字')`，就把整个屏幕（原生界面 + 网页）存成 Documents/shot-名字.jpg
        config.userContentController.add(context.coordinator, name: "snap")
        config.userContentController.addUserScript(.withRules("""
            const log = (m) => webkit.messageHandlers.log.postMessage(String(m));
            addEventListener('error', (e) => log('js error: ' + e.message));
            // 启动时间线：毫秒时间戳，和 Swift 那边打的 [time] 对得上。这段紧跟在「只留搜索」脚本后面运行
            const at = (t) => Math.round(performance.timeOrigin + t);
            log(`time ${at(performance.now())} script start (search box inserted) ${location.pathname}`);
            new PerformanceObserver((list) => list.getEntries().forEach((e) => log(`time ${at(e.startTime)} ${e.name}`)))
              .observe({ type: 'paint', buffered: true });
            addEventListener('DOMContentLoaded', () => log(`time ${at(performance.now())} DOMContentLoaded`));
            // 登录相关的接口（只记路径和耗时，不记参数和内容），以及页面前后台切换
            new PerformanceObserver((list) => list.getEntries()
              .filter((e) => /qrcode|login|\\/user\\/me/.test(e.name))
              .forEach((e) => log(`time ${at(e.responseEnd)} api ${new URL(e.name).pathname} took ${Math.round(e.duration)}ms`)))
              .observe({ type: 'resource' });
            document.addEventListener('visibilitychange', () => log(`time ${at(performance.now())} page ${document.visibilityState}`));
            addEventListener('load', () => {
              const n = performance.getEntriesByType('navigation')[0] || {};
              log(`time ${at(n.requestStart)} html request sent`);
              log(`time ${at(n.responseStart)} html first byte`);
              log(`time ${at(n.responseEnd)} html done ${Math.round((n.transferSize || 0) / 1024)}KB`);
              log(`time ${at(performance.now())} load event`);
            });
            // 启动参数 `-stateLog YES` 时，每 2 秒看一次屏幕上大概是什么（网址、搜索框在不在、笔记卡片数、页面文字长度），
            // 有变化才报。会读整页文字、逼网页重新排版，平时不开
            let ticks = 0, last = '';
            const state = () => {
              const gate = document.getElementById('xso-gate'), r = gate?.getBoundingClientRect(), ms = Math.round;
              const s = `state ${location.pathname} gate=${gate ? ms(r.width) + 'x' + ms(r.height) : 'none'} ` +
                  `body=${document.body ? getComputedStyle(document.body).display : '-'} ` +
                  `notes=${document.querySelectorAll(XSO_RULES.noteCard).length} text=${(document.body?.innerText || '').length} ` +
                  `app=${ms(document.querySelector(XSO_RULES.appRoot)?.getBoundingClientRect().width ?? -1)} ` +
                  `els=${document.body?.getElementsByTagName('*').length ?? 0} login=${!!document.querySelector(XSO_RULES.loginBox)} ` +
                  `searchApi=${performance.getEntriesByType('resource').filter((e) => e.name.includes('/search/notes'))
                    .map((e) => ms(e.startTime) + '→' + ms(e.responseEnd)).join(',') || 0}`;
              if (s !== last) log(last = s);
              if (++ticks < 60) setTimeout(state, 2000);
            };
            if (\(UserDefaults.standard.bool(forKey: "stateLog"))) setTimeout(state, 2000);
            // 页面加载 8 秒后报一次耗时：整页时间线、各域名的请求量、接口的起止时间（只有路径，不含参数）。
            // 小红书会清空浏览器的请求记录，所以边加载边自己记
            const seen = [];
            new PerformanceObserver((list) => seen.push(...list.getEntries())).observe({ type: 'resource', buffered: true });
            addEventListener('load', () => setTimeout(() => {
              const ms = Math.round, nav = performance.getEntriesByType('navigation')[0] || {};
              const res = seen, hosts = {};
              for (const e of res) {
                const h = hosts[new URL(e.name).host + ' ' + e.initiatorType] ||= { n: 0, kb: 0, slowest: 0, end: 0 };
                h.n++; h.kb += (e.transferSize || 0) / 1024; h.slowest = Math.max(h.slowest, e.duration); h.end = Math.max(h.end, e.responseEnd);
              }
              log(`perf ${location.pathname} ttfb=${ms(nav.responseStart)} domReady=${ms(nav.domContentLoadedEventEnd)} load=${ms(nav.loadEventEnd)} requests=${res.length}`);
              for (const [host, h] of Object.entries(hosts)) log(`perf host ${host} n=${h.n} kb=${ms(h.kb)} slowest=${ms(h.slowest)} lastEnd=${ms(h.end)}`);
              for (const e of res.filter((e) => e.name.includes('/api/')))
                log(`perf api ${ms(e.startTime)}→${ms(e.responseEnd)} ${new URL(e.name).pathname}`);
            }, 8000));
            """, at: .atDocumentStart))
        // 调试：网页比屏幕宽时（能被左右拖的那种 bug），记下是哪几个元素撑出去的，好找到根源。
        // 每 3 秒看一眼整页宽度，宽度变了才逐个元素量一遍，量的只是位置和 class，不读内容
        config.userContentController.addUserScript(WKUserScript(source: """
            (() => {
              let lastWidth = 0;
              setInterval(() => {
                const root = document.documentElement, width = root.scrollWidth, screen = root.clientWidth;
                if (width === lastWidth) return;
                lastWidth = width;
                if (width <= screen + 1) return;
                const wide = [];
                for (const el of document.querySelectorAll('body *')) {
                  const r = el.getBoundingClientRect();
                  if (r.width === 0 || r.right <= screen + 1 || wide.some((p) => p.contains(el))) continue;
                  let clipped = false;
                  for (let p = el.parentElement; p && p !== document.body; p = p.parentElement) {
                    if (getComputedStyle(p).overflowX !== 'visible' && p.getBoundingClientRect().right <= screen + 1) { clipped = true; break; }
                  }
                  if (!clipped) wide.push(el);
                  if (wide.length >= 5) break;
                }
                const name = (el) => el.tagName.toLowerCase() + '.' + String(el.className?.baseVal ?? el.className).trim().split(/\\s+/).slice(0, 3).join('.');
                webkit.messageHandlers.log.postMessage(`too wide ${location.pathname} ${width}>${screen} scale=${visualViewport.scale.toFixed(2)} ` +
                  wide.map((el) => `${name(el)}<${name(el.parentElement)} R=${Math.round(el.getBoundingClientRect().right)}`).join(' | '));
              }, 3000);
            })();
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        // 调试：启动参数 `-autoSearch <词>` 会在首页搜索框出现 8 秒后自动搜这个词，方便不碰手机就复现搜索
        if let query = UserDefaults.standard.string(forKey: "autoSearch"),
           let json = try? JSONEncoder().encode(query), let literal = String(data: json, encoding: .utf8) {
            config.userContentController.addUserScript(WKUserScript(source: """
                setTimeout(() => {
                  const input = document.querySelector('#xso-gate input');
                  if (input) {
                    webkit.messageHandlers.log.postMessage('autoSearch submit at ' + Math.round(performance.now()));
                    input.value = \(literal); input.form.requestSubmit();
                  }
                }, 8000);
                """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        // 调试：启动参数 `-hangPageAfter <秒>` 让网页死循环卡住，用来测试跳转看门狗（只在第一个网页窗口里做）
        let hangAfter = UserDefaults.standard.double(forKey: "hangPageAfter")
        if hangAfter > 0, browser.webViewID == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + hangAfter) { [weak webView] in
                mark("debug: freeze page")
                webView?.evaluateJavaScript("setTimeout(() => { for (;;) {} }, 0)")
            }
        }
        // 调试：启动参数 `-openFavoritesAfter <秒>` 会在指定秒数后点一下「我的收藏」
        let favoritesAfter = UserDefaults.standard.double(forKey: "openFavoritesAfter")
        if favoritesAfter > 0, browser.webViewID == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + favoritesAfter) { [browser] in
                mark("debug: open favorites")
                Task { await browser.openProfile(favorites: true) }
            }
        }
        // 调试：启动参数 `-nativeSearch <词> -nativeSearchDelay <秒>` 会在指定秒数后走原生搜索框的搜索流程
        if let query = UserDefaults.standard.string(forKey: "nativeSearch"), browser.webViewID == 0 {
            let delay = max(UserDefaults.standard.double(forKey: "nativeSearchDelay"), 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [browser] in
                mark("debug native search")
                browser.search(query)
            }
        }
        // 调试：`-debugJS <脚本> -debugJSAfter <秒>` 在指定秒数后在网页里执行一段脚本（算用户点的）；
        // `-goBackAfter <秒>` 在指定秒数后返回上一页（和侧滑返回一样）
        // 调试：`-debugJSFile <文件名> -debugJSAfter <秒>` 同上，但脚本从 app 的 Documents 里读（先用 devicectl 拷进去），长脚本不用挤进启动参数
        if let name = UserDefaults.standard.string(forKey: "debugJSFile"), browser.webViewID == 0,
           let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let js = try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8) {
            DispatchQueue.main.asyncAfter(deadline: .now() + UserDefaults.standard.double(forKey: "debugJSAfter")) { [weak webView] in
                mark("debug: run js file \(name)")
                webView?.evaluateJavaScript(js)
            }
        }
        // 调试：`-keepAwake YES` 让手机在 app 开着时不自动锁屏，方便连续在真机上测
        if UserDefaults.standard.bool(forKey: "keepAwake") { UIApplication.shared.isIdleTimerDisabled = true }
        if let js = UserDefaults.standard.string(forKey: "debugJS"), browser.webViewID == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + UserDefaults.standard.double(forKey: "debugJSAfter")) { [weak webView] in
                mark("debug: run js")
                webView?.evaluateJavaScript(js)
            }
        }
        // 调试：`-openURL <网址> -openURLAfter <秒>` 走底部导航栏同一条路打开一个页面
        if let address = UserDefaults.standard.string(forKey: "openURL"), let target = URL(string: address), browser.webViewID == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + UserDefaults.standard.double(forKey: "openURLAfter")) { [browser] in
                mark("debug: open \(target.path)")
                browser.open(target)
            }
        }
        let backAfter = UserDefaults.standard.double(forKey: "goBackAfter")
        if backAfter > 0, browser.webViewID == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + backAfter) { [browser] in
                mark("debug: go back")
                browser.goBack()
            }
        }
        if UserDefaults.standard.bool(forKey: "snapshots") {
            Timer.scheduledTimer(timeInterval: 4, target: context.coordinator,
                                 selector: #selector(Coordinator.snapshot(_:)), userInfo: nil, repeats: true)
        }
        context.coordinator.urlObservation = webView.observe(\.url, options: .new) { webView, _ in
            print("[url]", webView.url?.forLog ?? "nil")
        }
        #endif

        context.coordinator.webView = webView
        browser.webView = webView
        // 跟踪网址（含站内跳转），用来判断是否刚从登录页登录成功
        context.coordinator.pathObservation = webView.observe(\.url, options: [.old, .new]) { [browser] _, change in
            let old = change.oldValue??.path, new = change.newValue??.path, url = change.newValue ?? nil
            Task { @MainActor in
                browser.pathChanged(from: old, to: new)
                browser.urlChanged(to: url)
            }
        }
        // 整页加载时顶上的细进度条跟着网页自己估的进度走（站内跳转不触发，也用不着）
        context.coordinator.progressObservation = webView.observe(\.estimatedProgress, options: .new) { [browser] webView, _ in
            let progress = webView.estimatedProgress
            Task { @MainActor in browser.loadProgressed(progress) }
        }
        #if DEBUG
        mark("webview created, load requested")
        #endif
        webView.load(URLRequest(url: url))
        // 冷启动时 Siri / 最近搜索排队的搜索，等这一轮界面更新完再发
        DispatchQueue.main.async { [browser] in browser.webViewReady() }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // 换新网页窗口时，旧的要彻底拆掉，免得它（和它卡死的网页进程）留在内存里
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.pathObservation = nil
        coordinator.progressObservation = nil
        coordinator.sidewaysLock = nil
        webView.stopLoading()
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UIGestureRecognizerDelegate {
        weak var webView: WKWebView?

        /// 从屏幕左边缘往右滑：滑够一段距离（或甩得够快）松手就算「返回」
        @objc func backSwiped(_ swipe: UIScreenEdgePanGestureRecognizer) {
            guard swipe.state == .ended, let view = swipe.view else { return }
            if swipe.translation(in: view).x > 70 || swipe.velocity(in: view).x > 500 {
                #if DEBUG
                mark("back swipe")
                #endif
                browser.goBack()
            }
        }

        /// 和网页自己的滚动、点按并存，不抢它们的手势
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
        let browser: Browser
        var pathObservation: NSKeyValueObservation?
        var progressObservation: NSKeyValueObservation?
        var sidewaysLock: NSKeyValueObservation?

        init(browser: Browser) { self.browser = browser }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "xsoGate":
                browser.showsSearch = message.body as? Bool ?? true
                if !browser.showsSearch { browser.searchPageShown() }
                #if DEBUG
                mark("web search box \(browser.showsSearch ? "shown" : "removed") → native search home \(browser.showsSearch ? "on" : "off")")
                #endif
            case "xsoScan":
                #if DEBUG
                mark("page mentions 扫码: \(message.body)")
                #endif
                browser.setScanPromptVisible(message.body as? Bool ?? false)
            case "xsoReady":
                browser.pageReady()
                browser.syncPageSettings() // 第一次打开时网页的 localStorage 里还没有这些开关
            case "xsoGuard":
                #if DEBUG
                mark("guard blocked → \(message.body)")
                #endif
                browser.noteBlocked()
            case "xsoGoHome":
                // 网页里的链接想去推荐流，被拦下了：显示原生搜索首页（不弹键盘）
                browser.showsSearch = true
            #if DEBUG
            case "log":
                print("[js]", message.body)
            case "snap":
                if let name = message.body as? String, let window = webView?.window {
                    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
                    }
                    // 存成 PNG：截图要拿去放 README 和发帖，JPEG 压过以后字边上会糊
                    try? image.pngData()?.write(to: URL.documentsDirectory.appending(path: "shot-\(name).png"))
                    mark("saved shot-\(name).png")
                }
            #endif
            default:
                break
            }
        }

        // app 在后台时 iOS 可能回收网页进程，回来就是一张死掉的旧画面；重新加载才能恢复。
        // 在后台被回收的，等回到前台再加载：后台加载了没人看，还可能加载完又被回收，白费流量和电
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard UIApplication.shared.applicationState != .active else {
                #if DEBUG
                mark("web content process terminated → reload")
                #endif
                webView.reload()
                return
            }
            #if DEBUG
            mark("web content process terminated in background → reload when back")
            #endif
            guard reloadWhenActive == nil else { return }
            reloadWhenActive = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self, weak webView] _ in
                MainActor.assumeIsolated {
                    if let observer = self?.reloadWhenActive { NotificationCenter.default.removeObserver(observer) }
                    self?.reloadWhenActive = nil
                    webView?.reload()
                }
            }
        }
        private var reloadWhenActive: NSObjectProtocol?

        // 跳转看门狗在 Browser.watchLoad：小红书自己发起的跳转（比如登录后跳首页）从这里开始计时
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            #if DEBUG
            mark("start loading \(webView.url?.path ?? "")")
            #endif
            if let url = webView.url { browser.watchLoad(of: url) }
            browser.loadStarted()
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            browser.loadSettled()
            #if DEBUG
            mark("commit \(webView.url?.path ?? "")")
            #endif
        }

        // 进度条的兜底：页面开始显示以后又失败（比如被新的跳转打断）也收起，不会停在半截
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            browser.pageReady()
            #if DEBUG
            print("[nav] failed after commit", error.localizedDescription)
            #endif
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            browser.loadSettled()
            browser.isSearching = false
            browser.pageReady()
            #if DEBUG
            print("[nav] failed", error.localizedDescription)
            #endif
        }
        #if DEBUG
        var urlObservation: NSKeyValueObservation?
        var snapshotCount = 0

        // 调试：启动参数 `-snapshots YES` 时每 4 秒给网页截一张图，存到 app 的 Documents，最多 12 张
        @objc func snapshot(_ timer: Timer) {
            snapshotCount += 1
            guard let webView, snapshotCount <= 12 else { return timer.invalidate() }
            let file = URL.documentsDirectory.appending(path: "snap-\(snapshotCount).jpg")
            webView.takeSnapshot(with: nil) { image, _ in
                try? image?.jpegData(compressionQuality: 0.6)?.write(to: file)
            }
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            mark("server redirect → \(webView.url?.forLog ?? "")")
        }

        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if response.isForMainFrame {
                mark("response \((response.response as? HTTPURLResponse)?.statusCode ?? 0) \(response.response.url?.path ?? "")")
            }
            return .allow
        }

        #endif

        // 进度条一般在页面解析完时收起（xso-page.js 通知）；从返回缓存里整页恢复的页面不会再跑脚本，这里兜底
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            browser.pageReady()
            #if DEBUG
            mark("finish \(webView.url?.path ?? "")")
            #endif
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            // 页面里嵌的框架（比如安全验证）不管
            if action.targetFrame?.isMainFrame == false { return .allow }
            #if DEBUG
            print("[nav]", Self.isAllowed(url) ? "allow" : "block", url.forLog)
            #endif
            // 小红书有的重定向会把 https 换成 http，iOS 不让 app 加载 http，换回 https 再打开
            if url.scheme == "http", Self.isAllowed(url),
               var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                parts.scheme = "https"
                if let secure = parts.url { webView.load(URLRequest(url: secure)) }
                return .cancel
            }
            // 整页打开 /discovery/item/<id>、/search_result/<id> 这两种笔记网址（朋友分享的长链、xhslink 短链重定向过来的）时，
            // 小红书网页一启动就会把网址改成 /explore/<同一个id>。防滑门卫按路径认笔记，会当成「网页自己换到了另一条」退回去，
            // 退回去又被改写，整页无限刷新。所以整页打开时直接换成 /explore/<id>（参数原样带上），网页就不会再改网址
            if let canonical = Self.canonicalNoteURL(url) {
                #if DEBUG
                mark("note url \(url.path) → \(canonical.path)")
                #endif
                webView.load(URLRequest(url: canonical))
                return .cancel
            }
            if Self.isAllowed(url) { return .allow }
            // 没登录时，小红书服务器会把笔记页整页转去海外版 www.rednote.com（模拟器里未登录打开笔记链接发现的）。
            // 那不在放行名单里，以前直接丢掉，结果白屏。换回小红书的同一个网址，先去登录，登录好了再打开它
            if let home = Self.fromRednote(url) {
                #if DEBUG
                mark("redirected to rednote → login first, then \(home.path)")
                #endif
                browser.redirectedAbroad(home)
                return .cancel
            }
            // 别的网站：只有用户真点了链接才交给 Safari，并去掉追踪参数；页面自己发起的跳转
            // （自动跳 App Store、xhsdiscover:// 这类唤起小红书 app 的）一律不理
            if action.navigationType == .linkActivated {
                openOutside(url)
            } else {
                #if DEBUG
                mark("ignored automatic jump to \(url.scheme ?? "")://\(url.host ?? "")")
                #endif
            }
            return .cancel
        }

        private func openOutside(_ url: URL) {
            guard url.scheme == "https" || url.scheme == "http" else { return }
            let clean = Config.withoutTracking(url)
            #if DEBUG
            mark("open in Safari: \(clean.forLog)")
            #endif
            UIApplication.shared.open(clean)
        }

        // target="_blank" 的链接（比如搜索结果里的作者）在当前页面打开，不新开窗口：
        // 小红书自己的页面走站内跳转，不整页刷新；别的网站照常交给上面的 decidePolicyFor（去 Safari）
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard action.targetFrame == nil else { return nil }
            guard let url = action.request.url else { return nil }
            if Self.isAllowed(url), url.scheme == "https" {
                browser.open(url)
            } else if !Self.isAllowed(url) {
                // 新窗口只会因为用户点了链接才开（网页不能自己弹窗），所以直接交给 Safari
                openOutside(url)
            } else {
                webView.load(action.request)
            }
            return nil
        }

        @objc func reload(_ sender: UIRefreshControl) {
            // 卡死的网页里重新加载不会有反应，所以从这里就开始计时，5 秒没反应就换新窗口
            if let url = webView?.url { browser.watchLoad(of: url) }
            webView?.reload()
            sender.endRefreshing()
        }

        /// 笔记的另外两种网址换成 /explore/<id>（小红书网页自己用的那种）；不是这两种就返回 nil
        static func canonicalNoteURL(_ url: URL) -> URL? {
            guard url.host?.lowercased() == "www.xiaohongshu.com",
                  let match = url.path.firstMatch(of: /^\/(?:discovery\/item|search_result)\/([0-9a-f]{24})\/?$/),
                  var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            parts.scheme = "https"
            parts.path = "/explore/\(match.1)"
            return parts.url
        }

        static func isAllowed(_ url: URL) -> Bool {
            guard url.scheme == "https" || url.scheme == "http", let host = url.host?.lowercased() else { return false }
            return Config.allowedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
        }

        /// rednote.com 的网址换回 www.xiaohongshu.com 上同一个路径和参数；不是 rednote 的返回 nil。
        /// 换法只在 Config.canonical 一处（「打开链接」也用它）
        static func fromRednote(_ url: URL) -> URL? {
            let home = Config.canonical(url)
            return home == url ? nil : home
        }
    }
}

extension WKUserScript {
    /// 用到小红书页面结构的网页脚本：前面拼上 xhs-rules.js，脚本里用 XSO_RULES 取选择器。
    /// 包在一对大括号里，XSO_RULES 只在这段脚本里可见，不会挂到网页的全局变量上
    static func withRules(_ source: String, at time: WKUserScriptInjectionTime) -> WKUserScript {
        WKUserScript(source: "{\n\(Config.xhsRules)\n\(source)\n}", injectionTime: time, forMainFrameOnly: true)
    }
}

#if DEBUG
/// 调试：打一个毫秒时间戳，和网页里 `time` 开头的日志对得上。
/// 同时写进系统日志：模拟器里 print 会被缓冲，用 `xcrun simctl spawn <模拟器> log stream --predicate 'subsystem == "<app 的 bundle id>"'`
/// 能实时看
func mark(_ what: String) {
    let time = Int((Date().timeIntervalSince1970 * 1000).rounded())
    print("[time]", time, what)
    debugLog.notice("[time] \(time) \(what, privacy: .public)")
}
private let debugLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "searchonly", category: "debug")

extension URL {
    /// 调试日志里的网址：只要域名和路径。搜索词、xsec_token 都在参数里，不记
    var forLog: String { (host ?? "") + path }
}
#endif

extension UIScrollView {
    /// 网页只能上下滑：没放大时，横向位置一直钉在最左边。网页里偶尔有东西比屏幕宽（小红书电脑版网页在窄屏上会这样），
    /// 不管是哪个元素，页面都不会被拖得左右晃；双指放大以后照常能左右移动看。返回的观察要一直留着，丢掉就失效
    func lockSideways() -> NSKeyValueObservation {
        observe(\.contentOffset) { scrollView, _ in
            MainActor.assumeIsolated {
                let left = -scrollView.adjustedContentInset.left
                guard scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01, abs(scrollView.contentOffset.x - left) > 0.5 else { return }
                scrollView.contentOffset.x = left
            }
        }
    }
}

extension WKUserScript {
    /// 防滑门卫（xso-guard.js），前面拼上内容页规则。包在大括号里，不往网页的全局变量里放东西
    static func guardScript() -> WKUserScript? {
        guard let file = Bundle.main.url(forResource: "xso-guard", withExtension: "js"),
              let source = try? String(contentsOf: file, encoding: .utf8),
              let json = try? JSONEncoder().encode(Config.contentPattern),
              let pattern = String(data: json, encoding: .utf8) else { return nil }
        return WKUserScript(source: "{\nconst XSO_GUARD_CONTENT = \(pattern);\n\(source)\n}",
                            injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }
}
