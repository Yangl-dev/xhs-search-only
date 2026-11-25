import Combine
import SwiftUI

// 「圆润」这一套（DesignC.swift）的设计规范：颜色、字号、尺寸和它的几个小部件都在这里，界面代码只用这里的名字。
// 思路：
// - 浅灰的底上放白色的大圆角卡片，浅色模式靠很淡很散的影子浮起来，深色模式不要影子、靠卡片比底亮一档来分
// - 能圆的都圆：按钮和切换是胶囊，图标按钮是圆，图标一律用实心的、放在圆里
// - 开关的状态要一眼看到：开着的是淡红底 + 红图标（首页的方块整块变淡红，设置里是图标圆变淡红），关着的是白卡 + 灰图标圆
// - 红色 #FF2442 是唯一的颜色，少数几个最主要的东西（搜索按钮、用量圆环、提醒上的主按钮、进度条）
//   用「珊瑚 → 红」的渐变，其余的红都是纯色；整块的纯红只留给开关本身、选中的那一颗和勾
// - 小红书的网页也换成同一套底色和卡片（见 DesignC+Web.swift），所以挨着网页的几块（底栏、消息页的切换、搜索页顶栏）
//   跟首页一样：浅灰的底上放白色的圆东西，选中的那一格是淡红的

extension DesignC {
    enum Palette {
        /// 网页也要用的几个颜色（见 DesignC+Web.swift 里的网页配色）。网页要的是数值，所以先写成浅色、深色一对数值，
        /// 下面界面上用的颜色从这里取：两边永远是同一个颜色
        enum Hex {
            static let red = WebSkin.Tone(light: 0xFF2442, dark: 0xFF2442)
            static let canvas = WebSkin.Tone(light: 0xF4F4F6, dark: 0x0A0A0A)
            static let card = WebSkin.Tone(light: 0xFFFFFF, dark: 0x1B1B1F)
            static let text = WebSkin.Tone(light: 0x1C1C1E, dark: 0xF2F2F4)
            static let textSecondary = WebSkin.Tone(light: 0x66666E, dark: 0xA6A6AE)
            static let edge = WebSkin.Tone(light: 0xE6E6EB, dark: 0x2F2F35)
        }

        // MARK: 红色这一家

        static let red = Hex.red.color
        /// 渐变里红色的搭档：偏暖的珊瑚色
        static let coral = Color(hex: 0xFF7A5C)
        /// 只给最主要的几样东西用
        static let gradient = LinearGradient(colors: [coral, red], startPoint: .topLeading, endPoint: .bottomTrailing)
        /// 淡红底：开着的开关、提示卡
        static let tint = Color(light: 0xFFECEF, dark: 0x3A1A20)
        /// 淡红底上的图标圆：浅色是白的，深色比淡红底亮一档
        static let tintGlyph = Color(light: 0xFFFFFF, dark: 0x5A2430)
        /// 淡红底和白底上的红字：比品牌红深一点（深色模式浅一点），小字才看得清
        static let redText = Color(light: 0xD9143A, dark: 0xFF7387)
        /// 渐变按钮底下那圈淡淡的红晕
        static let glow = red.opacity(0.28)

        // MARK: 底和卡片

        /// 页面底色：首页、设置和小红书的网页都是它，所以底栏、顶栏跟网页之间没有色差
        static let canvas = Hex.canvas.color
        /// 卡片
        static let card = Hex.card.color
        /// 卡片里凹下去的一块：输入框、小标签、没亮的图标圆
        static let well = Color(light: 0xF2F2F5, dark: 0x2B2B30)
        /// 圆环没走到的部分
        static let ringTrack = Color(light: 0xECECF0, dark: 0x2F2F35)
        /// 很淡的一圈边：浮在网页上的白卡片和白胶囊；网页里的分隔线也是它
        static let edge = Hex.edge.color
        /// 风格小图的一圈边：半透明的，跟着底下图标的颜色走。白色的图标在白卡片上看得出边界，深色的图标上也不会多出一圈亮边
        static let thumbEdge = dynamic(light: UIColor(white: 0, alpha: 0.08), dark: UIColor(white: 1, alpha: 0.14))
        /// 关着的开关的轨道、没选中的圆圈
        static let switchOff = Color(light: 0xE1E1E6, dark: 0x3A3A40)

