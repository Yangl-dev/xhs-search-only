import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 朋友发来的小红书笔记，复制链接后打开只搜就能看（2026-11-22，用户选的做法）。
/// 只搜收不到别的 App 里点开的小红书链接（那些网址归小红书，不归只搜），所以换个路子：
/// 回到只搜时，系统说剪贴板里「像是有网址」，就在顶上浮一条提示，上面是系统自带的「粘贴」按钮。
/// - 只问系统「有没有像网址的东西」，不读内容：这一步不会弹「允许粘贴」，也不知道剪贴板里具体是什么。
/// - 用户点了「粘贴」按钮才真正读，这是系统的按钮，点了就算同意，同样不弹窗。读到的只拿来找小红书链接，不存。
/// - 同一份剪贴板只提示一次（看系统的剪贴板编号），不管点没点、关没关，复制了新东西才会再提示
@MainActor
final class ClipboardLink: ObservableObject {
    static let shared = ClipboardLink()

    /// 顶上的提示显示着
    @Published private(set) var offered = false
    /// 粘贴的不是小红书链接时，提示换成这句话，过一会儿自己收起
    @Published private(set) var problem: String?

    private static let seenKey = "xso.clipboardSeen"
    private var hideTask: Task<Void, Never>?

    init() {
        #if DEBUG
        // 调试：`-openLinkText <一段分享文字>` 启动 2 秒后走「粘贴」同一条路
        if let text = UserDefaults.standard.string(forKey: "openLinkText") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                mark("debug: open link text")
                Self.open(text)
            }
        }
        #endif
    }

    /// 从一段文字里找出网址（各 App 的「复制链接」常常是「标题 + 网址 + 一句话」），是小红书的就在只搜里打开。认不出返回 false
    @discardableResult
    static func open(_ text: String) -> Bool {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let found = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap(\.url)
        guard let first = found?.first(where: { $0.scheme == "https" || $0.scheme == "http" }) else { return false }
        let url = Config.canonical(first)
        guard let host = url.host?.lowercased(),
              Config.allowedHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) else { return false }
        #if DEBUG
        mark("open link: \(url.host ?? "")")
        #endif
        Browser.shared.openLink(url)
        return true
    }

    /// 回到前台时调：剪贴板换过、而且像是有网址，就提示
    func check() {
        let board = UIPasteboard.general
        let change = board.changeCount
        guard change != UserDefaults.standard.integer(forKey: Self.seenKey) else { return }
        UserDefaults.standard.set(change, forKey: Self.seenKey)
        Task {
            let patterns: Set<PartialKeyPath<UIPasteboard.DetectedValues>>
            do {
                patterns = try await board.detectedPatterns(for: [\.probableWebURL])
            } catch {
                #if DEBUG
                mark("clipboard check failed: \(error.localizedDescription)")
                #endif
                return
            }
            #if DEBUG
            mark("clipboard changed (\(change) → \(UIPasteboard.general.changeCount)), looks like a link: \(patterns.contains(\.probableWebURL))")
            #endif
            guard patterns.contains(\.probableWebURL) else { return }
            #if DEBUG
            mark("clipboard has a link → offer to open")
            #endif
            show()
        }
    }

    private func show() {
        problem = nil
        offered = true
        // 不理它就自己收起，别一直挡着
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            self.dismiss()
        }
    }

    func dismiss() {
        hideTask?.cancel()
        offered = false
        problem = nil
    }

    /// 系统「粘贴」按钮给的东西：网址或者一段文字（小红书 App「复制链接」是一段带短链的文字）
    func paste(_ providers: [NSItemProvider]) {
        Task {
            var texts: [String] = []
            for provider in providers {
                if let url = try? await provider.loadURL() { texts.append(url.absoluteString) }
                if let text = try? await provider.loadText() { texts.append(text) }
            }
            if texts.contains(where: { Self.open($0) }) {
                dismiss()
            } else {
                #if DEBUG
                mark("clipboard link is not 小红书")
                #endif
                problem = "剪贴板里不是小红书的链接"
                hideTask?.cancel()
                hideTask = Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    guard !Task.isCancelled else { return }
                    self.dismiss()
                }
            }
        }
    }
}

