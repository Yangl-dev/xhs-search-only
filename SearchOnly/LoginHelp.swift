import Photos
import SwiftUI
import Vision
import WebKit

// 小红书登录有时要求扫码确认（新设备风控），但用户可能只有这一台手机。
// 这里的做法：网页上出现「扫码」字样时，定时给网页截图、用 Vision 找二维码；
// 找到就弹出提示（界面在各套设计的 LoginBanner 里），让用户选用微信或小红书 app 确认：一点就把二维码存进相册并打开那个 app，
// 用户在它的「扫一扫」里从相册选图确认。不依赖小红书的页面结构，只看屏幕上有没有二维码。
// （二维码内容是 xiaohongshu.com/mobile/login?qrId=…，不在小红书 app 的通用链接里，没法直接跳进确认页。）

/// 用来扫码确认登录的 app
enum ScanApp {
    case weChat, xiaohongshu

    var name: String {
        switch self {
        case .weChat: "微信"
        case .xiaohongshu: "小红书"
        }
    }

    /// 这个 app 自己的品牌色，按钮用它，一眼认得出是哪个
    var tint: Color {
        switch self {
        case .weChat: Color(hex: 0x07C160)
        case .xiaohongshu: WebPage.red
        }
    }

    /// 依次尝试打开：先试直接到扫一扫（非公开的跳转，不一定有效），不行就只打开 app
    var schemes: [String] {
        switch self {
        case .weChat: ["weixin://scanqrcode", "weixin://"]
        case .xiaohongshu: ["xhsdiscover://"]
        }
    }

    var steps: String {
        switch self {
        case .weChat: "在微信点「扫一扫」→ 相册，选最新的一张，确认登录后回到这里。"
        case .xiaohongshu: "在小红书首页左上角菜单里点「扫一扫」→ 相册，选最新的一张，确认登录后回到这里。"
        }
    }
}

enum LoginHelpStatus {
    case ready, saved(ScanApp), failed(String)
}

extension Browser {
    /// 脚本告诉我们页面文字里有没有「扫码」，有才开始找二维码，没有就停（不白白耗电）
    func setScanPromptVisible(_ visible: Bool) {
        #if DEBUG
        if UIDemo.state == "login" { return } // 截图时提示条是摆出来的，别让真的检测把它收走
        #endif
        scanPromptVisible = visible
        qrScanTimer?.invalidate()
        qrScanTimer = nil
        guard visible else {
            loginQR = nil
            loginQRPayload = nil
            loginHelpStatus = .ready
            loginHelpDismissed = false
            setKeepPageVisible(false)
            return
        }
        // 被盖住的首页底下弹出了登录框 = 没登录：先带去登录页，登录好了再搜索
        if showsSearch {
            requireLogin()
            return
        }
        // 只要页面上有登录二维码就先对它隐藏「切到后台」：不管用户是点我们的按钮、
        // 自己截图，还是拿别的设备扫，回来时小红书都还在轮询，不会停在扫码页
        setKeepPageVisible(true)
        scheduleQRScan(every: 2)
        findLoginQR()
    }

    /// 找二维码的节奏：还没找到时 2 秒一次（页面刚出来要尽快拿到）；找到以后 6 秒一次就够了，
    /// 只为发现二维码过期换了新的。每次都要截整页再识别，太勤了费电
    private func scheduleQRScan(every seconds: TimeInterval) {
        guard qrScanTimer?.timeInterval != seconds else { return }
        qrScanTimer?.invalidate()
        let timer = Timer(timeInterval: seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.findLoginQR() }
        }
        timer.tolerance = seconds / 4
        RunLoop.main.add(timer, forMode: .common)
        qrScanTimer = timer
    }

    private func findLoginQR() {
        // 原生搜索页盖着时网页看不见，不用找
        guard scanPromptVisible, !showsSearch, let webView else { return }
        webView.takeSnapshot(with: nil) { [weak self] image, _ in
            guard let cgImage = image?.cgImage else { return }
            Task.detached(priority: .utility) {
                let qr = Self.qrCode(in: cgImage)
                await MainActor.run {
                    guard let self, self.scanPromptVisible else { return }
                    #if DEBUG
                    if (qr != nil) != (self.loginQR != nil) { mark(qr != nil ? "login QR found" : "login QR gone") }
                    #endif
                    self.scheduleQRScan(every: qr == nil ? 2 : 6)
                    // 同一个二维码不重新赋值（每次赋值整个界面都要跟着重算一遍）；内容认不出来时照旧换图
                    if let qr, qr.payload != nil, qr.payload == self.loginQRPayload, self.loginQR != nil { return }
                    self.loginQRPayload = qr?.payload
                    self.loginQR = qr.map { UIImage(cgImage: $0.image) }
                }
            }
        }
    }

    /// 在截图里找二维码，裁出来时四周多留一点白边，方便扫码识别
    nonisolated static func qrCode(in image: CGImage) -> (image: CGImage, payload: String?)? {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try? VNImageRequestHandler(cgImage: image).perform([request])
        guard let found = request.results?.first else { return nil }
        let box = found.boundingBox
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let rect = CGRect(x: box.minX * width, y: (1 - box.maxY) * height, width: box.width * width, height: box.height * height)
        guard let cropped = image.cropping(to: rect.insetBy(dx: -rect.width * 0.15, dy: -rect.height * 0.15).integral) else { return nil }
        return (cropped, found.payloadStringValue)
    }

    /// 扫码期间对网页隐藏「切到后台」的信号，让小红书一直轮询登录结果
    func setKeepPageVisible(_ on: Bool) {
        webView?.evaluateJavaScript("window.__xsoKeepVisible = \(on)")
    }

    /// 从微信/小红书扫完码回来：再给网页发一次「回到前台」的信号，保险起见让它马上再查一次登录结果
    func returnedFromScanning() {
        guard scanPromptVisible, !showsSearch else { return }
        #if DEBUG
        mark("back from scanning → nudge page")
        #endif
        webView?.evaluateJavaScript("dispatchEvent(new Event('focus')); document.dispatchEvent(new Event('visibilitychange'))")
    }

    /// 提示条上的说明文字，跟着进度变：还没点、已存进相册、出错了
    var loginHelpMessage: String {
        switch loginHelpStatus {
        case .ready:
            "只有这一台手机也可以：选一个 app，二维码会存进相册并打开它，在它的「扫一扫」里从相册选这张图确认就行。"
        case .saved(let app):
            "二维码已存进相册。\(app.steps)二维码一两分钟就过期，失败了就再点一次。"
        case .failed(let reason):
            reason
        }
    }

    func saveLoginQR(andOpen app: ScanApp) async {
        guard let qr = loginQR else { return }
        let access = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard access == .authorized || access == .limited else {
            loginHelpStatus = .failed("没有存相册的权限。可以在「设置 → \(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "只搜") → 照片」里打开，或者自己截图后在\(app.name)里扫。")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: qr) }
        } catch {
            loginHelpStatus = .failed("存进相册失败，可以自己截图后在\(app.name)「扫一扫」里从相册选。")
            return
        }
        loginHelpStatus = .saved(app)
        setKeepPageVisible(true) // 跳出去之前打开，见 WebView.swift
        for scheme in app.schemes {
            if let url = URL(string: scheme), await UIApplication.shared.open(url) { return }
        }
        loginHelpStatus = .failed("二维码已存进相册，但没找到\(app.name)。可以换另一个 app 试试。")
    }
}
