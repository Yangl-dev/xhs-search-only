import AppIntents

/// Siri、快捷指令、聚焦搜索、操作按钮都能用：「用只搜搜索」→ 问「想搜什么？」→ 打开 app 直接出结果
struct SearchXiaohongshu: AppIntent {
    static let title: LocalizedStringResource = "搜小红书"
    static let description = IntentDescription("打开只搜，直接搜索关键词，不经过推荐流")
    static let openAppWhenRun = true

    @Parameter(title: "关键词", requestValueDialog: "想搜什么？")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult {
        Browser.shared.search(query)
        return .result()
    }
}

struct SearchOnlyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SearchXiaohongshu(),
                    phrases: ["用\(.applicationName)搜索", "在\(.applicationName)里搜", "\(.applicationName)搜一下"],
                    shortTitle: "搜小红书",
                    systemImageName: "magnifyingglass")
    }
}
