import Foundation

enum JournalDragToken {
    static let prefix = "wellness-entry-id::"

    static func encode(id: UUID) -> String {
        "\(prefix)\(id.uuidString)"
    }

    static func decode(_ value: String) -> UUID? {
        guard value.hasPrefix(prefix) else { return nil }
        let raw = String(value.dropFirst(prefix.count))
        return UUID(uuidString: raw)
    }
}
