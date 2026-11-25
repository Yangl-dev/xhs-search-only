import SwiftUI

// 「原味」这一套（DesignA.swift）的设计规范：颜色、字号、图标大小、圆角、线的粗细、投影、几块界面共用的尺寸和小部件都在这里，
// 界面代码只用这里的名字。间距和只用一次的小尺寸在界面代码里直接写数字，都是 4 的倍数。
// 视觉语言跟小红书 app 走（参考它网页版的样式和公开的设计分析，只取数值和思路）：
// - 红色 #FF2442 是唯一的鲜艳颜色，只用在重点上：字标、主要按钮、选中标签的下划线、开关、进度条
// - 文字是同一种黑色的四档深浅（标题 / 正文 / 说明 / 占位），深色模式下换成白色
// - 底色白，输入框和小标签用浅灰实心填充、不描边；圆角只有 8 / 16 和胶囊
// - 深色模式用不带颜色的纯灰，一层比一层亮一点：页面 → 设置页 → 卡片 → 卡片上的小块
// - 图标用系统自带的线条符号，中等粗细，跟文字一个颜色；不用彩色图标
// - 红色的字一律用半粗（红字压在浅灰、淡红底上对比度偏低，靠字重补）
// - 能点的东西至少 44 见方：看着小的（小标签、垃圾桶、关闭）靠 TapStyle 把能点的范围往外扩
// - 动效短而平：0.2 秒左右

extension DesignA {
    enum Theme {
        // MARK: 颜色（底色、卡片、浅灰块、分隔线、红色跟网页配色是同一组数，见 DesignA+Web.swift：
        // 首页、底栏、顶栏和网页接在一起是连着的一整块，没有色差）

        static let brand = DesignA.webSkin.accent.color
        /// 选中的小标签、提醒卡图标的淡红底
        static let brandSoft = Color(light: 0xFFF0F2, dark: 0x2E1418)

        /// 页面底色，也是紧挨着网页的底栏、顶栏的底色
        static let background = DesignA.webSkin.background.color
        /// 设置页这种分组页面的底色
        static let groupedBackground = Color(light: 0xF5F5F5, dark: 0x141414)
        /// 卡片：设置页的分组、提醒卡、扫码提示
        static let surface = DesignA.webSkin.surface.color
        /// 页面上的浅灰实心块：搜索框、小标签、提示卡
        static let fill = DesignA.webSkin.fill.color
        /// 卡片上的浅灰实心块：图标底、进度条的槽、关闭按钮
        static let surfaceFill = Color(light: 0xF5F5F5, dark: 0x2C2C2C)
        /// 细分隔线
        static let hairline = DesignA.webSkin.hairline.color
        /// 图标小图外面的一圈线：白底的图标放在白卡片上，靠它看出是个方块
        static let outline = Color.primary.opacity(0.12)
        /// 提醒卡后面压暗整个界面的那一层
        static let scrim = Color.black.opacity(0.4)
        /// 浮在网页上的深色胶囊
        static let floating = Color(light: 0x222222, dark: 0x333333)
        /// 深色胶囊外面一圈很淡的亮边
        static let floatingEdge = Color.white.opacity(0.14)

        /// 标题、选中的文字
        static let textPrimary = Color.primary.opacity(0.88)
        /// 正文
        static let textBody = Color.primary.opacity(0.68)
        /// 说明、没选中的文字、图标（在白底和浅灰底上对比度都够 4.5:1）
        static let textSecondary = Color.primary.opacity(0.56)
        /// 输入框占位
        static let textPlaceholder = Color.primary.opacity(0.32)

        // MARK: 字号（只有这五档）

        /// 字标、「今天用了多少」的大数字
        static let sizeDisplay: CGFloat = 32
        /// 提醒卡的标题
        static let sizeTitle: CGFloat = 20
        /// 输入的字、每一行的标题、底栏、按钮
        static let sizeHeadline: CGFloat = 16
        /// 正文、小标签
        static let sizeBody: CGFloat = 14
        /// 说明
        static let sizeCaption: CGFloat = 13
        /// 多行文字的行间距
        static let lineSpacing: CGFloat = 3

        // MARK: 图标大小（紧跟着文字的图标用那行字的字号；单独出现的只有这三档）

        /// 关闭的叉、菜单的小箭头、筛选标签上的符号
        static let iconSmall: CGFloat = 12
        /// 齿轮、设置行前面的符号
        static let iconMedium: CGFloat = 16
        /// 提醒卡的沙漏
        static let iconLarge: CGFloat = 24

        // MARK: 间距（界面代码里直接写数字，只用 4 / 8 / 12 / 16 / 20 / 24 / 32；有名字的是下面三个）

