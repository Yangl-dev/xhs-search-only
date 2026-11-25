import Foundation

/// 每日使用计时：只算 app 在前台的时间，每天零点重新算。
/// 设了每日上限的话，到上限时提醒一次，之后每多用 10 分钟再提醒一次。全部记在这台手机上，不上传
@MainActor
final class UsageTimer: ObservableObject {
    static let shared = UsageTimer()
    static let repeatEvery: TimeInterval = 10 * 60
    static let limitChoices = [0, 15, 30, 45, 60, 90, 120]

    /// 每日上限（分钟），0 = 不提醒
    @Published var limitMinutes = UserDefaults.standard.integer(forKey: "xso.usageLimit") {
        didSet {
            UserDefaults.standard.set(limitMinutes, forKey: "xso.usageLimit")
            nextAlert = nil // 改了上限就按新的算
            tick()
        }
    }
    /// 今天已经用了多少秒
    var todaySeconds: TimeInterval { platformSeconds.values.reduce(0, +) }
    /// 现在要不要弹提醒（弹出来的提醒关掉时 SwiftUI 会把它改回 false）
    @Published var alertShown = false

    private var day = UserDefaults.standard.string(forKey: "xso.usageDay") ?? ""
    /// 用到多少秒时提醒下一次；nil = 到上限时提醒
    private var nextAlert: TimeInterval? = UserDefaults.standard.object(forKey: "xso.usageNextAlert") as? Double
    private var activeSince: Date?
    private var ticker: Timer?

    var todayMinutes: Int { Int(todaySeconds / 60) }

    /// 今天用了多少秒。存成「名字 → 秒数」是沿用以前的格式（键一直是 "xhs"），已经装着的人数据不丢
    @Published private(set) var platformSeconds: [String: Double] =
        UserDefaults.standard.dictionary(forKey: "xso.usagePlatformSeconds") as? [String: Double] ?? [:]
    private static let key = "xhs"

    func becameActive() {
        guard activeSince == nil else { return }
        activeSince = .now
        // 加到 .common 模式：手指一直在滑网页时也照常走，到上限的提醒不会拖到停下来才弹
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer.tolerance = 3
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
    }

    func resignedActive() {
        guard activeSince != nil else { return }
        tick()
        activeSince = nil
        ticker?.invalidate()
        ticker = nil
    }

    /// 把开着的这段时间记进今天，看看该不该提醒
    func tick() {
        let today = Self.dayFormatter.string(from: .now)
        if today != day {
            // 新的一天：从零开始
            day = today
            platformSeconds = [:]
            nextAlert = nil
        }
        if let since = activeSince {
            platformSeconds[Self.key, default: 0] += Date.now.timeIntervalSince(since)
            activeSince = .now
        }
        if limitMinutes > 0, !alertShown, todaySeconds >= nextAlert ?? TimeInterval(limitMinutes * 60) {
            alertShown = true
            nextAlert = todaySeconds + Self.repeatEvery
            #if DEBUG
            mark("usage alert at \(Int(todaySeconds))s, limit \(limitMinutes) min")
            #endif
        }
        let defaults = UserDefaults.standard
        defaults.set(day, forKey: "xso.usageDay")
        defaults.set(platformSeconds, forKey: "xso.usagePlatformSeconds")
        defaults.removeObject(forKey: "xso.usageHistory") // 旧版存的前几天的记录，现在不用了
        defaults.removeObject(forKey: "xso.usageSeconds") // 更旧的版本存的总数
        defaults.set(nextAlert, forKey: "xso.usageNextAlert")
    }

    #if DEBUG
    /// 截图用（见 UIDemo）：直接摆出「用了这么多分钟、该提醒了」的样子
    func demoReminder(minutes: Int) {
        platformSeconds = [Self.key: Double(minutes * 60)]
        alertShown = true
    }
    #endif

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
