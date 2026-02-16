import SwiftUI

struct JournalEntryView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var entries = Array(repeating: "", count: 5)
    @State private var saveMessage = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gratitude Journal")
                .font(.title2.weight(.semibold))

            Text(appModel.gratitudePromptText)
                .font(.body)
                .foregroundStyle(.secondary)

            ForEach(entries.indices, id: \.self) { idx in
                TextField("Gratitude \(idx + 1)", text: $entries[idx], axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            HStack {
                Button(isSaving ? "Saving..." : "Save Entry") {
                    saveEntry()
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
        .frame(width: 560)
    }

    private var canSave: Bool {
        entries.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func saveEntry() {
        isSaving = true
        defer { isSaving = false }

        do {
            let url = try appModel.saveGratitudeEntries(entries)
            saveMessage = "Saved: \(url.path)"
            entries = Array(repeating: "", count: 5)
        } catch {
            saveMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
