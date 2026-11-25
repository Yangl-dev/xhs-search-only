import SwiftUI

// 「极简」和小红书网页接上的部分：网页配色、搜索结果页的顶栏。规范和小部件见 DesignD.swift

extension DesignD {
    /// 网页配色：小红书的页面也变成黑白、平的，跟原生界面是同一套。
    /// 卡片和页面一个底色，靠一圈细线分开，没有阴影；小红书原来是红色的地方一律换成墨色（这套界面里红色不当强调色用）。
    /// 这几个颜色的数值只写在这里；原生界面的 Palette 从这里取，所以挨着网页的底栏、顶栏跟网页不会有色差
    static let webSkin = WebSkin(
        background: WebSkin.Tone(light: 0xFFFFFF, dark: 0x0A0A0A),
        surface: WebSkin.Tone(light: 0xFFFFFF, dark: 0x0A0A0A),
        text: ink,
        // 灰字压在底色上的对比度：浅色 5.3 : 1，深色 7.2 : 1
        textSecondary: WebSkin.Tone(light: 0x6B6B6B, dark: 0x9C9C9C),
        hairline: WebSkin.Tone(light: 0xE0E0E0, dark: 0x2C2C2C),
        fill: WebSkin.Tone(light: 0xF2F2F2, dark: 0x1A1A1A),
        accent: ink,
        // 圆角跟原生界面的框、小图一样大
        cardRadius: Int(Metrics.radius),
        mediaRadius: Int(Metrics.radiusThumb),
        controlRadius: Int(Metrics.radius),
        displayFont: nil,
        cardShadow: "none",
        cardBorder: "1px solid var(--xso-line)",
        cardGap: 8, // 卡片有底色和描边 / 阴影，上下留一点缝
        // 笔记页：没有红也没有蓝。话题标签是墨色字，「关注」是墨色描边，图片下的小点、发送按钮也是墨色；
        // 作者那一行底下一条细线，跟搜索页顶栏一样
        link: ink,
        onAccent: WebSkin.Tone(light: 0xFFFFFF, dark: 0x0A0A0A),
        noteHeaderRule: true)

    /// 墨色：浅色模式近乎纯黑，深色模式是不刺眼的白
    private static let ink = WebSkin.Tone(light: 0x0B0B0B, dark: 0xF2F2F2)

    /// 搜索结果页的顶栏：就是首页那个搜索框挪到了顶上、矮了一档。
    /// 框里左边一格是返回，右边一格是放大镜，正在搜的词在正中间；点词就能直接改了重新搜（KeywordField）。
    /// 底边一条细线：网页往上滚的时候，内容是从这条线底下滑进去的
    struct ResultsBar: View {
        @ObservedObject var browser: Browser

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
            HStack(spacing: 0) {
                Button { browser.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(Typo.iconMedium)
                        .frame(width: Metrics.touch)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("返回")
                KeywordField(browser: browser, font: Typo.body, color: Palette.ink, placeholder: Palette.secondary, alignment: .center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Image(systemName: "magnifyingglass")
                    .font(Typo.iconMedium)
                    .frame(width: Metrics.touch)
                    .accessibilityHidden(true)
            }
            .buttonStyle(Press())
            .foregroundStyle(Palette.ink)
            // 框只画 inner 那么高，能点的范围是整条顶栏的高度
            .background {
                shape
                    .strokeBorder(Palette.ink, lineWidth: Metrics.line)
                    .frame(height: Metrics.inner)
            }
            .padding(.horizontal, Metrics.boxInset)
            .frame(height: Metrics.resultsBar)
            .frame(maxWidth: Metrics.maxWidth)
            .frame(maxWidth: .infinity)
            .background(Palette.background.ignoresSafeArea(edges: .top))
            .overlay(alignment: .bottom) { Rule() }
        }
    }
}
