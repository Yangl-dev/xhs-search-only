import SwiftUI

// 界面风格「极简」：它是个工具，不是个逛的地方。搜索框钉在屏幕最上面，键盘升降它都不动；
// 下面只有一行筛选和几块最近搜索，再往下几乎是空的。只有黑、白和几档灰，唯一的颜色是红色的输入光标和底栏选中项下面的一小段红线。
// 首页和提醒页的东西都排在屏幕正中间那一条竖线上；设置是一行一行的表，照旧靠左。
// 这个文件是规范（颜色、字号、尺寸）和小部件。九块界面和网页配色（是哪些见 UIStyle.swift）分在四个文件里：
// DesignD+Home.swift（首页）、DesignD+Settings.swift（设置）、
// DesignD+Chrome.swift（底栏、消息页切换、提醒、登录提示、浮动按钮、进度条）、DesignD+Web.swift（网页配色、搜索结果页的顶栏）

enum DesignD {}

// MARK: - 规范：界面代码只用这里的名字

extension DesignD {
    /// 描边的规矩：能点的框（搜索框、按钮、开关、小方框）和浮在网页上的板子用墨色的 1pt 线；
    /// 不能点的面板和分隔线用 stroke 那档灰。
    /// 例外是首页最近搜索的词块：能点，但一屏好几块，用灰线框，免得跟搜索框抢
    /// 跟网页共用的那几个颜色，数值只写在网页配色里（DesignD+Web.swift 的 webSkin），这里从它取：
    /// 原生界面和网页用的是同一个白、同一个黑、同一档灰，接在一起看不出缝
    enum Palette {
        /// 底色：浅色纯白、深色 #0A0A0A
        static let background = webSkin.background.color
        /// 墨色：文字、能点的框的描边、实心按钮
        static let ink = webSkin.text.color
        /// 墨色实心块上面的字和图标：就是底色
        static let onInk = background
        /// 说明文字、没选中的文字、序号、占位字（对比度够读）
        static let secondary = webSkin.textSecondary.color
        /// 更淡一档，不够当文字用，只给底栏里没选中的图标
        static let faint = Color(light: 0x8C8C8C, dark: 0x6E6E6E)
        /// 细线：分隔线、不能点的面板的边
        static let stroke = webSkin.hairline.color
        /// 按下去时垫在底下的浅灰
        static let fill = webSkin.fill.color
        /// 唯一的颜色：输入光标、底栏选中项下面的那一小段线
        static let mark = WebPage.red
    }

    enum Metrics {
        /// 间距只用这几档
        static let space2: CGFloat = 2
        static let space4: CGFloat = 4
        static let space8: CGFloat = 8
        static let space12: CGFloat = 12
        static let space16: CGFloat = 16
        static let space20: CGFloat = 20
        static let space24: CGFloat = 24
        static let space28: CGFloat = 28
        /// 多行说明文字的行距
        static let lineSpacing: CGFloat = 5

        /// 文字的左右边线：靠边的文字、图标都顶着这条线
        static let gutter = space24
        /// 带框的东西（搜索框、提示框、大按钮）比文字往外多出 12，框里的内容正好落回文字的边线上
        static let boxInset = space12
        /// 框里面的留白（boxInset + boxPadding = gutter）
        static let boxPadding = space12
        /// 一个小记号和它后面的字隔这么远：序号和词、小方框和筛选、放大镜和占位字。
        /// 记号和字算一个整体，这个整体对着屏幕正中间
        static let markGap = space8

        /// 圆角：框 10、风格小图 8、框里的小块 6、小方框标记 2.5
        static let radius: CGFloat = 10
        static let radiusThumb: CGFloat = 8
        static let radiusSmall: CGFloat = 6
        static let radiusMark: CGFloat = 2.5
        /// 设置页那张纸的上面两个角：比系统默认的收敛，跟界面里别的方角是一家
        static let radiusSheet: CGFloat = 16

        /// 线宽：框和分隔线一律 1；自己画的图标用 1.4，跟系统的细线图标一样粗；选中的词下面那条墨线 2
        static let line: CGFloat = 1
        static let iconLine: CGFloat = 1.4
        static let underline: CGFloat = 2

