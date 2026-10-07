import Foundation

struct TaskOccurrence: Equatable {
    let item: ScheduleItem
    let day: String
    let start: Date
    let end: Date
}

enum DayPhase: Equatable {
    case noPlan
    case current
    case gap
    case done
    case emptyDay
}

struct DaySnapshot: Equatable {
    let phase: DayPhase
    let today: String?
    let timezone: String?
    let current: TaskOccurrence?
    let next: TaskOccurrence?

    static let noPlan = DaySnapshot(phase: .noPlan, today: nil, timezone: nil, current: nil, next: nil)
}

enum PlanEngine {
    static func activePlan(in plans: [WeekPlan], at now: Date) -> WeekPlan? {
        plans.filter { plan in
            guard let zone = TimeZone(identifier: plan.timezone) else { return false }
            let calendar = PlanValidator.calendar(for: zone)
            guard let start = PlanValidator.parseDate(plan.weekStart, calendar: calendar),
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else { return false }
            return start <= now && now < end
        }.max { $0.weekStart < $1.weekStart }
    }

    static func snapshot(in plans: [WeekPlan], at now: Date) -> DaySnapshot {
        guard let plan = activePlan(in: plans, at: now) else { return .noPlan }
        return snapshot(for: plan, at: now)
    }

    static func snapshot(for plan: WeekPlan, at now: Date) -> DaySnapshot {
        guard let zone = TimeZone(identifier: plan.timezone) else { return .noPlan }
        let calendar = PlanValidator.calendar(for: zone)
        let today = PlanValidator.dateString(now, calendar: calendar)
        guard let day = plan.days.first(where: { $0.date == today }),
              let dayDate = PlanValidator.parseDate(today, calendar: calendar) else { return .noPlan }
        let occurrences = day.items.compactMap { item -> TaskOccurrence? in
            guard let startTime = ClockTime(item.start),
                  let endTime = ClockTime(item.end, allowsDayEnd: true),
                  let start = PlanValidator.makeDate(day: dayDate, time: startTime, calendar: calendar),
                  let end = PlanValidator.makeDate(day: dayDate, time: endTime, calendar: calendar) else { return nil }
            return TaskOccurrence(item: item, day: today, start: start, end: end)
        }
        let current = occurrences.first { $0.start <= now && now < $0.end }
        let next = occurrences.first { $0.start > now }
        let phase: DayPhase
        if day.items.isEmpty { phase = .emptyDay }
        else if current != nil { phase = .current }
        else if next != nil { phase = .gap }
        else { phase = .done }
        return DaySnapshot(phase: phase, today: today, timezone: plan.timezone, current: current, next: next)
    }

    static func timelineDates(in plans: [WeekPlan], from now: Date, through horizon: Date) -> [Date] {
        var dates: Set<Date> = [now]
        for plan in plans {
            guard let zone = TimeZone(identifier: plan.timezone) else { continue }
            let calendar = PlanValidator.calendar(for: zone)
            for day in plan.days {
                guard let dayDate = PlanValidator.parseDate(day.date, calendar: calendar) else { continue }
                if now < dayDate && dayDate <= horizon { dates.insert(dayDate) }
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: dayDate), now < nextDay && nextDay <= horizon {
                    dates.insert(nextDay)
                }
                for item in day.items {
                    guard let start = ClockTime(item.start), let end = ClockTime(item.end, allowsDayEnd: true) else { continue }
                    for time in [start, end] {
                        guard let date = PlanValidator.makeDate(day: dayDate, time: time, calendar: calendar) else { continue }
                        if now < date && date <= horizon { dates.insert(date) }
                    }
                }
            }
        }
        return dates.sorted()
    }
}
