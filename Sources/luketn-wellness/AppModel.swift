import AppKit
import Foundation
import Observation
import ServiceManagement
import SwiftUI
import UserNotifications

enum ReminderState: Equatable {
    case none
    case gratitude
    case savor
}

enum NotificationStateFilter: String, CaseIterable {
    case gratitude
    case savor
    case both

    var title: String {
        switch self {
        case .gratitude:
            return "Gratitude Only"
        case .savor:
            return "Savor Only"
        case .both:
            return "Both States"
        }
    }

    func includes(_ reminder: ReminderState) -> Bool {
        switch self {
        case .gratitude:
            return reminder == .gratitude
        case .savor:
            return reminder == .savor
        case .both:
            return reminder == .gratitude || reminder == .savor
        }
    }
}

@Observable
@MainActor
final class AppModel {
    var currentReminder: ReminderState = .none {
        didSet {
            handleReminderStateChange(from: oldValue, to: currentReminder)
        }
    }
    var launchAtLoginEnabled = false
    var notificationsEnabled = false
    var notificationStateFilter: NotificationStateFilter = .both

    let gratitudePromptText = """
    Write one or more things you are grateful for today.
    Keep each one specific and personal, and include a short reason.
    """

    let savorPromptText = "Pause for one meaningful moment today and really savor it."

    private let lastLoginKey = "wellness.lastLoginDate"
    private let firstLaunchPromptShownKey = "wellness.firstLaunchPromptShown"
    private let notificationsEnabledKey = "wellness.notificationsEnabled"
    private let notificationFilterKey = "wellness.notificationStateFilter"
    private let sleepCenter = NSWorkspace.shared.notificationCenter
    private let fileManager: FileManager
    private let journalDirectoryURLValue: URL
    private let nowProvider: () -> Date
    private let observingSystemNotifications: Bool
    private let showFirstLaunchPrompt: Bool

    init(
        fileManager: FileManager = .default,
        journalDirectoryURL: URL? = nil,
        nowProvider: @escaping () -> Date = Date.init,
        observeSystemNotifications: Bool = true,
        setAccessoryActivationPolicy: Bool = true,
        showFirstLaunchPrompt: Bool = true
    ) {
        self.fileManager = fileManager
        self.journalDirectoryURLValue = journalDirectoryURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("OneDrive")
            .appendingPathComponent("GratitudeJournal")
        self.nowProvider = nowProvider
        self.observingSystemNotifications = observeSystemNotifications
        self.showFirstLaunchPrompt = showFirstLaunchPrompt

        if setAccessoryActivationPolicy {
            // Use regular activation so the app appears in Command-Tab.
            NSApplication.shared.setActivationPolicy(.regular)
        }
        if observeSystemNotifications {
            setupSleepObservation()
        }
        loadPreferences()
        refreshLaunchAtLoginStatus()
        handleDailyLoginReminder()
        if showFirstLaunchPrompt {
            promptForLaunchAtLoginIfNeeded()
        }
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

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus()
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        if !enabled {
            notificationsEnabled = false
            persistPreferences()
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.notificationsEnabled = granted
                self?.persistPreferences()
            }
        }
    }

    func setNotificationStateFilter(_ filter: NotificationStateFilter) {
        notificationStateFilter = filter
        persistPreferences()
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

    private func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = (status == .enabled)
    }

    private func promptForLaunchAtLoginIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: firstLaunchPromptShownKey) else { return }
        defaults.set(true, forKey: firstLaunchPromptShownKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Start Wellness at Login?"
            alert.informativeText = "Would you like Wellness to start automatically when you log in?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Enable")
            alert.addButton(withTitle: "Not Now")

            NSApplication.shared.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.setLaunchAtLoginEnabled(true)
            }
        }
    }

    private func loadPreferences() {
        let defaults = UserDefaults.standard
        notificationsEnabled = defaults.bool(forKey: notificationsEnabledKey)
        if
            let raw = defaults.string(forKey: notificationFilterKey),
            let parsed = NotificationStateFilter(rawValue: raw)
        {
            notificationStateFilter = parsed
        }
    }

    private func persistPreferences() {
        let defaults = UserDefaults.standard
        defaults.set(notificationsEnabled, forKey: notificationsEnabledKey)
        defaults.set(notificationStateFilter.rawValue, forKey: notificationFilterKey)
    }

    private func handleReminderStateChange(from oldValue: ReminderState, to newValue: ReminderState) {
        guard newValue != oldValue else { return }
        guard newValue != .none else { return }
        guard notificationsEnabled else { return }
        guard notificationStateFilter.includes(newValue) else { return }

        let content = UNMutableNotificationContent()
        switch newValue {
        case .gratitude:
            content.title = "Gratitude Reminder"
            content.body = "Sleep state detected. Capture today’s gratitude before you wrap up."
        case .savor:
            content.title = "Savor Reminder"
            content.body = "New day reminder: savor one meaningful moment today."
        case .none:
            return
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "wellness.reminder.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
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
