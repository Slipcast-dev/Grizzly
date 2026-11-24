import SwiftUI

/// Colors for `SyntaxEngine` output.
enum Syntax {
    static func color(_ role: SyntaxRole, _ t: Theme) -> Color {
        switch role {
        case .key: return t.key
        case .string: return t.string
        case .number: return t.number
        case .keyword: return t.keyword
        case .comment, .secondary: return t.comment
        case .error: return t.error
        case .warning: return t.warning
        case .success: return t.success
        }
    }
}
