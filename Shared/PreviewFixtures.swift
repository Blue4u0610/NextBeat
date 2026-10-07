import Foundation

enum PreviewFixtures {
    static let week: WeekPlan = {
        let dates = (5...11).map { String(format: "2026-10-%02d", $0) }
        return WeekPlan(weekStart: dates[0], timezone: "America/New_York", days: dates.enumerated().map { index, date in
            let items: [ScheduleItem]
            switch index {
            case 0:
                items = [
                    ScheduleItem(start: "09:00", end: "10:30", title: "金融学习", tip: "结合今天开盘看"),
                    ScheduleItem(start: "11:00", end: "12:00", title: "梳理本周投资研究笔记与待验证的假设", tip: "先整理关键数字，再写三句结论"),
                    ScheduleItem(start: "14:00", end: "15:00", title: "散步", tip: "让眼睛休息一下")
                ]
            case 1:
                items = [ScheduleItem(start: "08:30", end: "09:15", title: "晨间阅读", tip: "记录一个值得追问的问题")]
            default:
                items = []
            }
            return PlanDay(date: date, items: items)
        })
    }()

    static func time(_ hour: Int, _ minute: Int, day: Int = 5) -> Date {
        let calendar = PlanValidator.calendar(for: TimeZone(identifier: "America/New_York")!)
        return calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
}
