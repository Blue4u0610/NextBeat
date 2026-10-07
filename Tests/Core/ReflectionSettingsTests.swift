import Foundation
import XCTest
@testable import NextBeatCore

final class ReflectionSettingsTests: XCTestCase {
    func testDefaultAndRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ReflectionRepository(fileURL: directory.appendingPathComponent("reflection-v1.json"))

        XCTAssertEqual(try repository.load(), .defaultValue)
        let saved = try repository.save(ReflectionSettings(isEnabled: false, text: "  慢一点，想清楚再行动。  "))
        XCTAssertEqual(saved, ReflectionSettings(isEnabled: false, text: "慢一点，想清楚再行动。"))
        XCTAssertEqual(try repository.load(), saved)
    }

    func testInvalidChangePreservesExistingSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ReflectionRepository(fileURL: directory.appendingPathComponent("reflection-v1.json"))
        let original = ReflectionSettings(isEnabled: true, text: "此刻最重要的是什么？")
        try repository.save(original)

        XCTAssertThrowsError(try repository.save(ReflectionSettings(isEnabled: false, text: "  \n ")))
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