        // MARK: 文字和图标

        static let text = Hex.text.color
        /// 说明文字
        static let textSecondary = Hex.textSecondary.color
        /// 输入框占位
        static let textFaint = Color(light: 0xA3A3AB, dark: 0x6C6C74)
        /// 没亮的图标
        static let icon = Color(light: 0x8A8A93, dark: 0x9A9AA3)

        // MARK: 影子（只有浅色模式有）

        /// 卡片的影子：很淡、很散
        static let shadow = dynamic(light: UIColor(white: 0, alpha: 0.07), dark: .clear)
        /// 小东西的影子：开关的圆钮
        static let shadowSmall = dynamic(light: UIColor(white: 0, alpha: 0.12), dark: UIColor(white: 0, alpha: 0.4))
        /// 浮在网页上的东西的影子：底下可能是白卡片、也可能是照片，要深一点才分得开
        static let shadowFloat = dynamic(light: UIColor(white: 0, alpha: 0.14), dark: UIColor(white: 0, alpha: 0.5))

        /// 提醒升起来时压在后面的那层暗
        static let scrim = Color.black.opacity(0.4)

        private static func dynamic(light: UIColor, dark: UIColor) -> Color {
            Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
        }
    }

    /// 间距只用这几档（名字就是数值）
    enum Space {
        static let s2: CGFloat = 2
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
    }

    enum Metrics {
        // MARK: 留白

        /// 页面左右留白
        static let gutter = Space.s16
        /// 卡片之间
        static let gap = Space.s12
        /// 卡片里面四周
        static let pad = Space.s16
        /// 小方块里面的上下。左右：设置里的风格块跟卡片一样是 pad（字跟卡片里的字在一条左边线上）；
        /// 首页的三块里面是居中的，左右只留 tileSide，五个字的名字才放得下
        static let tilePad = Space.s12
        static let tileSide = Space.s8
        /// 直接站在底色上的字（字标、小标题、说明）比卡片的边再往里缩这么多：跟卡片里的字共用一条左边线
        static let inset = pad
        /// 多行说明的行距
        static let lineSpacing = Space.s4

        // MARK: 圆角

        /// 大卡片
        static let radiusCard: CGFloat = 24
        /// 首页的搜索卡是主角，再圆一点
        static let radiusHero: CGFloat = 28
        /// 从屏幕底下升起来的两块（设置页、提醒）：挨着屏幕的圆角，要更圆
        static let radiusSheet: CGFloat = 36
        /// 小方块（首页的开关块、风格块）
        static let radiusTile: CGFloat = 20
        /// 风格小图
        static let radiusThumb: CGFloat = 12

        // MARK: 高度和大小