        /// 搜索框、主要按钮的高度
        static let control: CGFloat = 48
        /// 能点的东西至少这么宽、这么高
        static let touch: CGFloat = 44
        /// 矮一档的东西：搜索框里的提交按钮、收起来的提示条、设置里的风格小图
        static let inner: CGFloat = 36
        /// 「最近」那一行小标题的高度
        static let header: CGFloat = 32
        /// 底栏的高度
        static let tabBar: CGFloat = 50
        /// 搜索结果页顶栏的高度：里面那个框是 inner 那么高，上下各留 8
        static let resultsBar: CGFloat = 52
        /// 小方框标记的边长
        static let stateMark: CGFloat = 12
        /// 首页「今天用了多久」那排刻度的宽度：60 根线，每 4pt 一根
        static let usageTicks: CGFloat = 238
        /// 首页「今天用了多久」连同它上下的留白要占这么高：最近搜索下面剩的地方不够就不显示
        static let usageRoom: CGFloat = 190
        /// 最近搜索那些词块之间的空隙（左右、上下都是这么多）：块高 inner 加上它，一行正好是 touch 那么高
        static let chipGap = touch - inner
        /// 内容最宽到这里
        static let maxWidth: CGFloat = 560
    }

    /// 文字字号四档（12 / 13 / 15 / 17），粗细只有常规和中等；数字一律用等宽字体；图标和大数字用细体
    enum Typo {
        /// 正文的字号：算「一个字多宽」的地方也用它
        static let bodySize: CGFloat = 15

        static let label = Font.system(size: 12)
        static let small = Font.system(size: 13)
        static let smallMedium = Font.system(size: 13, weight: .medium)
        static let body = Font.system(size: bodySize)
        static let bodyMedium = Font.system(size: bodySize, weight: .medium)
        static let input = Font.system(size: 17)
        static let title = Font.system(size: 17, weight: .medium)

        /// 等宽数字：跟上面四档字号一一对应
        static let monoLabel = mono(12)
        static let monoSmall = mono(13)
        static let monoBody = mono(bodySize)
        static let monoBodyMedium = mono(bodySize, .medium)
        static let monoInput = mono(17)

        /// 细线图标三档：小的（关闭、箭头尖）、中的（搜索框里、齿轮）、底栏的
        static let iconSmall = icon(14)
        static let iconMedium = icon(17)
        static let iconTab = icon(21)

        fileprivate static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }

        private static func icon(_ size: CGFloat) -> Font { .system(size: size, weight: .light) }
    }

    /// 细细的大数字（使用时间）：设置里用小的，首页用中的，提醒页用大的
    enum Display: CGFloat {
        case small = 48, medium = 64, large = 132

        var font: Font { Typo.mono(rawValue, .light) }
        /// 很大的等宽数字左边自带一截空白（字越大越明显），往左收这么多，数字的边才跟别的文字对齐
        var leadingInset: CGFloat { -rawValue * 0.06 }
        /// 数字上面、下面也各自带一截空白（大约字号的四分之一）：数字往上、往下各收这么多，
        /// 不管数字多大，压在它上面、垫在它下面的小字离数字都是 8 左右。
        /// 这个负的留白要加在数字上；加在小字上会被小字自己的高度卡住，收不够
        var captionGap: CGFloat { Metrics.space8 - rawValue * 0.24 }
    }
}

// MARK: - 小部件

extension DesignD {
    /// 一条细线
    struct Rule: View {
        var body: some View {
            Rectangle().fill(Palette.stroke).frame(height: Metrics.line)
        }
    }

