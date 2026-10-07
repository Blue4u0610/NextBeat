import Foundation

struct PlanArchive: Codable {
    var version = 1
    var plans: [WeekPlan] = []
}

struct PlanRepository {
    let fileURL: URL

    static func appGroup(bundle: Bundle = .main, fileManager: FileManager = .default) throws -> PlanRepository {
        guard let groupID = bundle.object(forInfoDictionaryKey: "NextBeatAppGroup") as? String,
              groupID.hasPrefix("group."), !groupID.contains("$(") else {
            throw PlanIssue(message: "App Group ID 未配置。请检查 App 与 Widget 的 NextBeatAppGroup 和 entitlements。")
        }
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            throw PlanIssue(message: "无法访问 App Group“\(groupID)”。请检查两个 target 的 Team、App Groups 能力、签名和 Group ID。")
        }
        return PlanRepository(fileURL: container.appendingPathComponent("plans-v1.json"))
    }

    func load() throws -> [WeekPlan] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let archive: PlanArchive
        do { archive = try JSONDecoder().decode(PlanArchive.self, from: data) }
        catch { throw PlanIssue(message: "共享计划文件无法读取：\(error.localizedDescription)。请先备份文件，不要覆盖。") }
        guard archive.version == 1 else { throw PlanIssue(message: "共享计划文件版本 \(archive.version) 暂不支持。") }
        var weeks = Set<String>()
        for plan in archive.plans {
            try PlanValidator.validate(plan)
            guard weeks.insert(plan.weekStart).inserted else { throw PlanIssue(message: "共享计划文件含重复周 \(plan.weekStart)。") }
        }
        return archive.plans.sorted { $0.weekStart < $1.weekStart }
    }

    func replace(_ proposed: WeekPlan) throws -> [WeekPlan] {
        // Validation and reading finish before the original file is replaced.
        try PlanValidator.validate(proposed)
        var plans = try load()
        plans.removeAll { $0.weekStart == proposed.weekStart }
        plans.append(proposed)
        plans.sort { $0.weekStart < $1.weekStart }
        let data = try JSONEncoder().encode(PlanArchive(plans: plans))
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        // A readable shared file is required before the UI reports success.
        let verified = try load()
        guard verified == plans else { throw PlanIssue(message: "共享计划保存后校验失败。") }
        return verified
    }
}
