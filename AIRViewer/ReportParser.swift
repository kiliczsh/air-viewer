import Foundation

enum ReportParser {
    private static let maximumEntries = 6_000
    private static let maximumContentLength = 120_000
    private static let maximumSourceLength = 32_000
    private static let maximumSearchLength = 16_000

    static func parse(_ root: Any) -> [ReportEntry] {
        var entries: [ReportEntry] = []
        walk(root, path: [], entries: &entries)
        return deduplicate(entries)
    }

    private static func walk(_ value: Any, path: [String], entries: inout [ReportEntry]) {
        guard entries.count < maximumEntries else { return }

        if let dictionary = value as? [String: Any] {
            parseRecord(dictionary, path: path, entries: &entries)
            for (key, child) in dictionary { walk(child, path: path + [key], entries: &entries) }
        } else if let array = value as? [Any] {
            for (index, child) in array.enumerated() { walk(child, path: path + ["[\(index)]"], entries: &entries) }
        } else if let string = value as? String, string.count > 20 {
            let decoded = decodeBase64(string)
            let label = path.suffix(2).joined(separator: " › ")
            entries.append(makeEntry(scope: .strings, title: label.isEmpty ? "String" : label, content: decoded ?? string, role: nil, tags: decoded == nil ? [] : ["base64 decoded"], source: value))
        }
    }

    private static func parseRecord(_ dictionary: [String: Any], path: [String], entries: inout [ReportEntry]) {
        let fields = Dictionary(uniqueKeysWithValues: dictionary.map { ($0.key.lowercased(), $0.value) })
        let role = string(in: fields, keys: ["role", "message_role"])
        let content = string(in: fields, keys: ["content", "text", "prompt", "value", "message"])
        let tags = [role, string(in: fields, keys: ["model", "model_name", "model_identifier"]), string(in: fields, keys: ["use_case", "usecase", "feature"])].compactMap { $0 }
        let source = { prettyJSON(dictionary) }

        if let content, role != nil || fields.keys.contains(where: { $0.contains("prompt") }) {
            let raw = source()
            entries.append(makeEntry(scope: .prompts, title: role?.capitalized ?? "Prompt", content: content, role: role, tags: tags, source: raw))
            entries.append(makeEntry(scope: .thread, title: role?.capitalized ?? "Request segment", content: content, role: role, tags: tags, source: raw))
        }
        if let name = string(in: fields, keys: ["name", "tool_name", "function_name"]), fields.keys.contains(where: { $0.contains("tool") || $0.contains("function") }) {
            let raw = source()
            entries.append(makeEntry(scope: .tools, title: name, content: content ?? raw, role: role, tags: tags, source: raw))
        }
        if fields.keys.contains(where: { $0.contains("pcc") || $0.contains("attestation") || $0.contains("cloud_compute") }) {
            let location = path.suffix(2).joined(separator: " › ")
            let raw = source()
            entries.append(makeEntry(scope: .pcc, title: "PCC \(location.isEmpty ? "record" : location)", content: content ?? raw, role: role, tags: tags, source: raw))
        }
    }

    private static func makeEntry(scope: ReportScope, title: String, content: String, role: String?, tags: [String], source: Any) -> ReportEntry {
        let boundedContent = truncate(content, to: maximumContentLength)
        let rawJSON = truncate(source as? String ?? prettyJSON(source), to: maximumSourceLength)
        return ReportEntry(scope: scope, title: title, preview: String(boundedContent.prefix(220)), content: boundedContent, role: role?.lowercased(), tags: tags, rawJSON: rawJSON, searchIndex: "\(title) \(boundedContent.prefix(maximumSearchLength)) \(tags.joined(separator: " "))".lowercased())
    }

    private static func string(in dictionary: [String: Any], keys: [String]) -> String? {
        keys.compactMap { key -> String? in
            guard let value = dictionary[key] else { return nil }
            return (value as? String) ?? (value as? CustomStringConvertible)?.description
        }.first
    }

    private static func prettyJSON(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]), let output = String(data: data, encoding: .utf8) else { return String(describing: value) }
        return output
    }

    private static func decodeBase64(_ string: String) -> String? {
        guard string.count >= 40, string.count.isMultiple(of: 4), string.utf8.allSatisfy({ ($0 >= 65 && $0 <= 90) || ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) || $0 == 43 || $0 == 47 || $0 == 61 }), let data = Data(base64Encoded: string), let decoded = String(data: data, encoding: .utf8) else { return nil }
        let readable = decoded.unicodeScalars.filter { $0.properties.isWhitespace || ($0.value >= 32 && $0.value <= 126) }.count
        return Double(readable) / Double(max(decoded.unicodeScalars.count, 1)) > 0.85 ? decoded : nil
    }

    private static func truncate(_ string: String, to limit: Int) -> String {
        guard string.utf8.count > limit else { return string }
        return "\(String(string.prefix(limit)))\n\n… truncated to keep AIR Viewer responsive …"
    }

    private static func deduplicate(_ entries: [ReportEntry]) -> [ReportEntry] {
        var seen = Set<String>()
        return entries.filter {
            seen.insert("\($0.scope.rawValue)|\($0.title)|\($0.content.utf8.count)|\($0.content.prefix(512))").inserted
        }
    }
}
