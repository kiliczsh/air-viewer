import Foundation
import Observation

@MainActor @Observable
final class ReportStore {
    private static let recentReportsKey = "recentReports"

    var report: ImportedReport?
    var entries: [ReportEntry] = []
    var recentReports: [SavedReport] = []
    var scope: ReportScope = .prompts
    var selectedID: ReportEntry.ID?
    var searchText = ""
    var roleFilter = "All"
    var errorMessage: String?
    var reimportCandidate: SavedReport?

    init() {
        recentReports = Self.loadRecentReports()
    }

    var filteredEntries: [ReportEntry] {
        let searchTerm = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return entries.filter { entry in
            guard entry.scope == scope else { return false }
            guard roleFilter == "All" || entry.role?.lowercased() == roleFilter.lowercased() else { return false }
            return searchTerm.isEmpty || entry.searchIndex.localizedStandardContains(searchTerm)
        }
    }

    var selectedEntry: ReportEntry? { entries.first { $0.id == selectedID } }
    var availableRoles: [String] { Array(Set(entries.compactMap(\.role))).sorted() }

    func count(for scope: ReportScope) -> Int { entries.count { $0.scope == scope } }

    func resetFilters() {
        searchText = ""
        roleFilter = "All"
    }

    func importReport(from url: URL) {
        if let savedReport = reimportCandidate {
            reimport(savedReport, from: url)
        } else {
            loadReport(from: url, replacingHistoryEntry: nil)
        }
    }

    func reopen(_ savedReport: SavedReport) {
        guard let bookmark = savedReport.bookmark else {
            reopenFromSavedLocation(savedReport)
            return
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            loadReport(from: url, replacingHistoryEntry: savedReport)
        } catch {
            reopenFromSavedLocation(savedReport)
        }
    }

    func forget(_ savedReport: SavedReport) {
        recentReports.removeAll { $0.id == savedReport.id }
        persistRecentReports()
    }

    private func reimport(_ savedReport: SavedReport, from url: URL) {
        guard url.standardizedFileURL.path == savedReport.path else {
            errorMessage = "Choose the original file at \(savedReport.path) to update this history entry."
            return
        }
        reimportCandidate = nil
        loadReport(from: url, replacingHistoryEntry: savedReport)
    }

    private func reopenFromSavedLocation(_ savedReport: SavedReport) {
        let url = URL(fileURLWithPath: savedReport.path)
        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: savedReport.path, isDirectory: &isDirectory)

        guard fileExists, !isDirectory.boolValue, url.pathExtension.lowercased() == "json" else {
            requestManualReimport(for: savedReport)
            return
        }

        // If the original file is still available, refresh this exact history entry automatically.
        loadReport(from: url, replacingHistoryEntry: savedReport)
    }

    private func requestManualReimport(for savedReport: SavedReport) {
        reimportCandidate = savedReport
        errorMessage = "Couldn’t automatically access \(savedReport.filename). Choose Re-Import if the original file is still at \(savedReport.path)."
    }

    private func loadReport(from url: URL, replacingHistoryEntry: SavedReport?) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let object = try JSONSerialization.jsonObject(with: data)
            let parsed = ReportParser.parse(object)
            guard !parsed.isEmpty else { throw ImportError.noRecognizableContent }

            entries = parsed
            report = ImportedReport(filename: url.lastPathComponent, importedAt: .now, requestCount: parsed.count { $0.scope == .thread })
            saveReportBookmark(for: url, replacing: replacingHistoryEntry)
            scope = parsed.contains { $0.scope == .prompts } ? .prompts : parsed[0].scope
            resetFilters()
            selectedID = filteredEntries.first?.id
        } catch {
            if let replacingHistoryEntry {
                requestManualReimport(for: replacingHistoryEntry)
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveReportBookmark(for url: URL, replacing savedReport: SavedReport?) {
        let bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        let normalizedPath = url.standardizedFileURL.path
        if let savedReport {
            recentReports.removeAll { $0.id == savedReport.id }
        } else {
            recentReports.removeAll { $0.path == normalizedPath }
        }
        recentReports.insert(SavedReport(id: savedReport?.id ?? UUID(), filename: url.lastPathComponent, path: normalizedPath, importedAt: .now, bookmark: bookmark), at: 0)
        persistRecentReports()
    }

    private func persistRecentReports() {
        guard let data = try? JSONEncoder().encode(recentReports) else { return }
        UserDefaults.standard.set(data, forKey: Self.recentReportsKey)
    }

    private static func loadRecentReports() -> [SavedReport] {
        guard let data = UserDefaults.standard.data(forKey: recentReportsKey), let savedReports = try? JSONDecoder().decode([SavedReport].self, from: data) else { return [] }
        return savedReports.sorted { $0.importedAt > $1.importedAt }
    }
}

private enum ImportError: LocalizedError {
    case noRecognizableContent
    var errorDescription: String? { "This JSON did not contain readable Apple Intelligence report content." }
}