        /// 能点的东西至少这么大
        static let touch: CGFloat = 44
        /// 图标圆的直径：一般的、小一号的（小方块上、卡片角上的清空和关闭）、最小的（浮着的胶囊里）
        static let glyph: CGFloat = 36
        static let glyphSmall: CGFloat = 32
        static let glyphMini: CGFloat = 28
        /// 小一号的胶囊：「完成」、消息切换里的一格
        static let compact: CGFloat = 36
        /// 胶囊按钮、小标签、每日提醒的选项、站在底色上的白圆按钮（设置、返回）、搜索页顶栏里的搜索框
        static let pill: CGFloat = 40
        /// 主要按钮
        static let control: CGFloat = 52
        /// 搜索框
        static let field: CGFloat = 56
        /// 首页顶上那一行
        static let topBar: CGFloat = 48
        /// 底栏那颗白色的大胶囊
        static let tabBar: CGFloat = 60
        /// 底栏里选中的图标坐着的那颗小胶囊
        static let tabCapsule = CGSize(width: 54, height: 30)
        /// 挨着网页的几块（底栏、搜索页顶栏）里的白东西，离网页那条边这么远
        static let chromeGap = Space.s8
        /// 「只搜」小标签的高度
        static let tag = Space.s24
        /// 开关的轨道
        static let switchTrack = CGSize(width: 50, height: 30)
        /// 风格小图
        static let thumb: CGFloat = 52
        /// 用量圆环：设置里的、提醒上的
        static let dialSmall: CGFloat = 88
        static let dialLarge: CGFloat = 104
        /// 进度条的粗细
        static let bar: CGFloat = 3
        /// 滚动区上下两头渐隐的高度
        static let fadeTop = Space.s24
        static let fadeBottom = Space.s12
        /// 横着滑的一排，右头渐隐的宽度
        static let fadeSide = Space.s24

        // MARK: 图标的字号

        /// 小的：圆环里
        static let iconSmall: CGFloat = 13
        /// 一般的：底栏、输入框里、设置按钮
        static let icon: CGFloat = 18
        /// 大的：选中的勾
        static let iconLarge: CGFloat = 22

        // MARK: 宽度

        /// 宽屏上内容最宽这么多
        static let maxWidth: CGFloat = 560
        /// 消息页的切换最宽这么多
        static let switcherWidth: CGFloat = 280
        /// 最近搜索里一个词最宽这么多，再长就截断
        static let chipWidth: CGFloat = 220

        /// 按钮按下时淡到这么多（跟公用的 PressableStyle 一样）
        static let pressedOpacity = 0.6

        /// 看着不到 44 的东西，能点的范围每边要补多少
        static func overhang(_ visible: CGFloat) -> CGFloat { max(0, (touch - visible) / 2) }
    }

    /// 影子只有这几种
    struct Elevation {
        let color: Color
        let radius: CGFloat
        let y: CGFloat

        /// 大卡片：很淡、很散
        static let card = Elevation(color: Palette.shadow, radius: 20, y: 8)
        /// 小方块：收一些（挨得近，影子叠在一起会显脏）
        static let tile = Elevation(color: Palette.shadow, radius: 10, y: 4)
        /// 站在底色上的白色小件（圆按钮、搜索页顶栏的胶囊、消息页的切换）：收得紧。
        /// 顶栏的影子伸到网页那边会被网页齐齐切掉一条，所以要在顶栏自己的那点空里收完
        static let bar = Elevation(color: Palette.shadow, radius: 4, y: 2)
        /// 开关的圆钮：收得很紧，不会在轨道里晕出一圈灰
        static let knob = Elevation(color: Palette.shadowSmall, radius: 2, y: 1)
        /// 浮在网页上的卡片
        static let float = Elevation(color: Palette.shadowFloat, radius: 24, y: 10)
        /// 浮在网页上的小胶囊
        static let floatSmall = Elevation(color: Palette.shadowFloat, radius: 12, y: 6)
        /// 渐变按钮底下的红晕
        static let glow = Elevation(color: Palette.glow, radius: 8, y: 4)
    }

    /// 给一个形状加上面某一种影子
    struct Lifted: ViewModifier {
        let elevation: Elevation?

        init(_ elevation: Elevation?) { self.elevation = elevation }

        func body(content: Content) -> some View {
            content.shadow(color: elevation?.color ?? .clear, radius: elevation?.radius ?? 0, y: elevation?.y ?? 0)
        }
    }

