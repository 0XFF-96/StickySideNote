import Foundation

public enum NoteColor: String, Codable, CaseIterable {
    case sky, cyan, lavender, coral, gold, sun

    public var hex: String {
        switch self {
        case .sky: return "#a7cde8"
        case .cyan: return "#4dd0cf"
        case .lavender: return "#c9bfe5"
        case .coral: return "#e59fb1"
        case .gold: return "#f2b33c"
        case .sun: return "#f4d86b"
        }
    }

    public var next: NoteColor {
        let all = NoteColor.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

public struct Note: Codable, Identifiable, Equatable {
    public let id: UUID
    public var text: String
    public var color: NoteColor
    public let createdAt: Date

    public init(id: UUID = UUID(), text: String, color: NoteColor, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.color = color
        self.createdAt = createdAt
    }

    /// Text as it goes to the clipboard: surrounding whitespace removed.
    public var copyText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The single glyph shown on the collapsed tab.
    public var cap: String {
        guard let first = copyText.first else { return "·" }
        return String(first).uppercased()
    }
}
