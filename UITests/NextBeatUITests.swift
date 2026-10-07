import XCTest

final class NextBeatUITests: XCTestCase {
    func testFooterReflectionCanBeDisabledAndRestored() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["设置"].tap()
        let toggle = app.switches["显示底部自省语"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        if (toggle.value as? String) != "0" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            app.buttons["保存并更新小组件"].tap()
        }
        app.terminate()
        app.launch()
        app.tabBars.buttons["设置"].tap()
        XCTAssertEqual(app.switches["显示底部自省语"].value as? String, "0")

        app.switches["显示底部自省语"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["保存并更新小组件"].tap()
        XCTAssertEqual(app.switches["显示底部自省语"].value as? String, "1")
    }

    func testReflectionCanBeDisabledAndPersists() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["设置"].tap()
        let toggle = app.switches["显示顶部自省语"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        if (toggle.value as? String) != "0" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "0", "关闭开关后，保存前应先呈现关闭状态。")
            app.buttons["保存并更新小组件"].tap()
        }
        XCTAssertEqual(toggle.value as? String, "0")

        app.terminate()
        app.launch()
        app.tabBars.buttons["设置"].tap()
        XCTAssertEqual(app.switches["显示顶部自省语"].value as? String, "0")
    }

    func testReflectionCanBeEnabledAndPersists() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["设置"].tap()
        let toggle = app.switches["显示顶部自省语"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        if (toggle.value as? String) != "1" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "1", "打开开关后，保存前应先呈现开启状态。")
            app.buttons["保存并更新小组件"].tap()
        }
        XCTAssertEqual(toggle.value as? String, "1")

        app.terminate()
        app.launch()
        app.tabBars.buttons["设置"].tap()
        XCTAssertEqual(app.switches["显示顶部自省语"].value as? String, "1")
    }

    func testImportEditAndPersistence() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let clock = calendar.dateComponents([.hour, .minute], from: .now)
        if clock.hour == 23 && (clock.minute ?? 0) >= 45 {
            throw XCTSkip("跨周或跨日边界前 15 分钟不运行依赖当前事项的界面流程。")
        }
        let app = XCUIApplication()
        let (json, hasNextTask) = makeCurrentWeekJSON()
        app.launchEnvironment["NEXTBEAT_UI_TEST_JSON"] = json
        app.launch()
        app.tabBars.buttons["导入"].tap()
        let editor = app.textViews["周计划 JSON"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertTrue((editor.value as? String ?? "").contains("此刻专注"))
        app.buttons["验证并预览"].tap()
        XCTAssertTrue(app.staticTexts["预览 · \(weekStart())"].waitForExistence(timeout: 10))
        let saveWeek = app.buttons["确认保存这一周"]
        for _ in 0..<20 where !saveWeek.isHittable { app.swipeUp() }
        saveWeek.tap()

        app.tabBars.buttons["今日"].tap()
        XCTAssertTrue(app.staticTexts["正在进行"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["此刻专注"].exists)
        if hasNextTask { XCTAssertTrue(app.staticTexts["整理思路"].exists) }

        app.tabBars.buttons["周计划"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "此刻专注")).firstMatch.tap()
        let title = app.textFields.element(boundBy: 0)
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("已调整 · ")
        app.buttons["保存事项"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "已调整 · ")).firstMatch.waitForExistence(timeout: 10))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "已调整 · ")).firstMatch.waitForExistence(timeout: 10))
    }

    private func makeCurrentWeekJSON() -> (String, Bool) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)
        let currentTime = calendar.dateComponents([.hour, .minute], from: .now)
        let nowMinutes = (currentTime.hour ?? 0) * 60 + (currentTime.minute ?? 0)
        let currentStart = max(0, nowMinutes - 5)
        let currentEnd = min(1440, nowMinutes + 15)
        let nextStart = currentEnd + 5
        let hasNextTask = nextStart < 1440
        let nextEnd = min(1440, nextStart + 30)
        func clock(_ minutes: Int) -> String {
            String(format: "%02d:%02d", minutes / 60, minutes % 60)
        }
        func minuteValue(_ time: String) -> Int {
            let parts = time.split(separator: ":")
            return Int(parts[0])! * 60 + Int(parts[1])!
        }
        let slots = [
            ("06:30", "07:00"), ("07:15", "08:00"), ("08:15", "09:00"),
            ("09:30", "10:15"), ("10:30", "11:15"), ("11:30", "12:00"),
            ("13:00", "14:00"), ("14:30", "15:30"), ("17:00", "18:00"),
            ("19:30", "20:30")
        ]
        let titles = ["晨间准备", "早餐与整理", "阅读", "专注工作", "沟通", "午间复盘",
                      "项目推进", "散步休息", "梳理这一周的研究思路和待验证假设", "晚间回顾"]
        let days: [[String: Any]] = (0..<7).map { offset in
            let date = formatter.string(from: calendar.date(byAdding: .day, value: offset, to: monday)!)
            let standard: [[String: String]] = slots.enumerated().map { index, slot in
                ["start": slot.0, "end": slot.1, "title": titles[index],
                 "tip": index == 3 ? "先做最重要的一件事" : "保持节奏"]
            }
            let items: [[String: String]]
            if date == todayString {
                var special = [["start": clock(currentStart), "end": clock(currentEnd),
                                "title": "此刻专注", "tip": "先把这一件事做好"]]
                if hasNextTask {
                    special.append(["start": clock(nextStart), "end": clock(nextEnd),
                                    "title": "整理思路", "tip": "记录下一步"])
                }
                let occupiedEnd = hasNextTask ? nextEnd : currentEnd
                let chosenSlots: Set<Int> = [0, 1, 2, 3, 5, 6, 8, 9]
                let nearbyStandard = standard.enumerated().compactMap { index, item -> [String: String]? in
                    guard chosenSlots.contains(index),
                          (minuteValue(item["end"]!) <= currentStart || minuteValue(item["start"]!) >= occupiedEnd)
                    else { return nil }
                    return item
                }
                items = (special + nearbyStandard)
                    .sorted { $0["start"]! < $1["start"]! }
            } else {
                items = standard
            }
            return ["date": date, "items": items]
        }
        let payload: [String: Any] = ["week_start": formatter.string(from: monday), "timezone": "America/New_York", "days": days]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        return (String(decoding: data, as: UTF8.self), hasNextTask)
    }

    private func weekStart() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let weekday = calendar.component(.weekday, from: .now)
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: .now)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }
}
