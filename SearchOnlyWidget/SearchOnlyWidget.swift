import SwiftUI
import WidgetKit

// 桌面 / 锁屏小组件：点一下打开只搜，直接停在搜索框上、弹出键盘。
// 小组件里不显示任何内容，只是一个「搜索框」入口（网友建议：桌面放个搜索框，点进去直接搜）

struct Entry: TimelineEntry {
    let date: Date
}

/// 内容不会变，只要一条，永不刷新
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

struct SearchWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "magnifyingglass").font(.title2.weight(.semibold))
            }
        case .accessoryRectangular:
            Label("搜小红书", systemImage: "magnifyingglass").font(.headline)
        case .accessoryInline:
            Label("搜小红书", systemImage: "magnifyingglass")
        default:
            VStack(alignment: .leading, spacing: 10) {
                Text("只搜").font(.headline)
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("想查什么？")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .background(.quaternary, in: Capsule())
                Text("不打扰，不推荐，你主动搜索")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

@main
struct SearchOnlyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SearchOnlyWidget", provider: Provider()) { _ in
            SearchWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "searchonly://search"))
        }
        .configurationDisplayName("搜小红书")
        .description("点一下直接搜索，不经过推荐流")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
