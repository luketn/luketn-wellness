import AppKit
import Foundation
import Testing
@testable import luketn_wellness

struct JournalUIBehaviorTests {
    @Test
    func optionTabMapsToAddEntryAction() {
        let action = JournalShortcutInterpreter.action(forKeyCode: 48, modifiers: [.option])
        #expect(action == .addEntry)
    }

    @Test
    func commandEnterMapsToSaveAndCloseAction() {
        let action = JournalShortcutInterpreter.action(forKeyCode: 36, modifiers: [.command])
        #expect(action == .saveAndClose)
    }

    @Test
    func unrelatedKeyHasNoAction() {
        let action = JournalShortcutInterpreter.action(forKeyCode: 0, modifiers: [])
        #expect(action == nil)
    }

    @Test
    func dateNavigatorShiftsByOneDay() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 16
        let calendar = Calendar(identifier: .gregorian)
        let base = try #require(calendar.date(from: components))

        let next = JournalDateNavigator.shiftedDay(from: base, by: 1, calendar: calendar)
        let previous = JournalDateNavigator.shiftedDay(from: base, by: -1, calendar: calendar)

        #expect(calendar.component(.day, from: next) == 17)
        #expect(calendar.component(.day, from: previous) == 15)
    }

    @Test
    func todayReturnsStartOfDay() {
        let calendar = Calendar(identifier: .gregorian)
        let fixedNow = Date(timeIntervalSince1970: 1_739_682_123)
        let result = JournalDateNavigator.today(calendar: calendar, now: { fixedNow })
        #expect(result == calendar.startOfDay(for: fixedNow))
    }
}
