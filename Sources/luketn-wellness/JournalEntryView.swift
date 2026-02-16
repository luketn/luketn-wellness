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
    @State private var keyMonitor: Any?
    @State private var focusedEntryID: UUID?
    @State private var autosaveWorkItem: DispatchWorkItem?
    @State private var undoStack: [[String]] = []
    @State private var redoStack: [[String]] = []
    @State private var isApplyingHistory = false

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
                                    },
                                    onBeginEditing: {
                                        focusedEntryID = entries[idx].id
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
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        undoChange()
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(undoStack.isEmpty)
                    .help("Undo")

                    Button {
                        redoChange()
                    } label: {
                        Image(systemName: "arrow.uturn.forward.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(redoStack.isEmpty)
                    .help("Redo")
                }
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
            autosaveWorkItem?.cancel()
        }
    }

    private func currentSnapshot() -> [String] {
        entries.map { $0.text.string }
    }

    private func persistSnapshotNow() {
        do {
            let url = try appModel.persistEntriesSnapshot(currentSnapshot(), on: selectedDate)
            saveMessage = "Autosaved: \(url.lastPathComponent)"
        } catch {
            saveMessage = "Autosave failed: \(error.localizedDescription)"
        }
    }

    private func entryBinding(at index: Int) -> Binding<NSAttributedString> {
        Binding(
            get: { entries[index].text },
            set: { newValue in
                let previous = currentSnapshot()
                entries[index].text = newValue
                registerUserChange(previous: previous)
            }
        )
    }

    private func addEntry(focusNew: Bool) {
        let previous = currentSnapshot()
        entries.append(EntryItem(text: NSAttributedString(string: "")))
        if focusNew {
            focusedEntryID = entries.last?.id
        }
        registerUserChange(previous: previous)
    }

    private func index(for id: UUID) -> Int? {
        entries.firstIndex(where: { $0.id == id })
    }

    private func deleteEntry(id: UUID) {
        guard let idx = index(for: id) else { return }
        let previous = currentSnapshot()

        if entries.count == 1 {
            entries[0].text = NSAttributedString(string: "")
            focusedEntryID = entries[0].id
            registerUserChange(previous: previous)
            return
        }

        entries.remove(at: idx)
        let nextIndex = min(idx, entries.count - 1)
        focusedEntryID = entries[nextIndex].id
        registerUserChange(previous: previous)
    }

    private func reorderEntries(from draggedID: UUID?, to targetID: UUID) -> Bool {
        let previous = currentSnapshot()
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
        registerUserChange(previous: previous)
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
        autosaveWorkItem?.cancel()
        let history = appModel.loadChangeHistory(on: selectedDate)
        if let latest = history.last {
            applySnapshot(latest)
            undoStack = Array(history.dropLast())
        } else {
            let loaded = appModel.loadGratitudeEntries(on: selectedDate)
            applySnapshot(loaded)
            undoStack = []
        }
        redoStack = []
        saveMessage = ""
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
    }

    private func closeWindow() {
        autosaveWorkItem?.cancel()
        persistSnapshotNow()
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
                closeWindow()
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

    private func registerUserChange(previous: [String]) {
        guard !isApplyingHistory else { return }
        let current = currentSnapshot()
        guard current != previous else { return }

        undoStack.append(previous)
        if undoStack.count > 100 {
            undoStack = Array(undoStack.suffix(100))
        }
        redoStack.removeAll(keepingCapacity: true)
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        autosaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            persistSnapshotNow()
        }
        autosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }

    private func undoChange() {
        guard let previous = undoStack.popLast() else { return }
        let current = currentSnapshot()
        redoStack.append(current)
        if redoStack.count > 100 {
            redoStack = Array(redoStack.suffix(100))
        }
        applySnapshot(previous)
        scheduleAutosave()
    }

    private func redoChange() {
        guard let next = redoStack.popLast() else { return }
        let current = currentSnapshot()
        undoStack.append(current)
        if undoStack.count > 100 {
            undoStack = Array(undoStack.suffix(100))
        }
        applySnapshot(next)
        scheduleAutosave()
    }

    private func applySnapshot(_ snapshot: [String]) {
        isApplyingHistory = true
        defer { isApplyingHistory = false }

        if snapshot.isEmpty {
            entries = [EntryItem(text: NSAttributedString(string: ""))]
        } else {
            entries = snapshot.map { EntryItem(text: NSAttributedString(string: $0)) }
        }
        focusedEntryID = entries.first?.id
    }
}
