import SwiftUI

private enum NextBeatTab: Hashable { case today, week, importPlan }

struct ContentView: View {
    @EnvironmentObject private var model: NextBeatModel
    @State private var tab: NextBeatTab = .today

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView() }
                .tabItem { Label("今日", systemImage: "sun.max") }
                .tag(NextBeatTab.today)
            NavigationStack { WeekView() }
                .tabItem { Label("周计划", systemImage: "calendar") }
                .tag(NextBeatTab.week)
            NavigationStack { ImportView() }
                .tabItem { Label("导入", systemImage: "square.and.arrow.down") }
                .tag(NextBeatTab.importPlan)
        }
        .tint(.teal)
        .overlay(alignment: .top) {
            if let issue = model.storageIssue {
                Text("共享存储错误：\(issue)")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.red)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: NextBeatModel
    var now: Date? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let snapshot = PlanEngine.snapshot(in: model.plans, at: now ?? context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("今天，按自己的节奏")
                            .font(.title.bold())
                        Text(snapshot.today.map { "\($0) · \(snapshot.timezone ?? "")" } ?? "当前没有可用的本周计划")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    DayStatusCard(snapshot: snapshot)

                    if snapshot.phase == .noPlan {
                        Text("在“导入”页粘贴 Muse 生成的七天 JSON，验证后保存。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    } else if let plan = PlanEngine.activePlan(in: model.plans, at: now ?? context.date),
                              let day = plan.days.first(where: { $0.date == snapshot.today }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("今日课表")
                                .font(.headline)
                            if day.items.isEmpty {
                                Text("今天没有安排事项")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(day.items.indices, id: \.self) { index in
                                    TaskRow(item: day.items[index],
                                            isCurrent: snapshot.current?.item == day.items[index],
                                            isPast: ClockTime(day.items[index].end, allowsDayEnd: true).map { end in
                                                let calendar = PlanValidator.calendar(for: TimeZone(identifier: plan.timezone)!)
                                                let dayStart = PlanValidator.parseDate(day.date, calendar: calendar)!
                                                return (PlanValidator.makeDate(day: dayStart, time: end, calendar: calendar) ?? .distantFuture) <= (now ?? context.date)
                                            } ?? false)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationTitle("NextBeat")
    }
}

struct DayStatusCard: View {
    let snapshot: DaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch snapshot.phase {
            case .current:
                if let current = snapshot.current {
                    Label("正在进行", systemImage: "circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.teal)
                    Text(current.item.title)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(current.item.start)–\(current.item.end) · \(current.item.end) 结束")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if !current.item.tip.isEmpty {
                        Text(current.item.tip)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Divider()
                    if let next = snapshot.next {
                        nextLine(next)
                    } else {
                        Text("今天没有下一项")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            case .gap:
                Label("当前是日程空档", systemImage: "cup.and.saucer")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.teal)
                if let next = snapshot.next {
                    Text("接下来 · \(next.item.start)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(next.item.title)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    if !next.item.tip.isEmpty { Text(next.item.tip).foregroundStyle(.secondary) }
                }
            case .done:
                Label("今日已完成", systemImage: "checkmark.circle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.teal)
                Text("今天的计划都完成了，休息一下吧。")
                    .foregroundStyle(.secondary)
            case .emptyDay:
                Label("今天没有安排", systemImage: "leaf")
                    .font(.title2.bold())
                    .foregroundStyle(.teal)
                Text("本周计划已保存，这一天的 items 是空数组。")
                    .foregroundStyle(.secondary)
            case .noPlan:
                Label("本周还没有计划", systemImage: "calendar.badge.plus")
                    .font(.title2.bold())
                    .foregroundStyle(.teal)
                Text("导入一份完整的七天计划后，桌面小组件也会显示。")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private func nextLine(_ next: TaskOccurrence) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("下一项")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(next.item.start)
                .font(.subheadline.monospacedDigit().weight(.semibold))
            Text(next.item.title)
                .font(.subheadline)
                .lineLimit(2)
        }
    }
}

struct TaskRow: View {
    let item: ScheduleItem
    var isCurrent = false
    var isPast = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.start)
                Text(item.end)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.monospacedDigit())
            .frame(width: 48, alignment: .leading)
            Rectangle()
                .fill(isCurrent ? Color.teal : Color.gray.opacity(0.35))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.body.weight(isCurrent ? .semibold : .regular))
                        .fixedSize(horizontal: false, vertical: true)
                    if isCurrent { Image(systemName: "circle.fill").font(.caption2).foregroundStyle(.teal) }
                }
                if !item.tip.isEmpty {
                    Text(item.tip)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(isPast ? Color.secondary : Color.primary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? Color.teal.opacity(0.10) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 15))
        .accessibilityElement(children: .combine)
    }
}

#Preview("当前任务") {
    NavigationStack { HomeView(now: PreviewFixtures.time(9, 30)) }
        .environmentObject(NextBeatModel(previewPlans: [PreviewFixtures.week]))
}

#Preview("当前任务 · 长标题") {
    NavigationStack { HomeView(now: PreviewFixtures.time(11, 30)) }
        .environmentObject(NextBeatModel(previewPlans: [PreviewFixtures.week]))
        .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("空档 · 深色") {
    NavigationStack { HomeView(now: PreviewFixtures.time(10, 45)) }
        .environmentObject(NextBeatModel(previewPlans: [PreviewFixtures.week]))
        .preferredColorScheme(.dark)
}

#Preview("全天结束") {
    NavigationStack { HomeView(now: PreviewFixtures.time(18, 0)) }
        .environmentObject(NextBeatModel(previewPlans: [PreviewFixtures.week]))
}

#Preview("无计划 · 大字") {
    NavigationStack { HomeView(now: PreviewFixtures.time(9, 30)) }
        .environmentObject(NextBeatModel(previewPlans: []))
        .environment(\.dynamicTypeSize, .accessibility2)
}