    /// 字：标题、块上的名字、按钮用圆体（系统字体，用到时才下载，见 OnDemandFonts），长一点的说明用苹方，数字用系统的圆角数字。
    /// 字号只有这几档
    enum Typo {
        /// 字标、大数字
        static let display: CGFloat = 28
        /// 每一页最大的那句话
        static let title: CGFloat = 20
        /// 名字、按钮、输入的字
        static let body: CGFloat = 16
        /// 说明
        static let caption: CGFloat = 13
        /// 最小的字：底栏图标下面、圆环里的单位、风格块上的两行说明
        static let small: CGFloat = 12

        static let yuanName = "STYuanti-SC-Bold"

        /// 圆体；还没下好时先用系统字体顶着
        @MainActor
        static func yuan(_ size: CGFloat) -> Font {
            OnDemandFonts.shared.font(yuanName, size: size, fallback: .system(size: size, weight: .semibold, design: .rounded))
        }

        /// 数字
        static func digits(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }

        /// 苹方：说明和长一点的文字
        static func plain(_ size: CGFloat = caption, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    }

    // MARK: - 小部件

    /// 一行圆体字。圆体下好的那一刻自己换上。
    /// 圆体自带的数字和英文又细又窄，跟汉字放一起不好看，所以这些换成系统的圆角字
    struct Yuan: View {
        @ObservedObject private var fonts = OnDemandFonts.shared
        private let text: String
        private let size: CGFloat

        init(_ text: String, size: CGFloat = Typo.body) {
            self.text = text
            self.size = size
        }

        var body: some View {
            Text(styled)
                .onAppear { fonts.request([Typo.yuanName]) }
        }

        /// 一段一段配好字体，拼成一句
        private var styled: AttributedString {
            runs.reduce(into: AttributedString()) { joined, run in
                var piece = AttributedString(run.text)
                piece.font = run.latin ? Typo.digits(size) : Typo.yuan(size)
                joined.append(piece)
            }
        }

        /// 把一句话按「数字英文 / 其它」切成几段
        private var runs: [(text: String, latin: Bool)] {
            var result: [(text: String, latin: Bool)] = []
            for character in text {
                let latin = character.isASCII && (character.isNumber || character.isLetter)
                if let last = result.last, last.latin == latin {
                    result[result.count - 1].text.append(character)
                } else {
                    result.append((String(character), latin))
                }
            }
            return result
        }
    }

    /// 键盘现在停在哪。新系统的键盘是半透明的，盖在它底下的东西（尤其是红色）会透上来一团，
    /// 所以首页和底栏要知道自己被键盘盖住了多少，盖住的部分先不画。
    /// 整个 app 只有一个，从第一次用到起一直开着：之后哪块界面晚一点才出现，也能问到键盘此刻的位置。
    /// 它开始之前就弹着的键盘，要等键盘下一次变化才知道；这种时候只是键盘底下透一点颜色
    @MainActor
    final class Keyboard: ObservableObject {
        static let shared = Keyboard()
        /// 键盘上沿在屏幕上的位置；收起来了是 nil
        @Published private(set) var top: CGFloat?
        private var watching: Set<AnyCancellable> = []

        private init() {
            let center = NotificationCenter.default
            center.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
                .sink { [weak self] note in
                    // 键盘最后停在哪（收起时是停在屏幕外面，算出来自然就是没盖住）
                    guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                    self?.top = frame.minY
                }
                .store(in: &watching)
            // 收起来以后、还有 app 退到后台时再清一次：就算上面那条哪次没跟上，也不会一直当它还弹着
            // （当成没弹着，最多是键盘底下透一点颜色；当成一直弹着，底栏就看不见了）
            center.publisher(for: UIResponder.keyboardDidHideNotification)
                .merge(with: center.publisher(for: UIApplication.didEnterBackgroundNotification))
                .sink { [weak self] _ in self?.top = nil }
                .store(in: &watching)
        }

        /// 下沿在屏幕上 bottom 这个位置的一块界面，被键盘盖住了多高
        func covers(below bottom: CGFloat) -> CGFloat {
            guard let top else { return 0 }
            return max(0, bottom - top)
        }
    }

