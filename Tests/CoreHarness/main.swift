import Foundation

var checks = 0
func check(_ condition: @autoclosure () throws -> Bool, _ description: String) throws {
    checks += 1
    guard try condition() else { fatalError("FAILED: \(description)") }
}
func expectFailure(_ description: String, _ action: () throws -> Void) {
    checks += 1
    do { try action(); fatalError("FAILED: \(description)") }
    catch is PlanIssue { }
    catch { fatalError("WRONG ERROR: \(description): \(error)") }
}
func task(_ start: String, _ end: String, _ title: String = "任务") -> ScheduleItem {
    ScheduleItem(start: start, end: end, title: title, tip: "提示")
}
func week(_ first: Int, items: [ScheduleItem] = []) -> WeekPlan {
    let dates = (first..<(first+7)).map { String(format: "2026-10-%02d", $0) }
    return WeekPlan(weekStart: dates[0], timezone: "America/New_York", days: dates.enumerated().map {
        PlanDay(date: $0.element, items: $0.offset == 0 ? items : [])
    })
}
func instant(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

let original = week(5, items: [task("09:00", "10:00", "学习"), task("11:00", "12:00", "散步"), task("23:00", "24:00", "收尾")])
try PlanValidator.validate(original)
try check(PlanValidator.decode(PlanValidator.export(original)) == original, "JSON round trip")
try check(PlanEngine.snapshot(in: [original], at: instant("2026-10-05T13:00:00Z")).current?.item.title == "学习", "task starts at exact boundary in JSON timezone")
try check(PlanEngine.snapshot(in: [original], at: instant("2026-10-05T14:00:00Z")).phase == .gap, "end boundary starts gap")
try check(PlanEngine.snapshot(in: [original], at: instant("2026-10-05T15:00:00Z")).current?.item.title == "散步", "next task starts")
try check(PlanEngine.snapshot(in: [original], at: instant("2026-10-06T04:00:00Z")).phase == .emptyDay, "24:00 is next-day midnight")
try check(PlanEngine.snapshot(in: [original], at: instant("2026-10-12T04:00:00Z")).phase == .noPlan, "week expires")
for invalid in [task("24:00", "24:00"), task("23:00", "00:30"), task("09:00", "24:01"), task("9:00", "10:00")] {
    expectFailure("invalid time \(invalid.start)-\(invalid.end)") { try PlanValidator.validate(week(5, items: [invalid])) }
}
expectFailure("overlap") { try PlanValidator.validate(week(5, items: [task("09:00", "10:00"), task("09:59", "11:00")])) }
expectFailure("unsorted") { try PlanValidator.validate(week(5, items: [task("11:00", "12:00"), task("09:00", "10:00")])) }
expectFailure("blank title") { try PlanValidator.validate(week(5, items: [task("09:00", "10:00", "  ")])) }
let invalidTitle = week(5, items: [task("09:00", "10:00", "  ")])
do {
    try PlanValidator.validate(invalidTitle)
    fatalError("FAILED: specific validation error")
} catch let issue as PlanIssue {
    try check(issue.message.contains("2026-10-05") && issue.message.contains("第 1 项"), "error names date and task")
}
expectFailure("JSON structure") { _ = try PlanValidator.decode("{\"week_start\":\"2026-10-05\",\"timezone\":\"America/New_York\"}") }
var sixDays = week(5)
sixDays.days.removeLast()
expectFailure("six days") { try PlanValidator.validate(sixDays) }
var wrongDate = week(5)
wrongDate.days[3].date = "2026-10-09"
expectFailure("non-contiguous days") { try PlanValidator.validate(wrongDate) }
var spring = WeekPlan(weekStart: "2027-03-08", timezone: "America/New_York", days: (8...14).map { PlanDay(date: String(format: "2027-03-%02d", $0), items: $0 == 14 ? [task("02:30", "03:30")] : []) })
expectFailure("nonexistent DST time") { try PlanValidator.validate(spring) }
let dates = PlanEngine.timelineDates(in: [original], from: instant("2026-10-05T12:00:00Z"), through: instant("2026-10-06T05:00:00Z"))
try check(dates.contains(instant("2026-10-05T13:00:00Z")), "timeline start")
try check(dates.contains(instant("2026-10-05T14:00:00Z")), "timeline end")
try check(dates.contains(instant("2026-10-06T04:00:00Z")), "timeline 24:00")
let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("plans.json")
defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
let repo = PlanRepository(fileURL: file)
expectFailure("missing App Group configuration is explicit") { _ = try PlanRepository.appGroup() }
_ = try repo.replace(original)
var bad = original
bad.days[0].items[0].end = "08:00"
expectFailure("failed replacement") { _ = try repo.replace(bad) }
try check(repo.load() == [original], "failed replacement preserves original")
var second = week(12, items: [task("09:00", "10:00", "第二周")])
_ = try repo.replace(second)
try check(repo.load() == [original, second], "different weeks coexist")
second.days[0].items[0].title = "修改后"
_ = try repo.replace(second)
try check(repo.load() == [original, second], "replacement preserves other weeks")
print("NextBeat core checks passed: \(checks)")
