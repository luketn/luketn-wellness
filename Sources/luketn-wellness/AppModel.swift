import AppKit
import Foundation
import Observation
import SwiftUI

enum ReminderState: Equatable {
    case none
    case gratitude
    case savor
}

@Observable
@MainActor
final class AppModel {
    var currentReminder: ReminderState = .none

    let gratitudePromptText = """
    Write one or more things you are grateful for today.
    Keep each one specific and personal, and include a short reason.
    """

    let savorPromptText = "Pause for one meaningful moment today and really savor it."

    private let lastLoginKey = "wellness.lastLoginDate"
    private let sleepCenter = NSWorkspace.shared.notificationCenter
    private let fileManager: FileManager
    private let journalDirectoryURLValue: URL
    private let nowProvider: () -> Date
    private let observingSystemNotifications: Bool

    init(
        fileManager: FileManager = .default,
        journalDirectoryURL: URL? = nil,
        nowProvider: @escaping () -> Date = Date.init,
        observeSystemNotifications: Bool = true,
        setAccessoryActivationPolicy: Bool = true
    ) {
        self.fileManager = fileManager
        self.journalDirectoryURLValue = journalDirectoryURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("OneDrive")
            .appendingPathComponent("GratitudeJournal")
        self.nowProvider = nowProvider
        self.observingSystemNotifications = observeSystemNotifications

        if setAccessoryActivationPolicy {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        if observeSystemNotifications {
            setupSleepObservation()
        }
        handleDailyLoginReminder()
    }

    deinit {
        if observingSystemNotifications {
            sleepCenter.removeObserver(self)
        }
    }

    func clearReminder() {
        currentReminder = .none
    }

    func markSavorAcknowledged() {
        if currentReminder == .savor {
            currentReminder = .none
        }
    }

    func displayDateString(for date: Date) -> String {
        Self.longDateFormatter.string(from: date)
    }

    func loadGratitudeEntries(on date: Date) -> [String] {
        let fileURL = journalFileURL(for: date)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        guard let markdown = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        var loaded: [String] = []
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: true) {
            let text = String(line).trimmingCharacters(in: .whitespacesAndNewlines)

            if let range = text.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                loaded.append(String(text[range.upperBound...]))
                continue
            }

            if text.hasPrefix("- ") {
                loaded.append(String(text.dropFirst(2)))
            }
        }
        return loaded
    }

    func saveGratitudeEntries(_ entries: [String], on date: Date) throws -> URL {
        let directory = journalDirectoryURL
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = journalFileURL(for: date)
        let body = markdownContent(for: entries, on: date)
        try body.write(to: fileURL, atomically: true, encoding: .utf8)

        if currentReminder == .gratitude {
            currentReminder = .none
        }
        return fileURL
    }

    private func setupSleepObservation() {
        sleepCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }

    private func handleDailyLoginReminder() {
        let defaults = UserDefaults.standard
        let now = nowProvider()
        let last = defaults.object(forKey: lastLoginKey) as? Date

        if last == nil || !Calendar.current.isDate(last!, inSameDayAs: now) {
            currentReminder = .savor
            defaults.set(now, forKey: lastLoginKey)
        }
    }

    private var journalDirectoryURL: URL {
        journalDirectoryURLValue
    }

    private func journalFileURL(for date: Date) -> URL {
        let dateText = Self.dayFormatter.string(from: date)
        return journalDirectoryURL.appendingPathComponent("journal-\(dateText).md")
    }

    private func markdownContent(for entries: [String], on date: Date) -> String {
        var content = "# Gratitude Journal\n"
        content += "## \(Self.longDateFormatter.string(from: date))\n\n"

        for (index, entry) in entries.enumerated() {
            content += "\(index + 1). \(entry.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }
        return content
    }

    @objc
    private func handleWillSleep() {
        currentReminder = .gratitude
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
}