        /// 页面左右留白
        static let gutter: CGFloat = 16
        /// 卡片里面的留白
        static let cardPadding: CGFloat = 16
        /// 一行的标题和它下面那句说明之间：两行是一个整体，贴得比别处近
        static let titleGap: CGFloat = 2

        // MARK: 圆角和大小

        /// 设置行前面的图标底
        static let radiusSmall: CGFloat = 8
        /// 卡片：设置页的分组、提醒卡、扫码提示、首页的提示卡
        static let radiusLarge: CGFloat = 16
        /// 搜索框、主要按钮的高度；也是能点的东西最小的高和宽
        static let controlHeight: CGFloat = 44
        /// 小标签的高度
        static let chipHeight: CGFloat = 36
        /// 小标签里的字最宽到这里，再长就截断
        static let chipMaxWidth: CGFloat = 260
        /// 浮在网页上的胶囊按钮的高度
        static let pillHeight: CGFloat = 40
        /// 底栏的高度
        static let tabBarHeight: CGFloat = 52
        /// 提醒卡最宽多少；首页、设置、扫码提示在宽屏上最宽多少
        static let reminderWidth: CGFloat = 320
        static let contentMaxWidth: CGFloat = 560

        // MARK: 线的粗细

        static let hairlineWidth: CGFloat = 0.5
        /// 图标小图外面那一圈
        static let outlineWidth: CGFloat = 1
        /// 网页顶上的加载进度条
        static let loadingHeight: CGFloat = 2
        /// 选中标签下面的红色短线
        static let underlineSize = CGSize(width: 20, height: 3)
        /// 「今天用了多少」的进度条
        static let progressHeight: CGFloat = 6

        // MARK: 投影和动效

        /// 浮在网页上的东西（扫码提示、胶囊按钮）的投影
        static let shadow = Color.black.opacity(0.12)
        static let shadowRadius: CGFloat = 16
        static let shadowY: CGFloat = 8

        static let animation = Animation.easeOut(duration: 0.2)
    }

    // MARK: - 这一套的小部件