    /// 卡片的底：圆角 + 浅色模式下一层很淡的影子。淡红底的块不要影子（elevation 给 nil），它靠颜色就够了
    struct Card: ViewModifier {
        var radius = Metrics.radiusCard
        var fill = Palette.card
        var elevation: Elevation? = .card

        func body(content: Content) -> some View {
            content.background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .modifier(Lifted(elevation))
            }
        }
    }

    /// 首页和设置里的小方块：比大卡片小一号的圆角和影子；亮着的时候是淡红底、没有影子
    struct Tile: ViewModifier {
        var lit = false

        func body(content: Content) -> some View {
            content.modifier(Card(radius: Metrics.radiusTile, fill: lit ? Palette.tint : Palette.card, elevation: lit ? nil : .tile))
        }
    }

    /// 滚动的内容滑到固定的标题底下（或者键盘、底栏上沿）时，边上淡出去，不是齐齐一刀切掉
    struct EdgeFade: View {
        let edge: VerticalEdge

        var body: some View {
            let top = edge == .top
            LinearGradient(colors: top ? [Palette.canvas, Palette.canvas.opacity(0.6), Palette.canvas.opacity(0)]
                                       : [Palette.canvas.opacity(0), Palette.canvas],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: top ? Metrics.fadeTop : Metrics.fadeBottom)
                .frame(maxHeight: .infinity, alignment: top ? .top : .bottom)
                .allowsHitTesting(false)
        }
    }

    /// 自己画的开关：圆头的轨道 + 白色的圆钮，开着是红的。不用系统的，是为了各个系统版本上都是同一个样子。
    /// 整行都能点
    struct SwitchStyle: ToggleStyle {
        func makeBody(configuration: Configuration) -> some View {
            Button { configuration.isOn.toggle() } label: {
                HStack(spacing: Space.s8) {
                    configuration.label
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Capsule()
                        .fill(configuration.isOn ? Palette.red : Palette.switchOff)
                        .frame(width: Metrics.switchTrack.width, height: Metrics.switchTrack.height)
                        .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                            Circle()
                                .fill(.white)
                                .modifier(Lifted(.knob))
                                .padding(Space.s2)
                        }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.snappy(duration: 0.2), value: configuration.isOn)
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(configuration.isOn ? "开" : "关")
        }
    }

    /// 圆里的实心图标。几种样子：没亮（卡片上的灰圆）、亮着（白卡片上是淡红圆 + 红图标）、
    /// 亮着并且本身站在淡红底上（白圆 + 红图标）、直接放在页面底色上的（白圆 + 灰图标）
    struct Glyph: View {
        enum Tone { case rest, soft, onTint, onCanvas }

        let systemImage: String
        var tone = Tone.rest
        var size = Metrics.glyph

        var body: some View {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(background, in: Circle())
                .animation(.quick, value: tone)
        }

        private var foreground: Color {
            switch tone {
            case .rest, .onCanvas: Palette.icon
            case .soft, .onTint: Palette.red
            }
        }

        private var background: Color {
            switch tone {
            case .rest: Palette.well
            case .soft: Palette.tint
            case .onTint: Palette.tintGlyph
            case .onCanvas: Palette.card
            }
        }
    }

    /// 直接站在页面底色上的白色圆按钮的样子（首页的设置、搜索页的返回）：白圆 + 灰图标，浅色模式有一点收得很紧的影子。
    /// 圆是 40，四周补到 44 好点
    struct Disc: View {
        let systemImage: String

        var body: some View {
            Image(systemName: systemImage)
                .font(.system(size: Metrics.icon, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: Metrics.pill, height: Metrics.pill)
                .background { Circle().fill(Palette.card).modifier(Lifted(.bar)) }
                .frame(width: Metrics.touch, height: Metrics.touch)
                .contentShape(Circle())
        }
    }

