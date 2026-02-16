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

enum JournalEntryReorder {
    static func reorderedIDs(_ ids: [UUID], draggedID: UUID, targetID: UUID) -> [UUID]? {
        guard
            draggedID != targetID,
            let fromIndex = ids.firstIndex(of: draggedID),
            let toIndex = ids.firstIndex(of: targetID)
        else {
            return nil
        }

        var reordered = ids
        let moved = reordered.remove(at: fromIndex)
        // Insert at target index in the post-removal array:
        // this makes downward drags land after the target and upward drags before it.
        reordered.insert(moved, at: toIndex)
        return reordered
    }
}

enum JournalFocusPlanner {
    static func nextFocusAfterAdd(current: UUID?, newEntryID: UUID, focusNew: Bool) -> UUID? {
        focusNew ? newEntryID : current
    }
}

enum JournalFocusStealGuard {
    static func shouldRequestProgrammaticFocus(
        isFocused: Bool,
        wasFocused: Bool,
        isFirstResponder: Bool
    ) -> Bool {
        guard isFocused else { return false }
        guard !isFirstResponder else { return false }
        // Only request focus on a transition into focused state; otherwise
        // the previously focused editor can keep stealing focus back.
        return !wasFocused
    }
}

enum JournalEntryValidation {
    static func allVisibleEntriesFilled(_ entries: [String]) -> Bool {
        !entries.isEmpty && entries.allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
