import AppKit
import SwiftUI

struct DeskField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)? = nil

    init(_ placeholder: String, text: Binding<String>, onSubmit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.onSubmit = onSubmit
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onSubmit { onSubmit?() }
    }
}

struct PaneIntro: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: 620, alignment: .leading)
    }
}

struct QuietNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.4))
    }
}

struct RowButton: View {
    let title: String
    let subtitle: String
    var trailing: String = ""
    var selected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.isEmpty ? "Untitled" : title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? DeskTheme.ink : .white.opacity(0.92))
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(selected ? DeskTheme.ink.opacity(0.7) : .white.opacity(0.4))
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if !trailing.isEmpty {
                    Text(trailing)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? DeskTheme.ink : DeskTheme.copperHighlight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selected ? DeskTheme.copper : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var note: String = ""
    var action: (() -> Void)? = nil

    var body: some View {
        Button { action?() } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.4))
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DeskTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct DeskCard<Content: View>: View {
    var maxWidth: CGFloat = 640
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(14)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .background(DeskTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusDot: View {
    let level: SyncHealth.Level
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private var color: Color {
        switch level {
        case .good: return .green
        case .warning: return DeskTheme.copperHighlight
        case .problem: return DeskTheme.copper
        case .none: return .white.opacity(0.3)
        }
    }
}

struct FilterChip: View {
    let title: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                Text("\(count)")
                    .foregroundStyle(selected ? DeskTheme.ink.opacity(0.6) : .white.opacity(0.4))
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(selected ? DeskTheme.ink : .white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selected ? DeskTheme.copper : Color.white.opacity(0.07))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Wraps children onto new lines when they run out of width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

struct TagChip: View {
    let name: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Remove \(name) from this person")
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
}

struct LabeledValue: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .textSelection(.enabled)
        }
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// Plain operator wording for Feathr's raw values.
enum Plain {
    static func state(_ raw: String) -> String {
        switch raw {
        case "published": return "Sending"
        case "draft": return "Draft"
        case "stopped": return "Stopped"
        case "paused": return "Paused"
        case "": return "No status"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func kind(_ raw: String) -> String {
        switch raw {
        case "email": return "Email"
        case "auto_send", "autosend": return "Auto send"
        case "": return "No type"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func hookEvents(_ hook: [String: Any]) -> String {
        JSON.strings(hook["events"]).map { event in
            switch event {
            case "person.created": return "New people"
            case "person.updated": return "Updated people"
            default: return event.replacingOccurrences(of: ".", with: " ")
            }
        }.joined(separator: " and ")
    }

    static func hookError(_ raw: String) -> String {
        if raw.isEmpty { return "" }
        if raw.localizedCaseInsensitiveContains("connect") {
            return "Feathr could not connect to the website."
        }
        if raw.localizedCaseInsensitiveContains("timeout") || raw.localizedCaseInsensitiveContains("timed out") {
            return "The website took too long to answer Feathr."
        }
        return raw
    }

    static func personTitle(_ row: [String: Any]) -> String {
        JSON.personName(row).ifEmpty(JSON.string(row["email"]))
    }

    static func successRate(_ hook: [String: Any]) -> String {
        let ok = JSON.int(hook["num_success"])
        let bad = JSON.int(hook["num_failure"])
        guard ok + bad > 0 else { return "" }
        let pct = Double(ok) / Double(ok + bad) * 100
        return String(format: "%.0f%% delivered", pct)
    }

    /// Gift amount exactly as Feathr sent it. Empty when the breadcrumb has none.
    static func amount(_ crumb: [String: Any]) -> String {
        let data = JSON.object(crumb["data"])
        let raw = firstDisplay(crumb, keys: ["amount", "donation_amount", "value", "gift_amount"])
            .ifEmpty(firstDisplay(data, keys: ["amount", "donation_amount", "value", "gift_amount"]))
        guard !raw.isEmpty else { return "" }
        let currency = JSON.display(crumb["currency"]).ifEmpty(JSON.display(data["currency"]))
        return currency.isEmpty ? raw : "\(raw) \(currency.uppercased())"
    }

    static func campaignLabel(_ crumb: [String: Any], resolve: (String) -> String) -> String {
        let data = JSON.object(crumb["data"])
        let named = firstDisplay(crumb, keys: ["campaign_name", "campaign"])
            .ifEmpty(firstDisplay(data, keys: ["campaign_name", "campaign"]))
        if !named.isEmpty { return named }
        let id = JSON.string(crumb["campaign_id"]).ifEmpty(JSON.string(data["campaign_id"]))
        return resolve(id)
    }

    private static func firstDisplay(_ row: [String: Any], keys: [String]) -> String {
        for key in keys {
            let text = JSON.display(row[key])
            if !text.isEmpty { return text }
        }
        return ""
    }
}

extension View {
    /// Focuses the field when Desk requests this section (⌘F / quick actions).
    func searchFocus(_ model: DeskModel, _ section: DeskSection, _ focused: FocusState<Bool>.Binding) -> some View {
        onChange(of: model.focusRequest) { _, request in
            guard request == section else { return }
            focused.wrappedValue = true
            model.focusRequest = nil
        }
    }
}

