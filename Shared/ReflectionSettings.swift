import Foundation

struct ReflectionSettings: Codable, Equatable {
    var isEnabled: Bool
    var text: String
    var footerEnabled: Bool
    var footerText: String

    static let defaultFooterText = "今天最值得坚持的一件事是什么？"

    init(isEnabled: Bool, text: String,
         footerEnabled: Bool = true, footerText: String = defaultFooterText) {
        self.isEnabled = isEnabled
        self.text = text
        self.footerEnabled = footerEnabled
        self.footerText = footerText
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, text, footerEnabled, footerText
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try values.decode(Bool.self, forKey: .isEnabled)
        text = try values.decode(String.self, forKey: .text)
        // Older reflection-v1.json files contain only the top reflection.
        footerEnabled = values.contains(.footerEnabled)
            ? try values.decode(Bool.self, forKey: .footerEnabled) : true
        footerText = values.contains(.footerText)
            ? try values.decode(String.self, forKey: .footerText) : Self.defaultFooterText
    }

    static let defaultValue = ReflectionSettings(
        isEnabled: true,
        text: "此刻做的事，是否值得我投入时间？"
    )

    func validated() throws -> ReflectionSettings {
        let top = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let bottom = footerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !top.isEmpty else {
            throw PlanIssue(message: "顶部自省语不能为空。若暂时不想显示，请关闭顶部开关。")
        }
        guard top.count <= 100 else {
            throw PlanIssue(message: "顶部自省语最多 100 字，当前为 \(top.count) 字。")
        }
        guard !bottom.isEmpty else {
            throw PlanIssue(message: "底部自省语不能为空。若暂时不想显示，请关闭底部开关。")
        }
        guard bottom.count <= 100 else {
            throw PlanIssue(message: "底部自省语最多 100 字，当前为 \(bottom.count) 字。")
        }
        return ReflectionSettings(isEnabled: isEnabled, text: top,
                                  footerEnabled: footerEnabled, footerText: bottom)
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
