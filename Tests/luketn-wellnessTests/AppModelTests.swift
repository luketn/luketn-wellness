import Foundation
import Testing
@testable import luketn_wellness

@MainActor
struct AppModelTests {
    @Test
    func saveAndLoadEntriesForSpecificDate() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let model = AppModel(
            journalDirectoryURL: tempDirectory,
            observeSystemNotifications: false,
            setAccessoryActivationPolicy: false,
            showFirstLaunchPrompt: false
        )

        var dateComponents = DateComponents()
        dateComponents.year = 2026
        dateComponents.month = 2
        dateComponents.day = 16
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: dateComponents))

        _ = try model.saveGratitudeEntries(["Family", "Health"], on: date)

        let loaded = model.loadGratitudeEntries(on: date)
        #expect(loaded == ["Family", "Health"])
    }

    @Test
    func saveWritesHeadingAndDateSubheading() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let model = AppModel(
            journalDirectoryURL: tempDirectory,
            observeSystemNotifications: false,
            setAccessoryActivationPolicy: false,
            showFirstLaunchPrompt: false
        )

        var dateComponents = DateComponents()
        dateComponents.year = 2026
        dateComponents.month = 2
        dateComponents.day = 1
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: dateComponents))

        let fileURL = try model.saveGratitudeEntries(["Morning walk"], on: date)
        let markdown = try String(contentsOf: fileURL, encoding: .utf8)

        #expect(markdown.contains("# Gratitude Journal"))
        #expect(markdown.contains("## \(model.displayDateString(for: date))"))
        #expect(markdown.contains("1. Morning walk"))
        #expect(!markdown.contains("Write one or more things you are grateful for today."))
    }

    @Test
    func saveClearsGratitudeReminder() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let model = AppModel(
            journalDirectoryURL: tempDirectory,
            observeSystemNotifications: false,
            setAccessoryActivationPolicy: false,
            showFirstLaunchPrompt: false
        )

        model.currentReminder = .gratitude
        _ = try model.saveGratitudeEntries(["Tea"], on: Date())
        #expect(model.currentReminder == .none)
    }

    @Test
    func changelogKeepsOnlyLastHundredSnapshots() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let model = AppModel(
            journalDirectoryURL: tempDirectory,
            observeSystemNotifications: false,
            setAccessoryActivationPolicy: false,
            showFirstLaunchPrompt: false
        )

        let baseDate = Date(timeIntervalSince1970: 1_740_000_000)
        for i in 1...105 {
            _ = try model.persistEntriesSnapshot(["entry-\(i)"], on: baseDate)
        }

        let history = model.loadChangeHistory(on: baseDate)
        #expect(history.count == 100)
        #expect(history.first == ["entry-6"])
        #expect(history.last == ["entry-105"])
    }

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
        let path = root.appendingPathComponent("wellness-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }
}
