import Foundation
import SwiftUI

enum ReportScope: String, CaseIterable, Identifiable {
    case prompts, thread, strings, tools, pcc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prompts: "Prompts"
        case .thread: "Thread"
        case .strings: "Decoded Strings"
        case .tools: "Tools"
        case .pcc: "PCC"
        }
    }

    var icon: String {
        switch self {
        case .prompts: "text.quote"
        case .thread: "text.line.first.and.arrowtriangle.forward"
        case .strings: "curlybraces"
        case .tools: "wrench.and.screwdriver"
        case .pcc: "server.rack"
        }
    }

    var tint: Color {
        switch self {
        case .prompts: .indigo
        case .thread: .teal
        case .strings: .orange
        case .tools: .purple
        case .pcc: .pink
        }
    }
}

struct ImportedReport {
    let filename: String
    let importedAt: Date
    let requestCount: Int
}

struct SavedReport: Identifiable, Codable, Hashable {
    let id: UUID
    let filename: String
    let path: String
    let importedAt: Date
    /// Optional: history remains visible even if macOS cannot create a reopen bookmark.
    let bookmark: Data?
}

struct ReportEntry: Identifiable, Hashable {
    let id = UUID()
    let scope: ReportScope
    let title: String
    let preview: String
    let content: String
    let role: String?
    let tags: [String]
    let rawJSON: String
    let searchIndex: String
}
