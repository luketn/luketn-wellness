import AppKit
import Foundation
import SwiftUI

enum ReminderState: Equatable {
    case none
    case gratitude
    case savor
}

@MainActor
final class AppModel: ObservableObject {
    @Published var currentReminder: ReminderState = .none

    let gratitudePromptText = """
    Write five things you are grateful for today.
    Keep each one specific and personal, and include a short reason.
    """

    let savorPromptText = "Pause for one meaningful moment today and really savor it."

    private let lastLoginKey = "wellness.lastLoginDate"
    private let sleepCenter = NSWorkspace.shared.notificationCenter

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        setupSleepObservation()
        handleDailyLoginReminder()
    }

    deinit {
        sleepCenter.removeObserver(self)
    }

    func clearReminder() {
        currentReminder = .none
    }

    func markSavorAcknowledged() {
        if currentReminder == .savor {
            currentReminder = .none
        }
    }

    func saveGratitudeEntries(_ entries: [String]) throws -> URL {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("OneDrive")
            .appendingPathComponent("GratitudeJournal")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let dateText = Self.dayFormatter.string(from: Date())
        let fileURL = directory.appendingPathComponent("journal-\(dateText).md")
        let body = markdownContent(for: entries, on: Date())

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let existing = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            let merged = existing.isEmpty ? body : "\(existing)\n\n\(body)"
            try merged.write(to: fileURL, atomically: true, encoding: .utf8)
        } else {
            try body.write(to: fileURL, atomically: true, encoding: .utf8)
        }

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
        let now = Date()
        let last = defaults.object(forKey: lastLoginKey) as? Date

        if last == nil || !Calendar.current.isDate(last!, inSameDayAs: now) {
            currentReminder = .savor
            defaults.set(now, forKey: lastLoginKey)
        }
    }

    private func markdownContent(for entries: [String], on date: Date) -> String {
        let timestamp = Self.timestampFormatter.string(from: date)
        var content = "## Gratitude Entry (\(timestamp))\n\n"
        content += "\(gratitudePromptText)\n\n"

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

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
