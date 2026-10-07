import XCTest

final class NextBeatUITests: XCTestCase {
    func testImportEditAndPersistence() throws {
        let app = XCUIApplication()
        let json = makeCurrentWeekJSON()
        app.launchEnvironment["NEXTBEAT_UI_TEST_JSON"] = json
        app.launch()
        app.tabBars.buttons["导入"].tap()
        let editor = app.textViews["周计划 JSON"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertTrue((editor.value as? String ?? "").contains("Current task"))
        app.buttons["验证并预览"].tap()
        XCTAssertTrue(app.staticTexts["预览 · \(weekStart())"].waitForExistence(timeout: 10))
        let saveWeek = app.buttons["确认保存这一周"]
        for _ in 0..<5 where !saveWeek.isHittable { app.swipeUp() }
        saveWeek.tap()

        app.tabBars.buttons["今日"].tap()
        XCTAssertTrue(app.staticTexts["正在进行"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Current task"].exists)
        XCTAssertTrue(app.staticTexts["Next task"].exists)

        app.tabBars.buttons["周计划"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Current task")).firstMatch.tap()
        let title = app.textFields.element(boundBy: 0)
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Edited ")
        app.buttons["保存事项"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Edited ")).firstMatch.waitForExistence(timeout: 10))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Edited ")).firstMatch.waitForExistence(timeout: 10))
    }

    private func makeCurrentWeekJSON() -> String {
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
        let days: [[String: Any]] = (0..<7).map { offset in
            let date = formatter.string(from: calendar.date(byAdding: .day, value: offset, to: monday)!)
            let items: [[String: String]] = date == todayString ? [
                ["start": "00:00", "end": "01:00", "title": "Current task", "tip": "Focus"],
                ["start": "01:05", "end": "01:45", "title": "Next task", "tip": "Prepare"]
            ] : []
            return ["date": date, "items": items]
        }
        let payload: [String: Any] = ["week_start": formatter.string(from: monday), "timezone": "America/New_York", "days": days]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        return String(decoding: data, as: UTF8.self)
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
