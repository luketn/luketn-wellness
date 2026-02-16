import AppKit
import SwiftUI

struct JournalEntryView: View {
    struct EntryItem: Identifiable {
        let id = UUID()
        var text: NSAttributedString
    }

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [EntryItem] = [EntryItem(text: NSAttributedString(string: ""))]
    @State private var selectedDate = JournalDateNavigator.today()
    @State private var saveMessage = ""
    @State private var isSaving = false
    @State private var keyMonitor: Any?
    @State private var focusedEntryID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Gratitude Journal")
                    .font(.title2.weight(.bold))

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
                    .font(.headline.weight(.semibold))
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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
            )

            Text(appModel.gratitudePromptText)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        if let idx = index(for: entry.id) {
                            HStack(alignment: .top, spacing: 8) {
                                RichTextEditor(
                                    text: entryBinding(at: idx),
                                    isFocused: focusedEntryID == entries[idx].id,
                                    onDropDraggedEntry: { draggedID in
                                        reorderEntries(from: draggedID, to: entry.id)
                                    }
                                )
                                .frame(minHeight: 130)

                                VStack(spacing: 8) {
                                    Button {
                                        deleteEntry(id: entry.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.callout)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete this entry")

                                    Image(systemName: "line.3.horizontal")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .padding(6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(.thinMaterial)
                                        )
                                        .help("Drag to reorder entries")
                                        .draggable(JournalDragToken.encode(id: entry.id)) {
                                            dragPreview(for: entry)
                                        }
                                }
                                .padding(.top, 8)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.regularMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        focusedEntryID == entries[idx].id
                                        ? Color.accentColor.opacity(0.55)
                                        : Color.secondary.opacity(0.22),
                                        lineWidth: 1
                                    )
                            )
                            .dropDestination(for: String.self) { items, _ in
                                let draggedID = items.first.flatMap(JournalDragToken.decode)
                                return reorderEntries(from: draggedID, to: entry.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
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
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.28, blue: 0.24).opacity(0.15),
                    Color(red: 0.18, green: 0.33, blue: 0.46).opacity(0.11),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            installKeyMonitor()
            loadEntriesForSelectedDate()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private var canSave: Bool {
        !entries.isEmpty && entries.allSatisfy {
            !$0.text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func saveEntry(closeAfterSave: Bool) {
        isSaving = true
        defer { isSaving = false }

        guard canSave else {
            saveMessage = "Fill in all visible entries or remove empty ones."
            return
        }

        let cleanedEntries = entries
            .map { $0.text.string.trimmingCharacters(in: .whitespacesAndNewlines) }

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

    private func entryBinding(at index: Int) -> Binding<NSAttributedString> {
        Binding(
            get: { entries[index].text },
            set: { entries[index].text = $0 }
        )
    }

    private func addEntry(focusNew: Bool) {
        entries.append(EntryItem(text: NSAttributedString(string: "")))
        if focusNew {
            focusedEntryID = entries.last?.id
        }
    }

    private func index(for id: UUID) -> Int? {
        entries.firstIndex(where: { $0.id == id })
    }

    private func deleteEntry(id: UUID) {
        guard let idx = index(for: id) else { return }

        if entries.count == 1 {
            entries[0].text = NSAttributedString(string: "")
            focusedEntryID = entries[0].id
            return
        }

        entries.remove(at: idx)
        let nextIndex = min(idx, entries.count - 1)
        focusedEntryID = entries[nextIndex].id
    }

    private func reorderEntries(from draggedID: UUID?, to targetID: UUID) -> Bool {
        guard
            let draggedID,
            let reorderedIDs = JournalEntryReorder.reorderedIDs(
                entries.map(\.id),
                draggedID: draggedID,
                targetID: targetID
            )
        else {
            return false
        }

        let byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        entries = reorderedIDs.compactMap { byID[$0] }
        return true
    }

    @ViewBuilder
    private func dragPreview(for entry: EntryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Entry")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(entry.text.string.isEmpty ? " " : entry.text.string)
                .lineLimit(4)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(width: 380, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .opacity(0.78)
    }

    private func loadEntriesForSelectedDate() {
        let loaded = appModel.loadGratitudeEntries(on: selectedDate)
        if loaded.isEmpty {
            entries = [EntryItem(text: NSAttributedString(string: ""))]
        } else {
            entries = loaded.map { EntryItem(text: NSAttributedString(string: $0)) }
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
