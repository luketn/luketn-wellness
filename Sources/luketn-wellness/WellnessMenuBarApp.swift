import AppKit
import SwiftUI

@main
struct WellnessMenuBarApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(appModel)
        } label: {
            MenuBarIconView(reminder: appModel.currentReminder)
        }
        .menuBarExtraStyle(.window)

        WindowGroup(id: "journal") {
            JournalEntryView()
                .environment(appModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 520)
        .commands {
        CommandGroup(replacing: .appTermination) {
            Button("Close Window") {
                NSApplication.shared.keyWindow?.performClose(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
    }
}
