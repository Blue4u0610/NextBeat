import Foundation
import XCTest
@testable import NextBeatCore

final class ReflectionSettingsTests: XCTestCase {
    func testDefaultAndRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ReflectionRepository(fileURL: directory.appendingPathComponent("reflection-v1.json"))

        XCTAssertEqual(try repository.load(), .defaultValue)
        let saved = try repository.save(ReflectionSettings(
            isEnabled: false, text: "  慢一点，想清楚再行动。  ",
            footerEnabled: false, footerTitle: "  片刻自问  ",
            footerText: "  今天留下了什么？  "
        ))
        XCTAssertEqual(saved, ReflectionSettings(
            isEnabled: false, text: "慢一点，想清楚再行动。",
            footerEnabled: false, footerTitle: "片刻自问",
            footerText: "今天留下了什么？"
        ))
        XCTAssertEqual(try repository.load(), saved)
    }

    func testLegacyArchiveLoadsWithDefaultFooterAndCanBeSaved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("reflection-v1.json")
        let legacy = #"{"version":1,"settings":{"isEnabled":false,"text":"记住重要的事。"}}"#
        try Data(legacy.utf8).write(to: fileURL)
        let repository = ReflectionRepository(fileURL: fileURL)

        let settings = try repository.load()
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.text, "记住重要的事。")
        XCTAssertTrue(settings.footerEnabled)
        XCTAssertEqual(settings.footerTitle, ReflectionSettings.defaultFooterTitle)
        XCTAssertEqual(settings.footerText, ReflectionSettings.defaultFooterText)

        try repository.save(settings)
        let saved = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        let savedSettings = saved?["settings"] as? [String: Any]
        XCTAssertEqual(savedSettings?["footerEnabled"] as? Bool, true)
        XCTAssertEqual(savedSettings?["footerTitle"] as? String, ReflectionSettings.defaultFooterTitle)
        XCTAssertEqual(savedSettings?["footerText"] as? String, ReflectionSettings.defaultFooterText)
    }

    func testExistingFooterWithoutTitleKeepsTextAndGetsDefaultTitle() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("reflection-v1.json")
        let previous = #"{"version":1,"settings":{"isEnabled":true,"text":"看见当下。","footerEnabled":false,"footerText":"今日所学是什么？"}}"#
        try Data(previous.utf8).write(to: fileURL)

        let settings = try ReflectionRepository(fileURL: fileURL).load()
        XCTAssertEqual(settings.footerTitle, ReflectionSettings.defaultFooterTitle)
        XCTAssertFalse(settings.footerEnabled)
        XCTAssertEqual(settings.footerText, "今日所学是什么？")
    }

    func testInvalidChangePreservesExistingSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ReflectionRepository(fileURL: directory.appendingPathComponent("reflection-v1.json"))
        let original = ReflectionSettings(isEnabled: true, text: "此刻最重要的是什么？")
        try repository.save(original)
        let originalData = try Data(contentsOf: repository.fileURL)

        XCTAssertThrowsError(try repository.save(ReflectionSettings(isEnabled: false, text: "  \n ")))
        XCTAssertThrowsError(try repository.save(ReflectionSettings(
            isEnabled: true, text: original.text, footerEnabled: false, footerText: "  \n "
        )))
        XCTAssertThrowsError(try repository.save(ReflectionSettings(
            isEnabled: true, text: original.text,
            footerText: String(repeating: "思", count: 101)
        )))
        XCTAssertThrowsError(try repository.save(ReflectionSettings(
            isEnabled: true, text: original.text, footerTitle: "  \n "
        )))
        XCTAssertThrowsError(try repository.save(ReflectionSettings(
            isEnabled: true, text: original.text, footerTitle: "第一行\n第二行"
        )))
        XCTAssertThrowsError(try repository.save(ReflectionSettings(
            isEnabled: true, text: original.text, footerTitle: "超过八个汉字的标题文字"
        )))
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), originalData)
        XCTAssertEqual(try repository.load(), original)
    }

    func testUnreadableSettingsCannotBeSilentlyReplaced() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("reflection-v1.json")
        try Data("not JSON".utf8).write(to: fileURL)
        let repository = ReflectionRepository(fileURL: fileURL)

        XCTAssertThrowsError(try repository.save(.defaultValue))
        XCTAssertEqual(try Data(contentsOf: fileURL), Data("not JSON".utf8))
    }
}
