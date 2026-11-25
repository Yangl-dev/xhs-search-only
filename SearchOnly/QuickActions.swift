import UIKit

/// 长按 app 图标出现的快捷操作：「搜索」写在 Info.plist 里（装上就有），最近 3 次搜索在这里动态加，点一下直接搜
enum QuickActions {
    static func update(recent: [String]) {
        UIApplication.shared.shortcutItems = recent.map {
            UIApplicationShortcutItem(type: "recent", localizedTitle: $0, localizedSubtitle: "最近搜索",
                                      icon: UIApplicationShortcutIcon(systemImageName: "clock.arrow.circlepath"),
                                      userInfo: ["query": $0 as NSString])
        }
    }

    @MainActor
    static func handle(_ item: UIApplicationShortcutItem) {
        if item.type == "recent", let query = item.userInfo?["query"] as? String {
            Browser.shared.search(query)
        } else {
            Browser.shared.showSearchHome()
        }
    }
}

/// SwiftUI 收不到快捷操作，要靠这两个代理：冷启动时从 connectionOptions 拿，app 在后台时走 SceneDelegate
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem { QuickActions.handle(item) }
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        QuickActions.handle(shortcutItem)
        completionHandler(true)
    }
}
