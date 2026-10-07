import SwiftUI
import UIKit

private struct EditorRoute: Identifiable {
    let id = UUID()
    let week: String
    let day: String
    let index: Int?
    let item: ScheduleItem?
}

struct WeekView: View {
    @EnvironmentObject private var model: NextBeatModel
    @State private var selectedDay: String?
    @State private var editor: EditorRoute?
    @State private var showingExport = false
    @State private var actionError: String?

    private var plan: WeekPlan? { model.selectedPlan }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let plan {
                    weekHeader(plan)
                    daySelector(plan)
                    if let day = plan.days.first(where: { $0.date == selectedDay }) ?? plan.days.first {
                        TimelineView(.periodic(from: .now, by: 30)) { timeline in
                            dayContent(plan: plan, day: day, now: timeline.date)
                        }
                    }
                } else {
                    ContentUnavailableView("还没有周计划", systemImage: "calendar", description: Text("在“导入”页粘贴完整的七天 JSON。"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                }
            }
            .padding(20)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("周计划")
        .sheet(item: $editor) { route in
            TaskEditorView(item: route.item, day: route.day) { newItem in
                try model.updateItem(week: route.week, day: route.day, index: route.index, item: newItem)
            }
        }
        .sheet(isPresented: $showingExport) {
            if let plan { ExportView(plan: plan) }
        }
        .alert("操作失败", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("好", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .onAppear { selectTodayIfNeeded() }
        .onChange(of: model.selectedWeekStart) { _, _ in selectTodayIfNeeded(force: true) }
    }

    private func weekHeader(_ plan: WeekPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(plan.weekStart) 开始的一周")
                .font(.title2.bold())
            Text(plan.timezone)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Menu {
                    ForEach(model.plans, id: \.weekStart) { week in
                        Button(week.weekStart) { model.selectedWeekStart = week.weekStart }
                    }
                } label: {
                    Label("选择周", systemImage: "calendar")
                }
                Button { showingExport = true } label: {
                    Label("导出 JSON", systemImage: "square.and.arrow.up")
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func daySelector(_ plan: WeekPlan) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(plan.days.indices, id: \.self) { index in
                    let day = plan.days[index]
                    Button {
                        selectedDay = day.date
                    } label: {
                        VStack(spacing: 4) {
                            Text(["周一", "周二", "周三", "周四", "周五", "周六", "周日"][index])
                                .font(.caption)
                            Text(String(day.date.suffix(2)))
                                .font(.headline.monospacedDigit())
                        }
                        .frame(minWidth: 48)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 4)
                        .background(selectedDay == day.date ? Color.teal : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(selectedDay == day.date ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func dayContent(plan: WeekPlan, day: PlanDay, now: Date) -> some View {
        let calendar = PlanValidator.calendar(for: TimeZone(identifier: plan.timezone)!)
        let dayStart = PlanValidator.parseDate(day.date, calendar: calendar)!
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(day.date)
                    .font(.headline)
                Spacer()
                Button {
                    editor = EditorRoute(week: plan.weekStart, day: day.date, index: nil, item: nil)
                } label: {
                    Label("添加事项", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
            if day.items.isEmpty {
                Text("这一天没有安排")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 15))
            }
            ForEach(day.items.indices, id: \.self) { index in
                let item = day.items[index]
                let start = ClockTime(item.start).flatMap { PlanValidator.makeDate(day: dayStart, time: $0, calendar: calendar) }
                let end = ClockTime(item.end, allowsDayEnd: true).flatMap { PlanValidator.makeDate(day: dayStart, time: $0, calendar: calendar) }
                HStack(spacing: 6) {
                    Button {
                        editor = EditorRoute(week: plan.weekStart, day: day.date, index: index, item: item)
                    } label: {
                        TaskRow(item: item, isCurrent: start.map { $0 <= now && now < (end ?? .distantPast) } ?? false,
                                isPast: end.map { $0 <= now } ?? false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("双击编辑")
                    Button(role: .destructive) {
                        do { try model.deleteItem(week: plan.weekStart, day: day.date, index: index) }
                        catch { actionError = error.localizedDescription }
                    } label: {
                        Image(systemName: "trash")
                            .frame(minWidth: 36, minHeight: 44)
                    }
                    .accessibilityLabel("删除\(item.title)")
                }
            }
            Text("轻点事项可修改；删除后会立即更新桌面小组件。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectTodayIfNeeded(force: Bool = false) {
        guard let plan else { selectedDay = nil; return }
        if !force, let selectedDay, plan.days.contains(where: { $0.date == selectedDay }) { return }
        let calendar = PlanValidator.calendar(for: TimeZone(identifier: plan.timezone)!)
        let today = PlanValidator.dateString(.now, calendar: calendar)
        selectedDay = plan.days.contains(where: { $0.date == today }) ? today : plan.days[0].date
    }
}

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let day: String
    let save: (ScheduleItem) throws -> Void
    @State private var title: String
    @State private var tip: String
    @State private var start: String
    @State private var end: String
    @State private var error: String?

    init(item: ScheduleItem?, day: String, save: @escaping (ScheduleItem) throws -> Void) {
        self.day = day
        self.save = save
        _title = State(initialValue: item?.title ?? "")
        _tip = State(initialValue: item?.tip ?? "")
        _start = State(initialValue: item?.start ?? "09:00")
        _end = State(initialValue: item?.end ?? "10:00")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("\(day) · 事项") {
                    TextField("标题", text: $title, axis: .vertical)
                        .lineLimit(1...4)
                    TextField("一句提示（可留空）", text: $tip, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section("时间 · 所属计划时区") {
                    TextField("开始 HH:mm", text: $start)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("结束 HH:mm", text: $end)
                        .keyboardType(.numbersAndPunctuation)
                    Text("结束可填 24:00，表示次日 00:00；其他跨午夜事项需要拆成两天。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
                Section {
                    Button("保存事项", action: commit)
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
            }
            .navigationTitle("编辑事项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: commit)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func commit() {
        do {
            try save(ScheduleItem(start: start, end: end, title: title, tip: tip))
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    let plan: WeekPlan
    private var json: String { (try? PlanValidator.export(plan)) ?? "导出失败" }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("导出 \(plan.weekStart)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("复制") { UIPasteboard.general.string = json }
                    ShareLink(item: json) { Image(systemName: "square.and.arrow.up") }
                }
            }
        }
    }
}

#Preview("周视图") {
    NavigationStack { WeekView() }
        .environmentObject(NextBeatModel(previewPlans: [PreviewFixtures.week]))
}
