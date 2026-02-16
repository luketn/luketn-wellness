import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wellness")
                .font(.headline)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open Gratitude Journal") {
                openWindow(id: "journal")
            }

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
        }
        .frame(width: 280)
        .padding(14)
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
        Image(systemName: "leaf.circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(primaryColor, .white.opacity(0.9))
            .font(.system(size: 16, weight: .semibold))
            .shadow(color: glowColor.opacity(glow ? 0.95 : 0.1), radius: glow ? 8 : 1)
            .scaleEffect(glow ? 1.12 : 1.0)
            .animation(animation, value: glow)
            .onAppear {
                updateGlowState()
            }
            .onChange(of: reminder) { _ in
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
