import SwiftUI

// 界面风格「圆润」和小红书网页接上的部分：网页配色、搜索页顶栏

extension DesignC {
    /// 小红书的网页在这一套里长什么样：跟首页一样，浅灰的底上放白色的大圆角卡片，标题用圆体，红色还是小红书的红。
    /// 颜色都取自 Palette（同一组数值），所以挨着网页的底栏、顶栏跟网页之间没有色差
    static let webSkin = WebSkin(
        background: Palette.Hex.canvas,
        surface: Palette.Hex.card,
        text: Palette.Hex.text,
        textSecondary: Palette.Hex.textSecondary,
        hairline: Palette.Hex.edge,
        // 输入框、小标签有的直接站在灰底上、有的在白卡片上：比首页卡片里的浅灰块深一档，两种底上都看得出来
        fill: WebSkin.Tone(light: 0xEBEBF0, dark: 0x2B2B30),
        accent: Palette.Hex.red,
        // 笔记卡片跟首页的小方块一样圆；图贴着卡片的上边，上面两个角跟着卡片走，下面两个角小一档
        cardRadius: Int(Metrics.radiusTile),
        mediaRadius: 16,
        controlRadius: 999,
        displayFont: "'Yuanti SC', 'STYuanti-SC-Regular', sans-serif",
        // 跟首页小方块的影子一样：很淡、收得近（网页里的模糊值是这边影子半径的两倍）
        cardShadow: "0 4px 20px rgba(0, 0, 0, 0.07)",
        cardBorder: "none",
        cardGap: 12, // 卡片有底色和描边 / 阴影，上下留一点缝
        // 笔记页：图、正文、评论、底部操作条各是一张白色圆角卡片，浮在灰底上，跟首页的小方块一个样子；
        // 「关注」是实心的红色胶囊；话题标签也用红色
        link: Palette.Hex.red,
        followFilled: true,
        notePanels: true)

    /// 搜索结果页的顶栏：左边一颗白色的圆形返回按钮，右边一条白色的胶囊，里面是正在搜的词，
    /// 右头一颗淡红的小放大镜（首页搜索框的缩小版）。点胶囊里的词就能直接改了重新搜（KeywordField）
    struct ResultsBar: View {
        @ObservedObject var browser: Browser

        var body: some View {
            // 返回按钮能点的范围比看得见的圆大一圈，间距里扣掉这一圈：看上去圆和胶囊之间是 8
            HStack(spacing: Space.s8 - Metrics.overhang(Metrics.pill)) {
                Button { browser.goBack() } label: {
                    Disc(systemImage: "chevron.left")
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("返回")
                HStack(spacing: Space.s8) {
                    KeywordField(browser: browser, font: Typo.plain(Typo.body), color: Palette.text, placeholder: Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Glyph(systemImage: "magnifyingglass", tone: .soft, size: Metrics.glyphMini)
                        .accessibilityHidden(true)
                }
                .padding(.leading, Space.s16)
                .padding(.trailing, (Metrics.pill - Metrics.glyphMini) / 2) // 小放大镜跟胶囊的圆头同心
                .frame(height: Metrics.pill)
                .background { Capsule().fill(Palette.card).modifier(Lifted(.bar)) }
            }
            // 返回按钮看得见的圆、胶囊的右头，都跟首页卡片的两条边对齐
            .padding(.leading, Metrics.gutter - Metrics.overhang(Metrics.pill))
            .padding(.trailing, Metrics.gutter)
            .frame(height: Metrics.pill)
            .frame(maxWidth: Metrics.maxWidth)
            .frame(maxWidth: .infinity)
            .padding(.top, Space.s4)
            .padding(.bottom, Metrics.chromeGap)
            .background(webSkin.background.color.ignoresSafeArea(edges: .top))
        }
    }
}
