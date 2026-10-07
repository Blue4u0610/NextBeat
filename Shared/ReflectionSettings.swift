import Foundation

struct ReflectionSettings: Codable, Equatable {
    var isEnabled: Bool
    var text: String

    static let defaultValue = ReflectionSettings(
        isEnabled: true,
        text: "此刻做的事，是否值得我投入时间？"
    )

    func validated() throws -> ReflectionSettings {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlanIssue(message: "自省语不能为空。若暂时不想显示，请关闭上方开关。")
        }
        guard trimmed.count <= 100 else {
            throw PlanIssue(message: "自省语最多 100 字，当前为 \(trimmed.count) 字。")
        }
        return ReflectionSettings(isEnabled: isEnabled, text: trimmed)
    }
}

private struct ReflectionArchive: Codable {
    var version = 1
    var settings: ReflectionSettings
}

struct ReflectionRepository {
    let fileURL: URL

    static func appGroup() throws -> ReflectionRepository {
        // Use the same checked App Group container as the plans. There is no private fallback.
        let plans = try PlanRepository.appGroup()
        return ReflectionRepository(fileURL: plans.fileURL.deletingLastPathComponent()
            .appendingPathComponent("reflection-v1.json"))
    }

    func load() throws -> ReflectionSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaultValue
        }
        let archive: ReflectionArchive
        do {
            archive = try JSONDecoder().decode(ReflectionArchive.self, from: Data(contentsOf: fileURL))
        } catch {
            throw PlanIssue(message: "共享自省语设置无法读取：\(error.localizedDescription)。请先备份文件，不要覆盖。")
        }
        guard archive.version == 1 else {
            throw PlanIssue(message: "共享自省语设置版本 \(archive.version) 暂不支持。")
        }
        return try archive.settings.validated()
    }

    @discardableResult
    func save(_ proposed: ReflectionSettings) throws -> ReflectionSettings {
        let settings = try proposed.validated()
        // Refuse to overwrite unreadable or unsupported settings.
        _ = try load()
        let data = try JSONEncoder().encode(ReflectionArchive(settings: settings))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        let verified = try load()
        guard verified == settings else {
            throw PlanIssue(message: "共享自省语设置保存后校验失败。")
        }
        return verified
    }
}
