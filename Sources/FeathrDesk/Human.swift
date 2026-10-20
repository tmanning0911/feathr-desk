import Foundation

/// Plain wording for dates, counts, and durations.
enum Human {
    static func count(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic))
    }

    static func plural(_ n: Int, _ one: String, _ many: String? = nil) -> String {
        "\(count(n)) \(n == 1 ? one : (many ?? one + "s"))"
    }

    static func seconds(_ n: Int) -> String {
        if n < 60 { return plural(max(n, 1), "second") }
        let minutes = Int((Double(n) / 60).rounded(.up))
        return plural(minutes, "minute")
    }

    static func date(_ iso: String) -> String {
        guard let date = JSON.date(iso) else { return "" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func dateTime(_ iso: String) -> String {
        guard let date = JSON.date(iso) else { return "" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func relative(_ iso: String) -> String {
        guard let date = JSON.date(iso) else { return "" }
        return relative(date)
    }

    static func relative(_ date: Date) -> String {
        if abs(date.timeIntervalSinceNow) < 45 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// "Oct 3, 2026 · 2 weeks ago". Empty when Feathr sent no usable date.
    static func dateLine(_ iso: String) -> String {
        let day = date(iso)
        guard !day.isEmpty else { return "" }
        return "\(day) · \(relative(iso))"
    }

    static func span(from start: Date, to end: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.year, .month, .weekOfMonth, .day]
        return formatter.string(from: start, to: end) ?? ""
    }

    /// One line describing when a campaign runs, using only the dates Feathr sent.
    static func campaignWindow(start: String, end: String) -> String {
        let s = JSON.date(start)
        let e = JSON.date(end)
        let now = Date()
        switch (s, e) {
        case let (s?, e?):
            let length = span(from: s, to: e)
            let range = "\(date(start)) to \(date(end))"
            if e < now { return "Ran \(range)\(length.isEmpty ? "" : ", \(length)")" }
            if s > now { return "Starts \(relative(s)), runs \(range)" }
            return "Running \(range). Ends \(relative(e))"
        case let (s?, nil):
            return s > now ? "Starts \(relative(s)). No end date" : "Started \(relative(s)). No end date"
        case let (nil, e?):
            return e < now ? "Ended \(relative(e))" : "Ends \(relative(e))"
        default:
            return ""
        }
    }

    static func dayHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: Date())
        let style = Date.FormatStyle().weekday(.wide).month(.wide).day()
        return sameYear ? date.formatted(style) : date.formatted(style.year())
    }

    static func greeting(_ now: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    static func initials(_ row: [String: Any]) -> String {
        let first = JSON.string(row["first_name"]).first.map(String.init) ?? ""
        let last = JSON.string(row["last_name"]).first.map(String.init) ?? ""
        let pair = (first + last).uppercased()
        if !pair.isEmpty { return pair }
        return JSON.string(row["email"]).first.map { String($0).uppercased() } ?? "?"
    }
}

/// Small ranked matcher for the command palette.
enum Fuzzy {
    static func score(_ query: String, _ text: String) -> Int? {
        let q = query.lowercased()
        let t = text.lowercased()
        guard !q.isEmpty else { return 1 }
        if t == q { return 1000 }
        if t.hasPrefix(q) { return 800 - min(t.count, 200) }
        if t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { $0.hasPrefix(q) }) { return 600 - min(t.count, 200) }
        if t.contains(q) { return 400 - min(t.count, 200) }
        var index = t.startIndex
        for ch in q {
            guard let found = t[index...].firstIndex(of: ch) else { return nil }
            index = t.index(after: found)
        }
        return 100 - min(t.count, 90)
    }
}
