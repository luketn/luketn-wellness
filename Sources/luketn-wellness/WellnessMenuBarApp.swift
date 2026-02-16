import SwiftUI

@main
struct WellnessMenuBarApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appModel)
        } label: {
            MenuBarIconView(reminder: appModel.currentReminder)
        }
        .menuBarExtraStyle(.window)

        Window("Gratitude Journal", id: "journal") {
            JournalEntryView()
                .environmentObject(appModel)
        }
        .windowResizability(.contentSize)
    }
}
