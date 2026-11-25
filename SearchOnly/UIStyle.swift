import SwiftUI

// 几套界面设计并排放在同一个 app 里（「结合版」e 不是单独一套，是极简加上原味的设置页），在「设置 → 界面风格」里切换，四套都保留，用的人自己选。
// 每一套是一个文件（DesignA.swift、DesignC.swift …），都提供同样的九块界面和一组网页配色（见下面的 extension）；
// 界面背后的行为（搜索、跳转、开关、计时）全在 Browser / UsageTimer 里，各套共用，换风格不影响功能

enum UIStyle: String, CaseIterable, Identifiable {
    case a, c, d, e

    var id: String { rawValue }

    var name: String {
        switch self {
        case .a: "原味"
        case .c: "圆润"
        case .d: "极简"
        case .e: "结合版"
        }
    }

    var summary: String {
        switch self {
        case .a: "跟小红书一个路子：白底、灰色搜索框、一点红"
        case .c: "圆角卡片加图标，各个开关的状态一眼看到"
        case .d: "搜索框在拇指边，黑白为主，像个工具"
        case .e: "极简的界面和图标，设置页用原味的"
        }
    }

    /// 界面和图标照哪一套：「结合版」（2026-11-22 用户要的）除了设置页，全用「极简」的
    var look: UIStyle { self == .e ? .d : self }

    /// 这一套的桌面图标在素材库里的名字；「原味」用默认图标（nil）
    var iconName: String? { look == .a ? nil : "IconStyle" + look.rawValue.uppercased() }
    /// 设置里显示的图标小图
    var previewImage: String { "IconPreview" + look.rawValue.uppercased() }
}

// 每一套设计要提供的九块界面和一组网页配色。App 的骨架（SearchOnlyApp.swift）只通过这里取界面，不直接认某一套
extension UIStyle {
    /// 原生搜索首页：盖在网页上面
    @ViewBuilder func home(_ browser: Browser) -> some View {
        switch self {
        case .a: DesignA.Home(browser: browser)
        case .c: DesignC.Home(browser: browser)
        case .d: DesignD.Home(browser: browser)
        case .e: DesignD.Home(browser: browser)
        }
    }

    /// 底部导航栏：排在网页下面（不盖住网页）
    @ViewBuilder func tabBar(_ browser: Browser) -> some View {
        switch self {
        case .a: DesignA.TabBar(browser: browser)
        case .c: DesignC.TabBar(browser: browser)
        case .d: DesignD.TabBar(browser: browser)
        case .e: DesignD.TabBar(browser: browser)
        }
    }

    /// 消息页顶上的「私信 | 评论和通知」切换：排在网页上面
    @ViewBuilder func messagesSwitcher(_ browser: Browser) -> some View {
        switch self {
        case .a: DesignA.MessagesSwitcher(browser: browser)
        case .c: DesignC.MessagesSwitcher(browser: browser)
        case .d: DesignD.MessagesSwitcher(browser: browser)
        case .e: DesignD.MessagesSwitcher(browser: browser)
        }
    }

    /// 设置页：从底下升起来的那一页
    @ViewBuilder func settings(_ browser: Browser) -> some View {
        switch self {
        case .a: DesignA.SettingsSheet(browser: browser)
        case .c: DesignC.SettingsSheet(browser: browser)
        case .d: DesignD.SettingsSheet(browser: browser)
        case .e: DesignA.SettingsSheet(browser: browser) // 结合版：设置页用原味的
        }
    }

    /// 用到每日上限时盖在最上面的提醒
    @ViewBuilder func usageReminder(_ usage: UsageTimer, openSettings: @escaping () -> Void) -> some View {
        switch self {
        case .a: DesignA.UsageReminder(usage: usage, openSettings: openSettings)
        case .c: DesignC.UsageReminder(usage: usage, openSettings: openSettings)
        case .d: DesignD.UsageReminder(usage: usage, openSettings: openSettings)
        case .e: DesignD.UsageReminder(usage: usage, openSettings: openSettings)
        }
    }

    /// 登录要扫码时浮在登录页顶部的帮忙提示
    @ViewBuilder func loginBanner(_ browser: Browser) -> some View {
        switch self {
        case .a: DesignA.LoginBanner(browser: browser)
        case .c: DesignC.LoginBanner(browser: browser)
        case .d: DesignD.LoginBanner(browser: browser)
        case .e: DesignD.LoginBanner(browser: browser)
        }
    }

    /// 搜索结果页顶上的顶栏（返回 + 正在搜的词）：排在网页上面
    @ViewBuilder func resultsBar(_ browser: Browser) -> some View {
        switch self {
        case .a: DesignA.ResultsBar(browser: browser)
        case .c: DesignC.ResultsBar(browser: browser)
        case .d: DesignD.ResultsBar(browser: browser)
        case .e: DesignD.ResultsBar(browser: browser)
        }
    }

    /// 这套风格希望小红书网页长成什么样
    var webSkin: WebSkin {
        switch self {
        case .a: DesignA.webSkin
        case .c: DesignC.webSkin
        case .d: DesignD.webSkin
        case .e: DesignD.webSkin
        }
    }

    /// 整页加载时网页顶上的细进度条
    @ViewBuilder func loadingBar(progress: Double) -> some View {
        switch self {
        case .a: DesignA.LoadingBar(progress: progress)
        case .c: DesignC.LoadingBar(progress: progress)
        case .d: DesignD.LoadingBar(progress: progress)
        case .e: DesignD.LoadingBar(progress: progress)
        }
    }
}