    /// 一行排不下就换行，每一行都居中：首页最近搜索的小标签用（公用的 FlowLayout 是靠左排的）
    struct CenteredFlow: Layout {
        var spacing = Space.s8

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
            return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                          height: rows.last.map { $0.y + $0.height } ?? 0)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            for row in arrange(width: bounds.width, subviews: subviews) {
                var x = bounds.midX - row.width / 2
                for index in row.items {
                    let size = subviews[index].sizeThatFits(.unspecified)
                    subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                    x += size.width + spacing
                }
            }
        }

        private struct Row { var items: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

        private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
            var rows: [Row] = []
            var row = Row()
            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)
                if !row.items.isEmpty && row.width + spacing + size.width > width {
                    rows.append(row)
                    row = Row(y: row.y + row.height + spacing)
                }
                row.width += (row.items.isEmpty ? 0 : spacing) + size.width
                row.height = max(row.height, size.height)
                row.items.append(index)
            }
            if !row.items.isEmpty { rows.append(row) }
            return rows
        }
    }

    /// 用量圆环：走了多少用渐变画，没走到的是浅灰。线的粗细跟着大小走
    struct Ring: View {
        /// 0…1
        let fraction: Double
        var size = Metrics.glyphSmall

        private var lineWidth: CGFloat { (size * 0.11).rounded() }

        var body: some View {
            ZStack {
                Circle().stroke(Palette.ringTrack, lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(max(fraction, 0), 1))
                    .stroke(Palette.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: fraction)
            }
            .padding(lineWidth / 2)
            .frame(width: size, height: size)
        }
    }

    /// 圆环里写着今天用了多少分钟：设置和提醒上是同一个东西，只是大小不同。没设上限时圆环是空的
    struct Dial: View {
        let minutes: Int
        let limit: Int
        var size: CGFloat

        var body: some View {
            ZStack {
                Ring(fraction: limit > 0 ? Double(minutes) / Double(limit) : 0, size: size)
                VStack(spacing: -Space.s2) {
                    Text("\(minutes)")
                        .font(Typo.digits(Typo.display))
                        .foregroundStyle(Palette.text)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("分钟")
                        .font(Typo.plain(Typo.small, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.horizontal, size * 0.2)
            }
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("今天用了 \(minutes) 分钟")
        }
    }

    /// 看着不到 44 的按钮，能点到的范围四周各补一点、补到 44；排版上占的位置不变
    struct TouchTarget: ViewModifier {
        /// 不给就是够宽、不用补
        var visibleWidth = Metrics.touch
        let visibleHeight: CGFloat

        func body(content: Content) -> some View {
            let dx = Metrics.overhang(visibleWidth), dy = Metrics.overhang(visibleHeight)
            content
                .padding(.horizontal, dx)
                .padding(.vertical, dy)
                .contentShape(Rectangle())
                .padding(.horizontal, -dx)
                .padding(.vertical, -dy)
        }
    }

    /// 胶囊按钮的三种样子：主要的（渐变）、淡红的、安静的（浅灰）
    struct PillStyle: ButtonStyle {
        enum Kind { case primary, soft, quiet }

        var kind = Kind.soft
        var height = Metrics.pill
        /// 撑满一行
        var wide = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(foreground)
                .padding(.horizontal, Space.s16)
                .frame(maxWidth: wide ? .infinity : nil)
                .frame(height: height)
                .background { background }
                .modifier(TouchTarget(visibleHeight: height))
                .opacity(configuration.isPressed ? Metrics.pressedOpacity : 1)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.quick, value: configuration.isPressed)
        }

        private var foreground: Color {
            switch kind {
            case .primary: .white
            case .soft: Palette.redText
            case .quiet: Palette.text
            }
        }

        @ViewBuilder private var background: some View {
            switch kind {
            case .primary: Capsule().fill(Palette.gradient).modifier(Lifted(.glow))
            case .soft: Capsule().fill(Palette.tint)
            case .quiet: Capsule().fill(Palette.well)
            }
        }
    }
}
