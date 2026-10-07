import SwiftUI
import WidgetKit

struct NextBeatEntry: TimelineEntry {
    let date: Date
    let snapshot: DaySnapshot
    let error: String?
}

struct NextBeatProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextBeatEntry {
        NextBeatEntry(date: PreviewFixtures.time(9, 30),
                     snapshot: PlanEngine.snapshot(for: PreviewFixtures.week, at: PreviewFixtures.time(9, 30)), error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextBeatEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(entry(at: .now))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextBeatEntry>) -> Void) {
        let now = Date.now
        do {
            let plans = try PlanRepository.appGroup().load()
            let horizon = now.addingTimeInterval(8 * 24 * 60 * 60)
            let dates = PlanEngine.timelineDates(in: plans, from: now, through: horizon)
            let entries = dates.map { NextBeatEntry(date: $0, snapshot: PlanEngine.snapshot(in: plans, at: $0), error: nil) }
            // WidgetKit chooses when to display entries. Reload requests after edits may also be deferred by iOS.
            completion(Timeline(entries: entries, policy: .after(horizon)))
        } catch {
            completion(Timeline(entries: [NextBeatEntry(date: now, snapshot: .noPlan, error: error.localizedDescription)],
                                policy: .after(now.addingTimeInterval(15 * 60))))
        }
    }

    private func entry(at date: Date) -> NextBeatEntry {
        do {
            let plans = try PlanRepository.appGroup().load()
            return NextBeatEntry(date: date, snapshot: PlanEngine.snapshot(in: plans, at: date), error: nil)
        } catch {
            return NextBeatEntry(date: date, snapshot: .noPlan, error: error.localizedDescription)
        }
    }
}

struct NextBeatWidgetEntryView: View {
    let entry: NextBeatEntry
    var familyOverride: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var environmentFamily

    var body: some View {
        Group {
            if (familyOverride ?? environmentFamily) == .systemSmall {
                smallView
            } else {
                mediumView
            }
        }
        .containerBackground(for: .widget) { Color(uiColor: .secondarySystemGroupedBackground) }
        .widgetURL(URL(string: "nextbeat://home"))
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("NextBeat", systemImage: "sun.max.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.teal)
                Spacer(minLength: 5)
                if let today = entry.snapshot.today {
                    Text(String(today.suffix(5)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let error = entry.error {
                Text("共享数据配置错误")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption2)
                    .lineLimit(3)
            } else {
                statusContent(isSmall: false)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NEXTBEAT")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.teal)
            if entry.error != nil {
                Text("共享数据错误")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text("轻点打开 App 查看配置")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                statusContent(isSmall: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
    }

    @ViewBuilder
    private func statusContent(isSmall: Bool) -> some View {
        switch entry.snapshot.phase {
        case .current:
            if let current = entry.snapshot.current {
                Text("正在进行 · \(current.item.end) 结束")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.teal)
                    .lineLimit(1)
                Text(current.item.title)
                    .font(isSmall ? .headline : .title3.bold())
                    .lineLimit(isSmall ? 2 : 2)
                    .minimumScaleFactor(0.8)
                if !current.item.tip.isEmpty {
                    Text(current.item.tip)
                        .font(isSmall ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let next = entry.snapshot.next {
                    Text("下一项  \(next.item.start)  \(next.item.title)")
                        .font(isSmall ? .caption2.monospacedDigit() : .caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(isSmall ? 2 : 1)
                } else if !isSmall {
                    Text("今天没有下一项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .gap:
            if let next = entry.snapshot.next {
                Text("当前空档 · 下一项 \(next.item.start)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.teal)
                    .lineLimit(1)
                Text(next.item.title)
                    .font(isSmall ? .headline : .title3.bold())
                    .lineLimit(2)
                if !next.item.tip.isEmpty {
                    Text(next.item.tip)
                        .font(isSmall ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isSmall ? 1 : 2)
                }
            }
        case .done:
            Text("今日已完成")
                .font(isSmall ? .headline : .title3.bold())
            Text("今天的安排已结束")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .emptyDay:
            Text("今天没有安排")
                .font(isSmall ? .headline : .title3.bold())
            Text("享受这一天")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .noPlan:
            Text("本周没有计划")
                .font(isSmall ? .headline : .title3.bold())
            Text("轻点打开 App 导入七天日程")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

struct NextBeatWidget: Widget {
    let kind = "NextBeatWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextBeatProvider()) { entry in
            NextBeatWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NextBeat 日程")
        .description("查看正在进行的事项、提示和下一项。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct NextBeatWidgetBundle: WidgetBundle {
    var body: some Widget { NextBeatWidget() }
}

private func previewEntry(_ hour: Int, _ minute: Int, plans: [WeekPlan] = [PreviewFixtures.week]) -> NextBeatEntry {
    let date = PreviewFixtures.time(hour, minute)
    return NextBeatEntry(date: date, snapshot: PlanEngine.snapshot(in: plans, at: date), error: nil)
}

#Preview("中号 · 时间切换", as: .systemMedium, widget: {
    NextBeatWidget()
}, timeline: {
    previewEntry(9, 30)
    previewEntry(10, 45)
    previewEntry(11, 30)
    previewEntry(18, 0)
})

#Preview("中号 · 无计划", as: .systemMedium, widget: {
    NextBeatWidget()
}, timeline: {
    previewEntry(9, 30, plans: [])
})

#Preview("小号 · 当前任务", as: .systemSmall, widget: {
    NextBeatWidget()
}, timeline: {
    previewEntry(9, 30)
})

#Preview("深色模式") {
    NextBeatWidgetEntryView(entry: previewEntry(9, 30), familyOverride: .systemMedium)
        .frame(width: 329, height: 155)
        .preferredColorScheme(.dark)
}
