import SwiftUI

// 界面风格「原味」和小红书网页接上的部分：网页配色、搜索页顶栏

extension DesignA {
    /// 网页配色。「原味」就是让小红书的页面保持原样，所以从它原本的样子出发，只动三处，都是为了跟这一套的原生界面对上：
    /// - 文字换成这一套的两档黑（Theme.textPrimary / textSecondary 压在页面底色上的实际颜色）。
    ///   小红书原来的次要文字 #8C8C8C 在白底上偏淡（对比度 3.4），换完是 4.9
    /// - 深色模式的卡片底色用这一套的卡片色，网页里的浮层和原生的提醒卡、扫码提示是同一种灰
    /// 其余不动：白底 / #0A0A0A、浅灰块、分隔线、红色 #FF2442、圆角 8 和胶囊、标题不换字体、卡片不加阴影不描边；
    /// 笔记页也照原样：蓝色话题标签、红色描边的「关注」、整页铺满。
    /// 原生界面的底色、卡片、浅灰块、分隔线、红色都从这里取（见 Theme），两边永远是同一组数
    static let webSkin: WebSkin = {
        var skin = WebSkin.xiaohongshu
        skin.text = WebSkin.Tone(light: 0x1F1F1F, dark: 0xE2E2E2)
        skin.textSecondary = WebSkin.Tone(light: 0x707070, dark: 0x939393)
        skin.surface.dark = 0x1F1F1F
        return skin
    }()

    /// 搜索结果页的顶栏：返回 + 正在搜的词。词放在跟首页搜索框一样的浅灰胶囊里，点它就能直接改了重新搜（KeywordField）。
    /// 跟小红书 app 的搜索页一个样子；下面紧接着网页自己的筛选标签，所以底下不画分隔线，和网页连成一块
    struct ResultsBar: View {
        @ObservedObject var browser: Browser

        /// 返回箭头画出来有多宽（sizeTitle 这个大小时）
        private static let chevronWidth: CGFloat = 12

        var body: some View {
            HStack(spacing: 0) {
                Button { browser.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: Theme.sizeTitle, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: Theme.controlHeight, height: Theme.controlHeight)
                }
                .buttonStyle(TapStyle())
                .accessibilityLabel("返回")
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: Theme.sizeBody, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityHidden(true)
                    KeywordField(browser: browser, font: .system(size: Theme.sizeHeadline),
                                 color: Theme.textPrimary, placeholder: Theme.textPlaceholder)
                }
                // 前面有放大镜的那一头少留一点，跟小标签一样
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .frame(height: Theme.chipHeight)
                .background(Theme.fill, in: Capsule())
            }
            // 箭头在 44 见方的可点范围正中，它的左边缘正好落在页面的留白线上
            .padding(.leading, Theme.gutter - (Theme.controlHeight - Self.chevronWidth) / 2)
            .padding(.trailing, Theme.gutter)
            .frame(height: Theme.controlHeight)
            .background(Theme.background.ignoresSafeArea(edges: .top))
        }
    }
}