private extension NSItemProvider {
    func loadURL() async throws -> URL? {
        guard canLoadObject(ofClass: URL.self) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            _ = loadObject(ofClass: URL.self) { url, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: url) }
            }
        }
    }

    func loadText() async throws -> String? {
        guard canLoadObject(ofClass: NSString.self) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            _ = loadObject(ofClass: NSString.self) { text, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: text as? String) }
            }
        }
    }
}

/// 顶上浮出来的提示：「剪贴板里有链接」+ 系统「粘贴」按钮 + 关掉。四套界面共用，和防滑门卫的提示一个样子
struct ClipboardLinkBanner: View {
    @ObservedObject var clip: ClipboardLink

    var body: some View {
        Group {
            if let problem = clip.problem {
                Label(problem, systemImage: "link")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.8), in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if clip.offered {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                    Text("剪贴板里有链接，是小红书笔记就点粘贴打开")
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    PasteButton(supportedContentTypes: [.url, .plainText]) { providers in
                        Task { @MainActor in clip.paste(providers) }
                    }
                    .labelStyle(.titleOnly)
                    .buttonBorderShape(.capsule)
                    .tint(Color(red: 1, green: 0x24 / 255, blue: 0x42 / 255)) // 小红书红 #FF2442，系统按钮上是白字
                    Button {
                        clip.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("关掉")
                }
                .foregroundStyle(.white)
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.quick, value: clip.offered)
        .animation(.quick, value: clip.problem)
    }
}

/// 首页左上角「打开链接」点开的说明页（2026-11-23，用户要的）：朋友在微信里发来的小红书笔记，点开是微信里的网页，
/// 网页上的「打开 App」只会去 App Store，到不了只搜；要复制链接再回只搜粘贴。这条路不写出来没人知道。
/// 各套界面共用一页，用系统的样子（和顶上那条剪贴板提示一样）。页面里也放一个系统「粘贴」按钮：
/// 顶上的提示同一份剪贴板只出现一次、15 秒自己收起，错过了从这里也能打开
struct LinkGuide: View {
    @Environment(\.dismiss) private var dismiss
    private static let red = Color(red: 1, green: 0x24 / 255, blue: 0x42 / 255) // 小红书红 #FF2442

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("打开朋友发来的笔记")
                        .font(.title2.bold())
                    Text("朋友在微信里分享的小红书笔记，复制链接就能在只搜里看。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 18) {
                    step(1, "在微信里点开朋友发的那条笔记",
                         "会打开一个网页。中间的「打开 App」（Open in App）不用点，它只会带你去 App Store。")
                    step(2, "点右上角的「···」，选「复制链接」", nil)
                    step(3, "回到只搜，点「粘贴」",
                         "顶上会出现「剪贴板里有链接」，点红色的「粘贴」。没看到的话，点下面这个按钮也一样。")
                }
                PasteButton(supportedContentTypes: [.url, .plainText]) { providers in
                    Task { @MainActor in
                        ClipboardLink.shared.paste(providers)
                        dismiss()
                    }
                }
                .buttonBorderShape(.capsule)
                .tint(Self.red)
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    // 系统的粘贴按钮在剪贴板里没有网址或文字时是灰的、点不动：说一声，免得以为坏了
                    Text("按钮是灰的，说明还没复制到链接。")
                    Text("在小红书 App 里点「分享」→「复制链接」，也是一样打开。")
                    Text("只搜只在你点「粘贴」的时候读剪贴板，只用来找小红书链接，不保存。")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func step(_ number: Int, _ title: String, _ detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: String(number))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Self.red, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
