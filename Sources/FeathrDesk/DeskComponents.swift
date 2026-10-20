import AppKit
import SwiftUI

struct DeskField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var onSubmit: (() -> Void)? = nil

    init(_ placeholder: String, text: Binding<String>, icon: String? = nil, onSubmit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: 7) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .rounded))
                .onSubmit { onSubmit?() }
            if icon != nil, !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DeskTheme.line))
    }
}

struct PaneIntro: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: 620, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct QuietNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.4))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SectionLabel: View {
    let text: String
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.4))
            if let count {
                Text(Human.count(count))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
    }
}

struct RowButton: View {
    let title: String
    let subtitle: String
    var trailing: String = ""
    var symbol: String? = nil
    var dot: SyncHealth.Level? = nil
    var selected: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                if let dot {
                    StatusDot(level: dot)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selected ? DeskTheme.ink.opacity(0.75) : DeskTheme.copper.opacity(0.85))
                        .frame(width: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.isEmpty ? "Untitled" : title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? DeskTheme.ink : .white.opacity(0.92))
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(selected ? DeskTheme.ink.opacity(0.7) : .white.opacity(0.42))
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                if !trailing.isEmpty {
                    Text(trailing)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? DeskTheme.ink : DeskTheme.copperHighlight)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selected ? DeskTheme.copper : Color.white.opacity(hovering ? 0.075 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var note: String = ""
    var symbol: String? = nil
    var loading: Bool = false
    var action: (() -> Void)? = nil
    @State private var hovering = false

    var body: some View {
        Button { action?() } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DeskTheme.copper.opacity(0.9))
                    }
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.4))
                }
                if loading {
                    SkeletonBar(width: 56, height: 22)
                } else {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Text(note.isEmpty ? " " : note)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering && action != nil ? DeskTheme.raised : DeskTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DeskTheme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .onHover { hovering = $0 }
    }
}

struct DeskCard<Content: View>: View {
    var maxWidth: CGFloat = 640
    var accent: Color? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(14)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .background(DeskTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent?.opacity(0.45) ?? DeskTheme.line))
    }
}

struct StatusDot: View {
    let level: SyncHealth.Level
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .background(Circle().fill(color.opacity(0.25)).frame(width: size + 6, height: size + 6))
    }

    private var color: Color {
        switch level {
        case .good: return DeskTheme.good
        case .warning: return DeskTheme.warn
        case .problem: return DeskTheme.problem
        case .none: return .white.opacity(0.3)
        }
    }
}

struct FilterChip: View {
    let title: String
    let count: Int?
    let selected: Bool
    var symbol: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
                if let count {
                    Text(Human.count(count))
                        .monospacedDigit()
                        .foregroundStyle(selected ? DeskTheme.ink.opacity(0.6) : .white.opacity(0.4))
                }
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(selected ? DeskTheme.ink : .white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selected ? DeskTheme.copper : Color.white.opacity(hovering ? 0.11 : 0.07))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
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
        .overlay(Capsule().stroke(DeskTheme.line))
    }
}

struct LabeledValue: View {
    let label: String
    let value: String
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(mono ? .system(size: 11, design: .monospaced) : .system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Calm placeholder for a list with nothing to show yet.
struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DeskTheme.copper)
                .frame(width: 38, height: 38)
                .background(Circle().fill(DeskTheme.copper.opacity(0.12)))
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    QuietButton(title: actionTitle, action: action)
                        .padding(.top, 4)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: 520, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.025)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DeskTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 10
    @State private var dim = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2.5)
            .fill(Color.white.opacity(dim ? 0.05 : 0.1))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

/// Row-shaped placeholders while the first page loads, so the layout does not jump.
struct SkeletonRows: View {
    var count = 6

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBar(width: CGFloat(150 + (index * 37) % 110), height: 10)
                        SkeletonBar(width: CGFloat(90 + (index * 53) % 140), height: 8)
                    }
                    Spacer()
                    SkeletonBar(width: 44, height: 10)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .accessibilityLabel("Loading")
    }
}

/// Thin copper line under the top bar while Feathr is working, instead of spinners in every pane.
struct ProgressLine: View {
    let active: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            Rectangle()
                .fill(LinearGradient(colors: [DeskTheme.copper.opacity(0), DeskTheme.copperHighlight, DeskTheme.copper.opacity(0)], startPoint: .leading, endPoint: .trailing))
                .frame(width: width * 0.35)
                .offset(x: -width * 0.35 + phase * width * 1.35)
                .opacity(active ? 1 : 0)
        }
        .frame(height: 2)
        .clipped()
        .animation(.easeOut(duration: 0.25), value: active)
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1 }
        }
        .allowsHitTesting(false)
    }
}

struct Banner: View {
    enum Tone { case info, warning, problem }

