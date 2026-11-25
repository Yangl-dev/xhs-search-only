import SwiftUI

// 「极简」的设置页。规范和小部件见 DesignD.swift

extension DesignD {
    /// 设置页：首页右上角的齿轮打开。跟首页一样的平底色，不用卡片：
    /// 小小的灰色分组名压着一条细线，下面一行一行用细线隔开，数值靠右、用等宽数字
    struct SettingsSheet: View {
        @ObservedObject var browser: Browser
        @ObservedObject private var usage = UsageTimer.shared
        @Environment(\.dismiss) private var dismiss
        /// 内容是不是已经往上滚了：滚了就在标题下面画一条线，把标题和内容分开
        @State private var scrolled = false

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("设置")
                        .font(Typo.title)
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button { dismiss() } label: {
                        Text("完成")
                            .font(Typo.bodyMedium)
                            .foregroundStyle(Palette.ink)
                            .frame(width: Metrics.touch, height: Metrics.touch, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(Press())
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, Metrics.space20)
                .padding(.bottom, Metrics.space4)
                .overlay(alignment: .bottom) { Rule().opacity(scrolled ? 1 : 0) }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Metrics.space28) {
                            section("界面风格") {
                                ForEach(UIStyle.allCases) { style in
                                    styleRow(style)
                                    Rule()
                                }
                                note(Text("四套风格随时可以换，换风格时桌面图标也跟着换。"))
                            }
                            section("少一点干扰") {
                                toggle("灰度模式", "图片和视频都变成黑白", $browser.grayscale)
                                Rule()
                                toggle("封面先模糊", "看标题决定点不点，点进笔记是清楚的", $browser.blurImages)
                                Rule()
                                toggle("视频点了才播", "打开视频笔记不会自己开始播放", $browser.tapToPlay)
                            }
                            section("使用时间") {
                                usageSummary
                                Rule()
                                limitPicker
                                Rule()
                                note(Text("只算 app 开着的时间，每天零点重新算。到点提醒一次，之后每多用 \(Text(verbatim: "10").font(Typo.monoSmall)) 分钟再提醒一次。"))
                            }
                            section("隐私") {
                                note(Text("只搜是小红书网页版外面的一层壳：不调用私有接口、不抓取数据，也不读取或保存你的账号密码。设置和使用时间只存在这台手机上。"))
                            }
                            .id("end")
                        }
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.top, Metrics.space12)
                        .padding(.bottom, Metrics.space28)
                        .frame(maxWidth: Metrics.maxWidth)
                        .frame(maxWidth: .infinity)
                        .onGeometryChange(for: Bool.self) { $0.frame(in: .named("settings")).minY < -1 } action: { scrolled = $0 }
                    }
                    .coordinateSpace(.named("settings"))
                    .task {
                        // 截图用：直接滑到底（等内容排好再滑）
                        guard UIDemo.state == "settings-bottom" else { return }
                        try? await Task.sleep(for: .seconds(0.5))
                        proxy.scrollTo("end", anchor: .bottom)
                    }
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .overlay(alignment: .top) { topEdge }
            .presentationBackground(Palette.background)
            .presentationCornerRadius(Metrics.radiusSheet)
            .presentationDragIndicator(.visible)
            .onAppear { usage.tick() } // 「今天已用」显示到这一刻
        }

        // MARK: 搭页面用的几块

        /// 这张纸的顶边：沿着上边和两个圆角描一条细线。
        /// 深色模式下纸和后面压暗的首页几乎一样黑，没有这条线就看不出是一张升起来的纸
        private var topEdge: some View {
            UnevenRoundedRectangle(topLeadingRadius: Metrics.radiusSheet, topTrailingRadius: Metrics.radiusSheet, style: .continuous)
                .strokeBorder(Palette.stroke, lineWidth: Metrics.line)
                .frame(height: Metrics.radiusSheet * 2)
                .mask(alignment: .top) { Rectangle().frame(height: Metrics.radiusSheet) }
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }

        /// 一组：灰色的小标题，下面一条线，然后是内容
        private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Typo.label)
                    .foregroundStyle(Palette.secondary)
                    .padding(.bottom, Metrics.space8)
                Rule()
                content()
            }
        }

        /// 一段灰色的说明（传 Text 进来：里面的数字可以单独换成等宽字体）
        private func note(_ text: Text) -> some View {
            text
                .font(Typo.small)
                .foregroundStyle(Palette.secondary)
                .lineSpacing(Metrics.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Metrics.space12)
        }

        /// 一种界面风格：图标小图 + 名字 + 一句话；最右边的小方框实心的就是现在用的，跟整行上下居中
        private func styleRow(_ style: UIStyle) -> some View {
            let selected = browser.style == style
            let shape = RoundedRectangle(cornerRadius: Metrics.radiusThumb, style: .continuous)
            return Button { browser.style = style } label: {
                HStack(spacing: Metrics.space8) {
                    Image(decorative: style.previewImage)
                        .resizable()
                        .frame(width: Metrics.inner, height: Metrics.inner)
                        .clipShape(shape)
                        .overlay { shape.strokeBorder(Palette.stroke, lineWidth: Metrics.line) }
                        .padding(.trailing, Metrics.space4)
                    VStack(alignment: .leading, spacing: Metrics.space4) {
                        Text(style.name)
                            .font(selected ? Typo.bodyMedium : Typo.body)
                            .foregroundStyle(Palette.ink)
                        Text(style.summary)
                            .font(Typo.small)
                            .foregroundStyle(Palette.secondary)
                            .lineLimit(2)
                    }
                    // 右边的标记挨得紧一点，让出地方，最长的那句说明在一行里放得下
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if selected {
                        Text("正在用")
                            .font(Typo.label)
                            .foregroundStyle(Palette.secondary)
                            .fixedSize()
                    }
                    StateMark(on: selected)
                }
                .padding(.vertical, Metrics.space12)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPress())
            .accessibilityAddTraits(selected ? .isSelected : [])
        }

        /// 一个开关：整行都能点
        private func toggle(_ title: String, _ detail: String, _ isOn: Binding<Bool>) -> some View {
            Button { isOn.wrappedValue.toggle() } label: {
                HStack(spacing: Metrics.space12) {
                    VStack(alignment: .leading, spacing: Metrics.space4) {
                        Text(title).font(Typo.body).foregroundStyle(Palette.ink)
                        Text(detail).font(Typo.small).foregroundStyle(Palette.secondary)
                    }
                    Spacer(minLength: 0)
                    Switch(isOn: isOn.wrappedValue)
                }
                .padding(.vertical, Metrics.space12)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPress())
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(isOn.wrappedValue ? "开" : "关")
        }

        /// 今天用了多少
        private var usageSummary: some View {
            UsageFigure(minutes: usage.todayMinutes, limit: usage.limitMinutes, size: .small, trailing: "今天")
                .padding(.top, Metrics.space8)
                .padding(.bottom, Metrics.space16)
        }

        /// 每日提醒：标题右边是现在的值；下面一排等宽的数字从左边线铺到右边线，
        /// 现在选的那个是墨色、下面压着一条墨线（跟消息页顶上的切换一个样子）
        private var limitPicker: some View {
            // 最窄的是「关」：只有一个字宽，左右各多出这么多能点的范围，正好够宽
            let reach = (Metrics.touch - Typo.bodySize) / 2
            let choices = UsageTimer.limitChoices
            return VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: Metrics.space4) {
                    Text("每日提醒").font(Typo.body).foregroundStyle(Palette.ink)
                    Spacer()
                    if usage.limitMinutes == 0 {
                        Text("不提醒").font(Typo.small)
                    } else {
                        Text(verbatim: String(usage.limitMinutes)).font(Typo.monoSmall)
                        Text("分钟").font(Typo.small)
                    }
                }
                .foregroundStyle(Palette.secondary)
                .padding(.top, Metrics.space12)
                HStack(spacing: 0) {
                    ForEach(choices, id: \.self) { minutes in
                        let selected = usage.limitMinutes == minutes
                        let title = minutes == 0 ? "关" : String(minutes)
                        Button { usage.limitMinutes = minutes } label: {
                            UnderlinedLabel(selected: selected) {
                                Text(verbatim: title).font(selected ? Typo.monoBodyMedium : Typo.monoBody)
                            } placeholder: {
                                Text(verbatim: title).font(Typo.monoBodyMedium)
                            } underline: {
                                Rectangle().fill(Palette.ink)
                            }
                            .frame(maxHeight: .infinity)
                            // 占的位置只有字那么宽（这样第一个、最后一个的字正好顶着两条边线），能点的范围往两边伸出去
                            .padding(.horizontal, reach)
                            .contentShape(Rectangle())
                            .padding(.horizontal, -reach)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(minutes == 0 ? "关" : "\(minutes) 分钟")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        if minutes != choices.last {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(height: Metrics.touch)
                .animation(.quick, value: usage.limitMinutes)
            }
        }
    }
}
