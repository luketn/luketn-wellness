import AppKit
import Foundation

enum JournalShortcutAction: Equatable {
    case addEntry
    case saveAndClose
}

enum JournalShortcutInterpreter {
    static func action(for event: NSEvent) -> JournalShortcutAction? {
        action(forKeyCode: event.keyCode, modifiers: event.modifierFlags)
    }

    static func action(forKeyCode keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> JournalShortcutAction? {
        let cleanModifiers = modifiers.intersection(.deviceIndependentFlagsMask)
        let isTab = keyCode == 48
        let isEnter = keyCode == 36

        if isTab && cleanModifiers.contains(.option) && !cleanModifiers.contains(.command) {
            return .addEntry
        }

        if isEnter && cleanModifiers.contains(.command) {
            return .saveAndClose
        }

        return nil
    }
}

enum JournalDateNavigator {
    static func shiftedDay(from date: Date, by value: Int, calendar: Calendar = .current) -> Date {
        let shifted = calendar.date(byAdding: .day, value: value, to: date) ?? date
        return calendar.startOfDay(for: shifted)
    }

    static func today(calendar: Calendar = .current, now: () -> Date = Date.init) -> Date {
        calendar.startOfDay(for: now())
    }
}