    let tone: Tone
    let text: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.85))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Dismiss (Esc)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var color: Color {
        switch tone {
        case .info: return DeskTheme.copperHighlight
        case .warning: return DeskTheme.warn
        case .problem: return DeskTheme.problem
        }
    }

    private var symbol: String {
        switch tone {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .problem: return "exclamationmark.octagon.fill"
        }
    }
}

struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.1)))
    }
}

struct Avatar: View {
    let person: [String: Any]
    var size: CGFloat = 40

    var body: some View {
        Text(Human.initials(person))
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(DeskTheme.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(LinearGradient(colors: [DeskTheme.copperHighlight, DeskTheme.copper], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
}

struct CopyButton: View {
    let text: String
    var label: String = "Copy"
    @State private var copied = false

    var body: some View {
        Button {
            Clipboard.copy(text)
            copied = true
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(copied ? DeskTheme.good : .white.opacity(0.45))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(copied ? "Copied" : label)
        .disabled(text.isEmpty)
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

    static func stateLevel(_ raw: String) -> SyncHealth.Level {
        switch raw {
        case "published": return .good
        case "paused": return .warning
        case "stopped": return .problem
        default: return .none
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

    static func isSalesforce(_ hook: [String: Any]) -> Bool {
        JSON.string(hook["target_url"]).localizedCaseInsensitiveContains("salesforce")
            || JSON.string(hook["name"]).localizedCaseInsensitiveContains("salesforce")
    }

    static func hookTitle(_ hook: [String: Any]) -> String {
        isSalesforce(hook) ? "Salesforce sync" : JSON.string(hook["name"]).ifEmpty("Webhook sync")
    }

    static func destination(_ hook: [String: Any]) -> String {
        if isSalesforce(hook) { return "Salesforce" }
        return URL(string: JSON.string(hook["target_url"]))?.host ?? "the website"
    }

    /// Feathr's delivery error in plain words. The raw text always stays available.
    static func hookProblem(_ raw: String) -> (summary: String, raw: String)? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        func has(_ needle: String) -> Bool { text.localizedCaseInsensitiveContains(needle) }
        let code = text.range(of: #"\b[45]\d\d\b"#, options: .regularExpression).map { String(text[$0]) }
        let summary: String
        if code == "401" || code == "403" || has("unauthorized") || has("forbidden") {
            summary = "The receiving side refused Feathr's delivery, usually a credentials problem."
        } else if code == "404" || has("not found") {
            summary = "The address Feathr sends to was not found."
        } else if code == "429" {
            summary = "The receiving side asked Feathr to slow down."
        } else if code?.hasPrefix("5") == true || has("internal server error") || has("bad gateway") || has("service unavailable") {
            summary = "The receiving side had a problem of its own."
        } else if has("ssl") || has("certificate") || has("tls") {
            summary = "The secure connection to the receiving side failed."
        } else if has("name resolution") || has("getaddrinfo") || has("nodename") || has("dns") {
            summary = "Feathr could not look up the receiving address."
        } else if has("refused") {
            summary = "The receiving side refused the connection."
        } else if has("timeout") || has("timed out") {
            summary = "The receiving side took too long to answer Feathr."
        } else if has("connect") {
            summary = "Feathr could not connect to the receiving side."
        } else {
            summary = text
        }
        return (summary, FeathrAPI.scrub(text))
    }

    static func hookError(_ raw: String) -> String {
        hookProblem(raw)?.summary ?? ""
    }

    static func personTitle(_ row: [String: Any]) -> String {
        JSON.personName(row).ifEmpty(JSON.string(row["email"]))
    }

    static func successRate(_ hook: [String: Any]) -> String {
        guard let pct = successPercent(hook) else { return "" }
        return String(format: "%.0f%% delivered", pct)
    }

    static func successPercent(_ hook: [String: Any]) -> Double? {
        let ok = JSON.int(hook["num_success"])
        let bad = JSON.int(hook["num_failure"])
        guard ok + bad > 0 else { return nil }
        return Double(ok) / Double(ok + bad) * 100
    }

    /// Gift amount exactly as Feathr sent it. Empty when the breadcrumb has none.
    static func amount(_ crumb: [String: Any]) -> String {
        let data = JSON.object(crumb["data"])
        let keys = ["amount", "donation_amount", "gift_amount"]
        let raw = firstDisplay(crumb, keys: keys).ifEmpty(firstDisplay(data, keys: keys))
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
    /// Focuses the field when Desk requests this section (⌘F, palette, quick actions).
    func searchFocus(_ model: DeskModel, _ section: DeskSection, _ focused: FocusState<Bool>.Binding) -> some View {
        let take = {
            guard model.focusRequest == section else { return }
            DispatchQueue.main.async {
                focused.wrappedValue = true
                model.focusRequest = nil
            }
        }
        return onAppear { take() }
            .onChange(of: model.focusRequest) { _, _ in take() }
    }
}
