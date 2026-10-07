import Foundation
import XCTest
@testable import NextBeatCore

final class PlanCoreTests: XCTestCase {
    private func fixture(items: [ScheduleItem] = []) -> WeekPlan {
        let dates = (5...11).map { String(format: "2026-10-%02d", $0) }
        return WeekPlan(weekStart: dates[0], timezone: "America/New_York", days: dates.enumerated().map {
            PlanDay(date: $0.element, items: $0.offset == 0 ? items : [])
        })
    }

    private func item(_ start: String, _ end: String, _ title: String = "任务") -> ScheduleItem {
        ScheduleItem(start: start, end: end, title: title, tip: "提示")
    }

    private func instant(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    func testAcceptsEndOfDayAndRejectsInvalidTimes() throws {
        XCTAssertNoThrow(try PlanValidator.validate(fixture(items: [item("23:30", "24:00")])))
        for bad in [item("24:00", "24:00"), item("23:00", "00:30"), item("09:00", "24:01"), item("9:00", "10:00")] {
            XCTAssertThrowsError(try PlanValidator.validate(fixture(items: [bad])))
        }
    }

    func testRejectsAmbiguousFallBackTimeWithDateAndItem() throws {
        let dates = ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29",
                     "2026-10-30", "2026-10-31", "2026-11-01"]
        var plan = WeekPlan(weekStart: dates[0], timezone: "America/New_York",
                            days: dates.map { PlanDay(date: $0, items: []) })
        plan.days[6].items = [item("01:15", "01:45", "回拨时段")]
        XCTAssertThrowsError(try PlanValidator.validate(plan)) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("2026-11-01"))
            XCTAssertTrue(message.contains("第 1 项"))
            XCTAssertTrue(message.contains("重复出现两次"))
        }
        plan.days[6].items = [item("02:15", "03:00", "回拨后")]
        XCTAssertNoThrow(try PlanValidator.validate(plan))
    }

    func testBoundariesAndGapUseJSONTimezone() throws {
        let plan = fixture(items: [item("09:00", "10:00", "学习"), item("11:00", "12:00", "散步")])
        try PlanValidator.validate(plan)
        XCTAssertEqual(PlanEngine.snapshot(in: [plan], at: instant("2026-10-05T12:59:00Z")).phase, .gap)
        XCTAssertEqual(PlanEngine.snapshot(in: [plan], at: instant("2026-10-05T13:00:00Z")).current?.item.title, "学习")
        XCTAssertEqual(PlanEngine.snapshot(in: [plan], at: instant("2026-10-05T14:00:00Z")).phase, .gap)
        XCTAssertEqual(PlanEngine.snapshot(in: [plan], at: instant("2026-10-05T15:00:00Z")).current?.item.title, "散步")
        XCTAssertEqual(PlanEngine.snapshot(in: [plan], at: instant("2026-10-05T16:00:00Z")).phase, .done)
        XCTAssertEqual(PlanEngine.snapshot(in: [plan], at: instant("2026-10-06T16:00:00Z")).phase, .emptyDay)
        XCTAssertEqual(PlanEngine.snapshot(in: [plan], at: instant("2026-10-12T04:00:00Z")).phase, .noPlan)
    }

    func testValidatesSevenDaysOrderingOverlapAndTitles() throws {
        var plan = fixture(items: [item("09:00", "10:00"), item("09:59", "11:00")])
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan.days[0].items[1].start = "10:00"
        try PlanValidator.validate(plan)
        plan.days[0].items[1].title = "  "
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = fixture()
        plan.days.removeLast()
        XCTAssertThrowsError(try PlanValidator.validate(plan))
        plan = fixture()
        plan.days[3].date = "2026-10-09"
        XCTAssertThrowsError(try PlanValidator.validate(plan))
    }

    func testFailedReplacementPreservesOriginal() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("plans.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = PlanRepository(fileURL: url)
        let old = fixture(items: [item("09:00", "10:00", "原计划")])
        _ = try repository.replace(old)
        var invalid = old
        invalid.days[0].items[0].end = "08:00"
        XCTAssertThrowsError(try repository.replace(invalid))
        XCTAssertEqual(try repository.load(), [old])
        var replacement = old
        replacement.days[0].items[0].title = "新计划"
        _ = try repository.replace(replacement)
        XCTAssertEqual(try repository.load(), [replacement])
    }

    func testExportRoundTripAndTimelineTransitions() throws {
        let plan = fixture(items: [item("09:00", "10:00"), item("23:00", "24:00")])
        XCTAssertEqual(try PlanValidator.decode(PlanValidator.export(plan)), plan)
        let dates = PlanEngine.timelineDates(in: [plan], from: instant("2026-10-05T12:00:00Z"), through: instant("2026-10-06T05:00:00Z"))
        XCTAssertTrue(dates.contains(instant("2026-10-05T13:00:00Z")))
        XCTAssertTrue(dates.contains(instant("2026-10-05T14:00:00Z")))
        XCTAssertTrue(dates.contains(instant("2026-10-06T04:00:00Z")))
    }
}
