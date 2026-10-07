import Foundation

struct ScheduleItem: Codable, Equatable, Sendable {
    var start: String
    var end: String
    var title: String
    var tip: String
}

struct PlanDay: Codable, Equatable, Sendable {
    var date: String
    var items: [ScheduleItem]
}

struct WeekPlan: Codable, Equatable, Sendable {
    var weekStart: String
    var timezone: String
    var days: [PlanDay]

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case timezone, days
    }
}

struct PlanIssue: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

struct ClockTime: Equatable, Comparable {
    let minutes: Int

    init?(_ text: String, allowsDayEnd: Bool = false) {
        guard text.range(of: #"^[0-9]{2}:[0-9]{2}$"#, options: .regularExpression) != nil else { return nil }
        let parts = text.split(separator: ":")
        guard let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        if allowsDayEnd && hour == 24 && minute == 0 {
            minutes = 1440
        } else {
            guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            minutes = hour * 60 + minute
        }
    }

    static func < (lhs: ClockTime, rhs: ClockTime) -> Bool { lhs.minutes < rhs.minutes }
}

enum PlanValidator {
    static func decode(_ json: String) throws -> WeekPlan {
        guard let data = json.data(using: .utf8) else { throw PlanIssue(message: "JSON 不是有效的 UTF-8 文本。") }
        let plan: WeekPlan
        do {
            plan = try JSONDecoder().decode(WeekPlan.self, from: data)
        } catch {
            throw PlanIssue(message: describeDecodingError(error, json: data))
        }
        try validate(plan)
        return plan
    }

    static func validate(_ plan: WeekPlan) throws {
        guard let timezone = TimeZone(identifier: plan.timezone) else {
            throw PlanIssue(message: "timezone“\(plan.timezone)”不是有效的 IANA 时区。")
        }
        let calendar = calendar(for: timezone)
        guard let monday = parseDate(plan.weekStart, calendar: calendar),
              calendar.component(.weekday, from: monday) == 2 else {
            throw PlanIssue(message: "week_start 必须是格式为 YYYY-MM-DD 的周一日期。")
        }
        guard plan.days.count == 7 else {
            throw PlanIssue(message: "\(plan.weekStart) 这一周必须恰好包含周一至周日连续 7 个 days；当前有 \(plan.days.count) 个。")
        }
        for offset in 0..<7 {
            let expectedDate = calendar.date(byAdding: .day, value: offset, to: monday)!
            let expected = dateString(expectedDate, calendar: calendar)
            let day = plan.days[offset]
            guard day.date == expected else {
                throw PlanIssue(message: "第 \(offset + 1) 天应为 \(expected)，实际为“\(day.date)”。days 必须按日期连续排列。")
            }
            var previousEnd = -1
            var previousStart = -1
            for (index, item) in day.items.enumerated() {
                let label = "\(day.date) 第 \(index + 1) 项“\(item.title.isEmpty ? "未命名" : item.title)”"
                guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw PlanIssue(message: "\(label)：标题不能为空。")
                }
                guard let start = ClockTime(item.start) else {
                    throw PlanIssue(message: "\(label)：start“\(item.start)”无效，应为 00:00–23:59。")
                }
                guard let end = ClockTime(item.end, allowsDayEnd: true) else {
                    throw PlanIssue(message: "\(label)：end“\(item.end)”无效，应为 00:00–24:00，且 24:00 只能表示当天结束。")
                }
                guard end > start else {
                    throw PlanIssue(message: "\(label)：结束时间必须晚于开始时间；跨午夜事项请拆成两天，或用 24:00 作为当日结束。")
                }
                guard start.minutes >= previousStart else {
                    throw PlanIssue(message: "\(label)：事项未按开始时间排序。")
                }
                guard start.minutes >= previousEnd else {
                    throw PlanIssue(message: "\(label)：与上一项重叠。")
                }
                if isAmbiguousLocalTime(day: expectedDate, time: start, calendar: calendar) {
                    throw PlanIssue(message: "\(label)：start“\(item.start)”在当地时区 \(plan.timezone) 因夏令时回拨重复出现两次，无法确定是哪一次。")
                }
                if isAmbiguousLocalTime(day: expectedDate, time: end, calendar: calendar) {
                    throw PlanIssue(message: "\(label)：end“\(item.end)”在当地时区 \(plan.timezone) 因夏令时回拨重复出现两次，无法确定是哪一次。")
                }
                guard makeDate(day: expectedDate, time: start, calendar: calendar) != nil,
                      makeDate(day: expectedDate, time: end, calendar: calendar) != nil else {
                    throw PlanIssue(message: "\(label)：当地时区 \(plan.timezone) 在该日期不存在此时间（夏令时跳时）。")
                }
                previousStart = start.minutes
                previousEnd = end.minutes
            }
        }
    }