    /// 小方框标记：实心 = 开 / 选中，空心 = 关 / 没选中。首页的两个筛选、设置里的风格列表都用它
    struct StateMark: View {
        let on: Bool

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Metrics.radiusMark, style: .continuous)
            shape
                .fill(on ? Palette.ink : .clear)
                .overlay { shape.strokeBorder(Palette.ink, lineWidth: Metrics.line) }
                .frame(width: Metrics.stateMark, height: Metrics.stateMark)
        }
    }

    /// 「正在忙」的标记：一根一明一暗的墨色竖条，跟输入框里那根红光标是一家。
    /// 不用系统那个转圈，它跟这套界面不是一家；也不用小方块，会被当成第三个筛选
    struct BusyMark: View {
        @State private var dim = false

        var body: some View {
            Capsule()
                .fill(Palette.ink)
                .frame(width: 2, height: 12)
                .opacity(dim ? 0.2 : 1)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { dim = true }
                }
                .accessibilityHidden(true)
        }
    }

    /// 「首页」的图标：一个小搜索框，里面一根光标。首页就是搜索；桌面图标也是这个图形。
    /// 不用放大镜：搜索框里已经有一个，上下叠着两个一样的
    struct SearchFieldGlyph: View {
        var body: some View {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(lineWidth: Metrics.iconLine)
                .frame(width: 24, height: 16)
                .overlay(alignment: .leading) {
                    Capsule()
                        .frame(width: Metrics.iconLine, height: 8)
                        .padding(.leading, 5)
                }
        }
    }

    /// 「问 AI」的图标：空心的四角星
    struct SparkGlyph: View {
        var body: some View {
            Spark()
                .stroke(style: StrokeStyle(lineWidth: Metrics.iconLine, lineJoin: .round))
                .frame(width: 20, height: 20)
        }
    }

    /// 开关：方的，像机器上的拨动开关。开 = 整块墨色、滑块在右；关 = 空心的墨线框、墨色滑块在左。
    /// 关着也用墨色：灰的会像「点不了」。
    /// 不用系统开关：系统开关染成白色以后，深色模式下白底白钮，看不出开没开
    struct Switch: View {
        let isOn: Bool

        /// 滑块离外框 3，所以外框的圆角比滑块大 3，两个圆角是同心的
        private let knobInset: CGFloat = 3
        private let knobRadius = Metrics.radiusSmall - 1

        var body: some View {
            let frame = RoundedRectangle(cornerRadius: knobRadius + knobInset, style: .continuous)
            frame
                .fill(isOn ? Palette.ink : .clear)
                .overlay { frame.strokeBorder(Palette.ink, lineWidth: Metrics.line) }
                .frame(width: 44, height: 26)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: knobRadius, style: .continuous)
                        .fill(isOn ? Palette.onInk : Palette.ink)
                        .frame(width: 20, height: 20)
                        .padding(knobInset)
                }
                .animation(.quick, value: isOn)
        }
    }

    /// 刻度条：一排细竖线，用掉多少就有多少根是墨色的，像表盘上的刻度
    struct TickBar: View {
        /// 0…1
        let fraction: Double
        @Environment(\.displayScale) private var scale

        private let count = 60

        var body: some View {
            Canvas { context, size in
                // 位置和宽度都对齐到屏幕的像素，不然细线会发虚
                let width = (1.5 * scale).rounded() / scale
                let step = (size.width - width) / CGFloat(count - 1)
                let filled = Int((min(max(fraction, 0), 1) * Double(count)).rounded())
                for index in 0..<count {
                    let x = (CGFloat(index) * step * scale).rounded() / scale
                    context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)),
                                 with: .color(index < filled ? Palette.ink : Palette.stroke))
                }
            }
            .frame(height: 14)
            .accessibilityHidden(true)
        }
    }

    /// 今天用了多少分钟，靠左的排法（设置里用）：细细的大数字，设了上限就在后面跟上「/ 上限」，下面一排刻度
    struct UsageFigure: View {
        let minutes: Int
        /// 0 = 没设上限
        let limit: Int
        let size: Display
        /// 最右边的小字（设置里写「今天」）
        var trailing: String?

        var body: some View {
            VStack(alignment: .leading, spacing: Metrics.space8) {
                HStack(alignment: .firstTextBaseline, spacing: Metrics.space8) {
                    // 数字不走本地化：不然上千以后中间会多出一个分隔符
                    Text(verbatim: String(minutes))
                        .font(size.font)
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                        .padding(.leading, size.leadingInset)
                    if limit > 0 {
                        Text(verbatim: "/ \(limit)")
                            .font(Typo.monoBody)
                            .foregroundStyle(Palette.secondary)
                    }
                    Text("分钟")
                        .font(Typo.small)
                        .foregroundStyle(Palette.secondary)
                    Spacer(minLength: 0)
                    if let trailing {
                        Text(trailing)
                            .font(Typo.small)
                            .foregroundStyle(Palette.secondary)
                    }
                }
                if limit > 0 {
                    TickBar(fraction: Double(minutes) / Double(limit))
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// 今天用了多少分钟，居中的排法：小字「今天」压在细细的大数字上面，单位垫在下面，三样都在正中间那条线上。
    /// 首页用中号，提醒页用大号
    struct UsageDial<Unit: View>: View {
        let minutes: Int
        let size: Display
        /// 数字下面那一行小字：单位，设了上限时前面带上「/ 上限」
        @ViewBuilder let unit: () -> Unit

        var body: some View {
            VStack(spacing: 0) {
                Text("今天")
                    .font(Typo.label)
                // 数字不走本地化：不然上千以后中间会多出一个分隔符
                Text(verbatim: String(minutes))
                    .font(size.font)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.vertical, size.captionGap)
                unit()
                    .font(Typo.small)
            }
            .foregroundStyle(Palette.secondary)
            .accessibilityElement(children: .combine)
        }
    }

    /// 四角星的轮廓。系统自带的那个只有实心的，跟别的细线图标放一起太重，所以自己画一个空心的
    private struct Spark: Shape {
        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let tips = [CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.midY),
                        CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.midY)]
            var path = Path()
            path.move(to: tips[3])
            for tip in tips {
                // 两个尖之间往中心凹进去
                let last = path.currentPoint ?? tip
                let middle = CGPoint(x: (last.x + tip.x) / 2, y: (last.y + tip.y) / 2)
                let control = CGPoint(x: center.x + (middle.x - center.x) * 0.24, y: center.y + (middle.y - center.y) * 0.24)
                path.addQuadCurve(to: tip, control: control)
            }
            path.closeSubpath()
            return path
        }
    }

    /// 一排选项里的一个词：选中的是墨色、字下面压一条 2pt 的墨线，没选中的是灰的。墨线贴着字，不贴底边。
    /// 消息页顶上的切换、设置里的每日提醒都用它。
    /// 先按选中时（稍粗）的样子占好位置，选中、没选中宽度一样，切换时旁边的词不会跟着挪
    struct UnderlinedLabel<Label: View, Placeholder: View, Underline: View>: View {
        let selected: Bool
        @ViewBuilder let label: () -> Label
        @ViewBuilder let placeholder: () -> Placeholder
        @ViewBuilder let underline: () -> Underline

        var body: some View {
            placeholder()
                .hidden()
                .overlay {
                    label()
                        .foregroundStyle(selected ? Palette.ink : Palette.secondary)
                        .fixedSize()
                }
                .overlay(alignment: .bottom) {
                    if selected {
                        underline()
                            .frame(height: Metrics.underline)
                            .offset(y: Metrics.space4)
                    }
                }
        }
    }

    /// 一个挨一个往右排，一行放不下就换到下一行；每一行都对着正中间那条竖线。首页的最近搜索用它。
    /// 一块比整行还宽（词特别长）时，只给它一整行那么宽，让它自己截断
    struct CenteredFlow: Layout {
        var spacing: CGFloat = Metrics.chipGap

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let width = proposal.width ?? .infinity
            let lines = lines(width: width, subviews: subviews)
            let height = lines.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, lines.count - 1))
            return CGSize(width: proposal.width ?? lines.map(\.width).max() ?? 0, height: height)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var y = bounds.minY
            for line in lines(width: bounds.width, subviews: subviews) {
                var x = bounds.midX - line.width / 2
                for (index, size) in zip(line.members, line.sizes) {
                    subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                    x += size.width + spacing
                }
                y += line.height + spacing
            }
        }

        /// 一行里有哪几块、各多大，合起来多宽多高
        private struct Line {
            var members: [Int] = []
            var sizes: [CGSize] = []
            var width: CGFloat = 0
            var height: CGFloat = 0
        }

        private func lines(width: CGFloat, subviews: Subviews) -> [Line] {
            var result: [Line] = []
            var current = Line()
            for index in subviews.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
                let grown = current.width + (current.members.isEmpty ? 0 : spacing) + size.width
                if !current.members.isEmpty && grown > width {
                    result.append(current)
                    current = Line()
                }
                current.width += (current.members.isEmpty ? 0 : spacing) + size.width
                current.height = max(current.height, size.height)
                current.members.append(index)
                current.sizes.append(size)
            }
            if !current.members.isEmpty { result.append(current) }
            return result
        }
    }

    /// 按下时只变淡，不缩放：干脆一点
    struct Press: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.45 : 1)
                .animation(.quick, value: configuration.isPressed)
        }
    }

    /// 整行能点的：按下时垫一层浅灰
    struct RowPress: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(configuration.isPressed ? Palette.fill : .clear)
        }
    }

    /// 实心 / 描边的长方形按钮
    struct BoxButton: ButtonStyle {
        var filled = true
        var height: CGFloat = Metrics.control
        var radius: CGFloat = Metrics.radius

        func makeBody(configuration: Configuration) -> some View {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            configuration.label
                .font(Typo.bodyMedium)
                .foregroundStyle(filled ? Palette.onInk : Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(filled ? Palette.ink : Palette.background, in: shape)
                .overlay { shape.strokeBorder(Palette.ink, lineWidth: Metrics.line) }
                .contentShape(shape)
                .opacity(configuration.isPressed ? 0.6 : 1)
                .animation(.quick, value: configuration.isPressed)
        }
    }
}
