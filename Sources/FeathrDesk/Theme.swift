import SwiftUI

enum DeskTheme {
    static let copper = Color(red: 0.86, green: 0.48, blue: 0.22)
    static let copperHighlight = Color(red: 0.98, green: 0.72, blue: 0.42)
    static let ink = Color(red: 0.07, green: 0.06, blue: 0.05)
    static let desk = Color(red: 0.11, green: 0.10, blue: 0.09)
    static let rail = Color(red: 0.08, green: 0.07, blue: 0.065)
    static let paper = Color(red: 0.145, green: 0.13, blue: 0.12)
    static let raised = Color(red: 0.17, green: 0.155, blue: 0.14)
    static let line = Color.white.opacity(0.07)
    static let good = Color(red: 0.49, green: 0.76, blue: 0.56)
    static let warn = Color(red: 0.95, green: 0.69, blue: 0.38)
    static let problem = Color(red: 0.90, green: 0.43, blue: 0.33)
}

struct DeskBadge: View {
    var text: String = "DESK"
    var size: CGFloat = 10

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(DeskTheme.copper)
    }
}

struct CopperButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(DeskTheme.ink.opacity(enabled ? 1 : 0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(enabled ? (hovering ? DeskTheme.copperHighlight : DeskTheme.copper) : DeskTheme.copper.opacity(0.35))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

struct QuietButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(enabled ? 0.85 : 0.35))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(hovering && enabled ? 0.13 : 0.08))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

struct RailLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(.white.opacity(0.4))
    }
}