    static func sortedForEditing(_ plan: WeekPlan) -> WeekPlan {
        var copy = plan
        for index in copy.days.indices {
            copy.days[index].items.sort {
                (ClockTime($0.start)?.minutes ?? Int.max) < (ClockTime($1.start)?.minutes ?? Int.max)
            }
        }
        return copy
    }

    static func export(_ plan: WeekPlan) throws -> String {
        try validate(plan)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(plan)
        return String(decoding: data, as: UTF8.self)
    }

    static func calendar(for timezone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        calendar.firstWeekday = 2
        return calendar
    }

    static func parseDate(_ text: String, calendar: Calendar) -> Date? {
        guard text.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil else { return nil }
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(timeZone: calendar.timeZone, year: parts[0], month: parts[1], day: parts[2], hour: 12)
        guard let midday = calendar.date(from: components), dateString(midday, calendar: calendar) == text else { return nil }
        return calendar.startOfDay(for: midday)
    }

    static func dateString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    static func makeDate(day: Date, time: ClockTime, calendar: Calendar) -> Date? {
        if time.minutes == 1440 { return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) }
        let dateParts = calendar.dateComponents([.year, .month, .day], from: day)
        let hour = time.minutes / 60
        let minute = time.minutes % 60
        let components = DateComponents(timeZone: calendar.timeZone, year: dateParts.year, month: dateParts.month, day: dateParts.day, hour: hour, minute: minute)
        guard let result = calendar.date(from: components) else { return nil }
        let roundTrip = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result)
        guard roundTrip.year == dateParts.year, roundTrip.month == dateParts.month,
              roundTrip.day == dateParts.day, roundTrip.hour == hour, roundTrip.minute == minute else { return nil }
        return result
    }

    private static func isAmbiguousLocalTime(day: Date, time: ClockTime, calendar: Calendar) -> Bool {
        guard time.minutes < 1440 else { return false }
        let components = DateComponents(hour: time.minutes / 60, minute: time.minutes % 60)
        let searchStart = calendar.startOfDay(for: day).addingTimeInterval(-1)
        guard let first = calendar.nextDate(after: searchStart, matching: components,
                                            matchingPolicy: .strict, repeatedTimePolicy: .first),
              let last = calendar.nextDate(after: searchStart, matching: components,
                                           matchingPolicy: .strict, repeatedTimePolicy: .last) else {
            return false
        }
        let expected = dateString(day, calendar: calendar)
        return first != last && dateString(first, calendar: calendar) == expected
            && dateString(last, calendar: calendar) == expected
    }

    private static func describeDecodingError(_ error: Error, json: Data) -> String {
        var path: [CodingKey] = []
        var detail = "JSON 结构有误"
        switch error {
        case let DecodingError.keyNotFound(key, context):
            path = context.codingPath + [key]
            detail = "缺少字段"
        case let DecodingError.typeMismatch(_, context), let DecodingError.valueNotFound(_, context), let DecodingError.dataCorrupted(context):
            path = context.codingPath
            detail = context.debugDescription
        default:
            return "JSON 语法错误：\(error.localizedDescription)"
        }
        let location = path.map { key in key.intValue.map { "[\($0)]" } ?? ".\(key.stringValue)" }.joined()
        var hint = ""
        if let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
           let days = root["days"] as? [[String: Any]],
           let dayIndex = path.first(where: { $0.intValue != nil })?.intValue,
           days.indices.contains(dayIndex) {
            let day = days[dayIndex]
            hint = "（\(day["date"] as? String ?? "第 \(dayIndex + 1) 天")"
            if let items = day["items"] as? [[String: Any]],
               let itemIndex = path.dropFirst(2).first(where: { $0.intValue != nil })?.intValue,
               items.indices.contains(itemIndex) {
                hint += " 第 \(itemIndex + 1) 项“\(items[itemIndex]["title"] as? String ?? "未命名")”"
            }
            hint += "）"
        }
        return "JSON \(location.isEmpty ? "根节点" : location)\(hint)：\(detail)。"
    }
}
