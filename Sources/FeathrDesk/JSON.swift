import Foundation

enum JSON {
    static func object(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }

    static func array(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }

    static func string(_ value: Any?) -> String {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        default: return ""
        }
    }

    static func bool(_ value: Any?) -> Bool? {
        (value as? NSNumber)?.boolValue ?? value as? Bool
    }

    static func int(_ value: Any?) -> Int {
        (value as? NSNumber)?.intValue ?? 0
    }

    static func strings(_ value: Any?) -> [String] {
        if let list = value as? [String] { return list }
        if let list = value as? [Any] { return list.map { string($0) }.filter { !$0.isEmpty } }
        return []
    }

    static func pretty(_ value: Any?) -> String {
        guard let value, JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: redact(value), options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return String(describing: value ?? "—")
        }
        return text
    }

    static func redact(_ value: Any) -> Any {
        if var dict = value as? [String: Any] {
            for key in dict.keys where key.lowercased().contains("secret") || key == "Authorization" {
                dict[key] = "hidden"
            }
            for (key, nested) in dict {
                dict[key] = redact(nested)
            }
            return dict
        }
        if let list = value as? [Any] {
            return list.map { redact($0) }
        }
        return value
    }

    static func shortDate(_ iso: String) -> String {
        guard !iso.isEmpty else { return "—" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return String(iso.prefix(16)).replacingOccurrences(of: "T", with: " ") }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
