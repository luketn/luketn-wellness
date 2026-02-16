import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wellness")
                .font(.headline.weight(.semibold))

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open Gratitude Journal") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "journal")
            }

            Divider()

            Toggle("Start at Login", isOn: Binding(
                get: { appModel.launchAtLoginEnabled },
                set: { appModel.setLaunchAtLoginEnabled($0) }
            ))

            Toggle("Notify on State Change", isOn: Binding(
                get: { appModel.notificationsEnabled },
                set: { appModel.setNotificationsEnabled($0) }
            ))

            Menu("Notification State") {
                ForEach(NotificationStateFilter.allCases, id: \.self) { option in
                    Button {
                        appModel.setNotificationStateFilter(option)
                    } label: {
                        HStack {
                            Text(option.title)
                            if appModel.notificationStateFilter == option {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .disabled(!appModel.notificationsEnabled)

            if appModel.currentReminder == .savor {
                Button("I savored something today") {
                    appModel.markSavorAcknowledged()
                }
            }

            if appModel.currentReminder != .none {
                Button("Dismiss Reminder") {
                    appModel.clearReminder()
                }
            }

            Divider()

            Button("Quit Wellness") {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(width: 280)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
        )
    }

    private var statusText: String {
        switch appModel.currentReminder {
        case .none:
            return "No reminder right now."
        case .gratitude:
            return "Sleep reminder: capture your gratitude before you wrap up."
        case .savor:
            return "New day reminder: savor one meaningful moment today."
        }
    }
}

struct MenuBarIconView: View {
    let reminder: ReminderState
    @State private var glow = false

    var body: some View {
        Image(systemName: "leaf.fill")
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(primaryColor)
            .font(.system(size: 18, weight: .bold))
            .shadow(color: glowColor.opacity(glow ? 0.95 : 0.1), radius: glow ? 8 : 1)
            .scaleEffect(glow ? 1.12 : 1.0)
            .animation(animation, value: glow)
            .onAppear {
                updateGlowState()
            }
            .onChange(of: reminder) { _, _ in
                updateGlowState()
            }
            .accessibilityLabel("Wellness")
    }

    private var primaryColor: Color {
        switch reminder {
        case .none:
            return Color(red: 0.20, green: 0.64, blue: 0.43)
        case .gratitude:
            return Color(red: 0.95, green: 0.65, blue: 0.23)
        case .savor:
            return Color(red: 0.25, green: 0.54, blue: 0.93)
        }
    }

    private var glowColor: Color {
        switch reminder {
        case .none:
            return .clear
        case .gratitude:
            return Color(red: 0.96, green: 0.67, blue: 0.27)
        case .savor:
            return Color(red: 0.31, green: 0.60, blue: 1.0)
        }
    }

    private var animation: Animation? {
        reminder == .none ? .none : .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    }

    private func updateGlowState() {
        if reminder == .none {
            glow = false
        } else {
            glow = true
        }
    }
}
