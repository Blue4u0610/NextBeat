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

    static let denseWeek: WeekPlan = {
        let dates = (5...11).map { String(format: "2026-10-%02d", $0) }
        let slots: [(String, String)] = [
            ("06:30", "07:00"), ("07:15", "08:00"), ("08:15", "09:00"),
            ("09:30", "10:15"), ("10:30", "11:15"), ("11:30", "12:00"),
            ("13:00", "14:00"), ("14:30", "15:30"), ("17:00", "18:00"),
            ("19:30", "20:30")
        ]
        let titles = ["晨间准备", "早餐与整理", "阅读", "专注工作", "沟通", "午间复盘",
                      "项目推进", "散步休息", "梳理这一周的研究思路和待验证的假设", "晚间回顾"]
        return WeekPlan(weekStart: dates[0], timezone: "America/New_York",
                        days: dates.enumerated().map { dayIndex, date in
                            let items = slots.enumerated().map { index, slot in
                                ScheduleItem(start: slot.0, end: slot.1,
                                             title: dayIndex == 6 && index == 3 ? "留给自己的时间" : titles[index],
                                             tip: index == 3 ? "先做最重要的一件事" : "保持节奏")
                            }
                            return PlanDay(date: date, items: items)
                        })
    }()

    static func time(_ hour: Int, _ minute: Int, day: Int = 5) -> Date {
        let calendar = PlanValidator.calendar(for: TimeZone(identifier: "America/New_York")!)
        return calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
}
