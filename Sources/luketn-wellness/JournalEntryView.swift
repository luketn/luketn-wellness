import AppKit
import SwiftUI

struct JournalEntryView: View {
    struct EntryItem: Identifiable {
        let id = UUID()
        var text: String
    }

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [EntryItem] = [EntryItem(text: "")]
    @State private var selectedDate = JournalDateNavigator.today()
    @State private var saveMessage = ""
    @State private var isSaving = false
    @State private var keyMonitor: Any?
    @FocusState private var focusedEntryID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Gratitude Journal")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    shiftDay(-1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Previous day")

                Text(appModel.displayDateString(for: selectedDate))
                    .font(.headline)
                    .frame(minWidth: 250)

                Button {
                    shiftDay(1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Next day")

                Button("Today") {
                    jumpToToday()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Jump to today")

                Spacer()

                Button {
                    addEntry(focusNew: true)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Add another entry... (Option-Tab Shortcut)")
            }

            Text(appModel.gratitudePromptText)
                .font(.body)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(entries.indices, id: \.self) { idx in
                        TextEditor(text: entryBinding(at: idx))
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 100)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                            .focused($focusedEntryID, equals: entries[idx].id)
                    }
                }
            }

            HStack {
                Button(isSaving ? "Saving..." : "Save Entry") {
                    saveEntry(closeAfterSave: false)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || !canSave)

                Spacer()

                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(width: 560, height: 520)
        .onAppear {
            installKeyMonitor()
            loadEntriesForSelectedDate()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private var canSave: Bool {
        entries.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func saveEntry(closeAfterSave: Bool) {
        isSaving = true
        defer { isSaving = false }

        let cleanedEntries = entries
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedEntries.isEmpty else {
            saveMessage = "Add at least one gratitude item."
            return
        }

        do {
            let url = try appModel.saveGratitudeEntries(cleanedEntries, on: selectedDate)
            saveMessage = "Saved: \(url.path)"
            loadEntriesForSelectedDate()
            if closeAfterSave {
                closeWindow()
            }
        } catch {
            saveMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func entryBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { entries[index].text },
            set: { entries[index].text = $0 }
        )
    }

    private func addEntry(focusNew: Bool) {
        entries.append(EntryItem(text: ""))
        if focusNew {
            focusedEntryID = entries.last?.id
        }
    }

    private func loadEntriesForSelectedDate() {
        let loaded = appModel.loadGratitudeEntries(on: selectedDate)
        if loaded.isEmpty {
            entries = [EntryItem(text: "")]
        } else {
            entries = loaded.map { EntryItem(text: $0) }
        }
        focusedEntryID = entries.first?.id
    }

    private func shiftDay(_ value: Int) {
        selectedDate = JournalDateNavigator.shiftedDay(from: selectedDate, by: value)
        loadEntriesForSelectedDate()
        saveMessage = ""
    }

    private func jumpToToday() {
        selectedDate = JournalDateNavigator.today()
        loadEntriesForSelectedDate()
        saveMessage = ""
    }

    private func closeWindow() {
        NSApp.keyWindow?.performClose(nil)
        dismiss()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch JournalShortcutInterpreter.action(for: event) {
            case .addEntry:
                addEntry(focusNew: true)
                return nil
            case .saveAndClose:
                saveEntry(closeAfterSave: true)
                return nil
            case nil:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}
