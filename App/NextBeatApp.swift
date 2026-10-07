import SwiftUI
import WidgetKit

@main
struct NextBeatApp: App {
    @StateObject private var model = NextBeatModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}

@MainActor
final class NextBeatModel: ObservableObject {
    @Published private(set) var plans: [WeekPlan] = []
    @Published private(set) var reflectionSettings = ReflectionSettings.defaultValue
    @Published var selectedWeekStart: String?
    @Published var storageIssue: String?
    @Published var reflectionIssue: String?

    private let repository: PlanRepository?
    private var reflectionRepository: ReflectionRepository?

    init(previewPlans: [WeekPlan]? = nil) {
        if let previewPlans {
            repository = nil
            plans = previewPlans
            selectedWeekStart = previewPlans.last?.weekStart
            return
        }
        do {
            try Self.verifyWidgetConfiguration()
            let store = try PlanRepository.appGroup()
            let loaded = try store.load()
            repository = store
            plans = loaded
            selectedWeekStart = PlanEngine.activePlan(in: plans, at: .now)?.weekStart ?? plans.last?.weekStart
            do {
                let settingsStore = try ReflectionRepository.appGroup()
                reflectionRepository = settingsStore
                reflectionSettings = try settingsStore.load()
            } catch {
                reflectionIssue = error.localizedDescription
            }
        } catch {
            repository = nil
            storageIssue = error.localizedDescription
        }
    }

    private static func verifyWidgetConfiguration() throws {
        guard let appGroup = Bundle.main.object(forInfoDictionaryKey: "NextBeatAppGroup") as? String,
              let plugIns = Bundle.main.builtInPlugInsURL,
              let widgetBundle = Bundle(url: plugIns.appendingPathComponent("NextBeatWidget.appex")),
              let widgetGroup = widgetBundle.object(forInfoDictionaryKey: "NextBeatAppGroup") as? String,
              appGroup == widgetGroup else {
            throw PlanIssue(message: "App 与 Widget 的 App Group 配置不一致，或 Widget 未嵌入 App。请检查两个 target 的 NextBeatAppGroup、entitlements 和嵌入设置。")
        }
    }

    var selectedPlan: WeekPlan? {
        plans.first { $0.weekStart == selectedWeekStart } ?? plans.last
    }

    func save(_ plan: WeekPlan) throws {
        guard let repository else {
            throw PlanIssue(message: storageIssue ?? "共享存储不可用。请检查 App Group 配置。")
        }
        let updated = try repository.replace(plan)
        plans = updated
        selectedWeekStart = plan.weekStart
        storageIssue = nil
        WidgetCenter.shared.reloadTimelines(ofKind: "NextBeatWidget")
    }

    func saveReflectionSettings(_ proposed: ReflectionSettings) throws {
        guard let reflectionRepository else {
            throw PlanIssue(message: reflectionIssue ?? storageIssue ?? "共享存储不可用。请检查 App Group 配置。")
        }
        reflectionSettings = try reflectionRepository.save(proposed)
        reflectionIssue = nil
        WidgetCenter.shared.reloadTimelines(ofKind: "NextBeatWidget")
    }

    func updateItem(week: String, day: String, index: Int?, item: ScheduleItem) throws {
        guard var plan = plans.first(where: { $0.weekStart == week }),
              let dayIndex = plan.days.firstIndex(where: { $0.date == day }) else {
            throw PlanIssue(message: "找不到 \(day) 的计划。")
        }
        if let index {
            guard plan.days[dayIndex].items.indices.contains(index) else { throw PlanIssue(message: "找不到这项任务。") }
            plan.days[dayIndex].items[index] = item
        } else {
            plan.days[dayIndex].items.append(item)
        }
        try save(PlanValidator.sortedForEditing(plan))
    }

    func deleteItem(week: String, day: String, index: Int) throws {
        guard var plan = plans.first(where: { $0.weekStart == week }),
              let dayIndex = plan.days.firstIndex(where: { $0.date == day }),
              plan.days[dayIndex].items.indices.contains(index) else {
            throw PlanIssue(message: "找不到这项任务。")
        }
        plan.days[dayIndex].items.remove(at: index)
        try save(plan)
    }
}