    /// 按钮样式：按下时变淡、缩一点；能点的范围可以比看得见的往外多出一圈（凑够 44），排版仍按看得见的大小算
    struct TapStyle: ButtonStyle {
        var horizontal: CGFloat = 0
        var vertical: CGFloat = 0

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.horizontal, horizontal)
                .padding(.vertical, vertical)
                .contentShape(Rectangle())
                .padding(.horizontal, -horizontal)
                .padding(.vertical, -vertical)
                .opacity(configuration.isPressed ? 0.6 : 1)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(Theme.animation, value: configuration.isPressed)
        }
    }

    /// 设置里整行能点的那种按钮：按下时整行变成浅灰
    struct RowButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .contentShape(Rectangle())
                .background(configuration.isPressed ? Theme.surfaceFill : .clear)
        }
    }

    /// 小标签。两种：最近搜索的词只有字；「只看图文」这类开关前面带一个符号（跟设置里那一行的一样），
    /// 开着是淡红底红字，关着是浅灰底。符号一直在，开和关一样宽，不会把旁边的标签推来推去
    struct Chip: View {
        let title: String
        var systemImage: String?
        var selected = false
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 4) {
                    if let systemImage {
                        Image(systemName: systemImage).font(.system(size: Theme.iconSmall, weight: .medium))
                        // 开关的字按半粗留位置：开着时字变粗，标签不跟着变宽
                        Text(title).fontWeight(.semibold).hidden()
                            .overlay { Text(title).fontWeight(selected ? .semibold : .regular) }
                    } else {
                        // 太长的词截断，不把一行撑出屏幕
                        Text(title).lineLimit(1).frame(maxWidth: Theme.chipMaxWidth)
                    }
                }
                .font(.system(size: Theme.sizeBody))
                .foregroundStyle(selected ? Theme.brand : Theme.textBody)
                // 有多少字占多宽，不被并排的东西拉长
                .fixedSize()
                // 前面有符号的那一头少留一点，看起来两头才一样宽
                .padding(.leading, systemImage == nil ? 16 : 12)
                .padding(.trailing, 16)
                .frame(height: Theme.chipHeight)
                .background(selected ? Theme.brandSoft : Theme.fill, in: Capsule())
            }
            .buttonStyle(TapStyle(vertical: (Theme.controlHeight - Theme.chipHeight) / 2))
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    /// 胶囊按钮：主要的是品牌红实心；并排两个时，不是首选的那个用次要的（卡片上的浅灰底、深色字）
    struct PillButtonStyle: ButtonStyle {
        var secondary = false

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: Theme.sizeHeadline, weight: .semibold))
                .foregroundStyle(secondary ? Theme.textPrimary : Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.controlHeight)
                .background(secondary ? Theme.surfaceFill : Theme.brand, in: Capsule())
                .opacity(configuration.isPressed ? 0.8 : 1)
                .animation(Theme.animation, value: configuration.isPressed)
        }
    }

    /// 设置行前面的小图标：浅灰圆角方块里一个深色符号，不用五颜六色
    struct SettingIcon: View {
        static let size: CGFloat = 30
        let systemImage: String

        var body: some View {
            Image(systemName: systemImage)
                .font(.system(size: Theme.iconMedium, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: Self.size, height: Self.size)
                .background(Theme.surfaceFill, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        }
    }

    /// 一句说明：一行排得下就排一行；排不下就在第一个冒号或逗号后面断开，
    /// 免得第二行只剩一两个字
    struct Detail: View {
        let text: String

        var body: some View {
            ViewThatFits(in: .horizontal) {
                Text(text).lineLimit(1)
                Text(broken).lineSpacing(Theme.lineSpacing).fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: Theme.sizeCaption))
            .foregroundStyle(Theme.textSecondary)
        }

        private var broken: String {
            guard let index = text.firstIndex(where: { $0 == "：" || $0 == "，" }) else { return text }
            let next = text.index(after: index)
            return text[..<next] + "\n" + text[next...]
        }
    }

    /// 一行排不下就换行的排列，每一行都居中：首页最近搜索的小标签用
    struct CenteredFlow: Layout {
        var spacing: CGFloat = 8

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
            return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                          height: rows.last.map { $0.y + $0.height } ?? 0)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            for row in arrange(width: bounds.width, subviews: subviews) {
                var x = bounds.minX + (bounds.width - row.width) / 2
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

    /// 卡片上的细分隔线
    struct Hairline: View {
        var body: some View {
            Rectangle().fill(Theme.hairline).frame(height: Theme.hairlineWidth)
        }
    }

    /// 首页的提示卡折到键盘后面时，原地留的那一行入口用：往上滑、卡片快要从键盘后面出来时，这一行淡出去。
    /// 卡片露头之前它已经全隐了：同一句标题不会上下出现两遍，两样东西也不会叠在一起
    struct FadesAsCardAppears: ViewModifier {
        /// 键盘上沿在屏幕上的位置
        let keyboardTop: CGFloat
        /// 卡片的上沿在这一行底边往下多远（卡片比这一行的底边还高时是负的）
        let cardBelow: CGFloat
        /// 没滑动时卡片的上沿排在键盘上沿以下多远：还在那儿时这一行全显，升到键盘上沿时全隐
        let margin: CGFloat

        func body(content: Content) -> some View {
            content.visualEffect { [keyboardTop, cardBelow, margin] view, proxy in
                // 卡片的上沿还在键盘上沿以下多远
                let hidden: CGFloat = proxy.frame(in: .global).maxY + cardBelow - keyboardTop
                return view.opacity(min(max(hidden / margin, 0), 1))
            }
        }
    }

    /// 量键盘上沿在屏幕上的位置，键盘走到哪就报到哪。用系统给的键盘参考线，不听键盘通知：
    /// 手指拖着往下收键盘的那一段系统不发通知，松手才发；参考线是一直跟着键盘走的。
    /// 键盘收着的时候，报的是放它的这一块自己的底边
    struct KeyboardTop: UIViewRepresentable {
        /// 位置变了就叫一次。animated：系统正在用动画挪键盘（弹出、收起），不是跟着手指一点点走
        let onChange: (_ top: CGFloat, _ animated: Bool) -> Void

        func makeUIView(context: Context) -> Probe { Probe() }

        func updateUIView(_ view: Probe, context: Context) { view.onChange = onChange }

        final class Probe: UIView {
            var onChange: ((CGFloat, Bool) -> Void)?
            /// 底边贴在键盘上沿的一个看不见的小块：键盘一动它就跟着动，这里就会重新排一次
            private let marker = UIView()
            private var reported: CGFloat?

            override init(frame: CGRect) {
                super.init(frame: frame)
                isUserInteractionEnabled = false
                marker.isHidden = true
                marker.translatesAutoresizingMaskIntoConstraints = false
                addSubview(marker)
                NSLayoutConstraint.activate([
                    marker.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
                    marker.leadingAnchor.constraint(equalTo: leadingAnchor),
                    marker.widthAnchor.constraint(equalToConstant: 1),
                    marker.heightAnchor.constraint(equalToConstant: 1),
                ])
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) { fatalError("只用代码创建") }

            override func layoutSubviews() {
                super.layoutSubviews()
                guard window != nil, let onChange else { return }
                let top = convert(marker.frame, to: nil).maxY
                guard top != reported else { return }
                reported = top
                onChange(top, UIView.inheritedAnimationDuration > 0)
            }
        }
    }
}
