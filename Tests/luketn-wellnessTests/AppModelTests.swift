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

    @Test
    func latestSnapshotWinsAfterRapidSuccessivePersists() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let model = AppModel(
            journalDirectoryURL: tempDirectory,
            observeSystemNotifications: false,
            setAccessoryActivationPolicy: false,
            showFirstLaunchPrompt: false
        )

        let date = Date(timeIntervalSince1970: 1_741_111_111)
        _ = try model.persistEntriesSnapshot(["first"], on: date)
        _ = try model.persistEntriesSnapshot(["second"], on: date)
        _ = try model.persistEntriesSnapshot(["final", "state"], on: date)

        let loaded = model.loadGratitudeEntries(on: date)
        #expect(loaded == ["final", "state"])
    }

    @Test
    func loadUsesChangelogAsSourceOfTruth() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let model = AppModel(
            journalDirectoryURL: tempDirectory,
            observeSystemNotifications: false,
            setAccessoryActivationPolicy: false,
            showFirstLaunchPrompt: false
        )

        let date = Date(timeIntervalSince1970: 1_742_222_222)
        let journalURL = try model.persistEntriesSnapshot(["correct"], on: date)

        // Simulate markdown getting out of sync; load should still return changelog latest.
        try "1. stale".write(to: journalURL, atomically: true, encoding: .utf8)

        let loaded = model.loadGratitudeEntries(on: date)
        #expect(loaded == ["correct"])
    }

    @Test
    func identicalSnapshotsAreNotDuplicatedInChangelog() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let model = AppModel(
            journalDirectoryURL: tempDirectory,
            observeSystemNotifications: false,
            setAccessoryActivationPolicy: false,
            showFirstLaunchPrompt: false
        )

        let date = Date(timeIntervalSince1970: 1_743_333_333)
        _ = try model.persistEntriesSnapshot(["same"], on: date)
        _ = try model.persistEntriesSnapshot(["same"], on: date)
        _ = try model.persistEntriesSnapshot(["same"], on: date)

        let history = model.loadChangeHistory(on: date)
        #expect(history.count == 1)
        #expect(history.first == ["same"])
    }

    @Test
    func changelogIsWrittenToDotLogFolder() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let model = AppModel(
            journalDirectoryURL: tempDirectory,
            observeSystemNotifications: false,
            setAccessoryActivationPolicy: false,
            showFirstLaunchPrompt: false
        )

        var comps = DateComponents()
        comps.year = 2026
        comps.month = 2
        comps.day = 16
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: comps))

        _ = try model.persistEntriesSnapshot(["entry"], on: date)

        let changelog = tempDirectory
            .appendingPathComponent(".log")
            .appendingPathComponent("journal-2026-02-16.changelog.jsonl")

        #expect(FileManager.default.fileExists(atPath: changelog.path))
    }

    private func makeTempDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
        let path = root.appendingPathComponent("wellness-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }
}
