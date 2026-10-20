import SwiftUI

struct WebhooksPane: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaneIntro(text: "The links that send new and updated people out of Feathr, usually to Salesforce. Signing secrets stay hidden.")
            if !model.connected && model.webhooks.isEmpty {
                SkeletonRows(count: 2).frame(maxWidth: 680)
            } else if model.webhooks.isEmpty {
                EmptyState(
                    symbol: "arrow.left.arrow.right",
                    title: "No sync links on this account",
                    message: "Feathr has no webhook set up, so people are not sent to Salesforce automatically. Webhooks are created in Feathr."
                )
            } else {
                summary
                if !model.canWriteHooks {
                    Banner(tone: .info, text: "This key can read sync status but cannot pause or restart it. Ask a Feathr admin for webhooks:write, or do it in Feathr.")
                        .frame(maxWidth: 680)
                }
                ForEach(model.webhooks, id: \.selfID) { hook in
                    HookCard(model: model, hook: hook)
                        .id(hook.selfID)
                }
            }
        }
    }

    private var summary: some View {
        let levels = model.webhooks.map { SyncHealth.of($0).level }
        let running = levels.filter { $0 == .good }.count
        let failing = levels.filter { $0 == .warning }.count
        let paused = levels.filter { $0 == .problem }.count
        return HStack(spacing: 16) {
            summaryItem(running, "running", .good)
            summaryItem(failing, "failing", .warning)
            summaryItem(paused, "paused", .problem)
            Spacer()
            if let last = model.lastRefresh {
                Text("Checked \(Human.relative(last))")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: 680)
    }

    private func summaryItem(_ count: Int, _ label: String, _ level: SyncHealth.Level) -> some View {
        HStack(spacing: 6) {
            StatusDot(level: count > 0 ? level : .none, size: 6)
            Text("\(count) \(label)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(count > 0 ? 0.8 : 0.35))
        }
    }
}

private struct HookCard: View {
    @ObservedObject var model: DeskModel
    let hook: [String: Any]
    @State private var showRaw = false

    private var health: SyncHealth { SyncHealth.of(hook) }
    private var active: Bool { JSON.bool(hook["is_active"]) == true }
    private var streak: Int { JSON.int(hook["consecutive_failures"]) }
    private var selected: Bool { hook.selfID == model.selected.selfID }

    var body: some View {
        DeskCard(maxWidth: 680, accent: selected ? DeskTheme.copper : accent) {
            HStack(spacing: 10) {
                StatusDot(level: health.level, size: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(health.headline)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(JSON.string(hook["name"]).ifEmpty("Webhook"))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                statePill
            }
            Text(health.detail)
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                metric(Human.count(JSON.int(hook["num_success"])), "Delivered", nil)
                metric(Human.count(JSON.int(hook["num_failure"])), "Failed", nil)
                metric(Plain.successPercent(hook).map { String(format: "%.0f%%", $0) } ?? "—", "Success rate", nil)
                metric(Human.count(streak), "Failures in a row", streak > 0 ? DeskTheme.warn : nil)
            }
            .padding(.vertical, 4)

            if streak > 0 { streakStrip }

            VStack(alignment: .leading, spacing: 6) {
                line("clock", lastAttempt)
                line("paperplane", "Sends \(Plain.hookEvents(hook).lowercased().ifEmpty("people")) to \(Plain.destination(hook))")
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 14)
                    Text(JSON.string(hook["target_url"]))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    CopyButton(text: JSON.string(hook["target_url"]), label: "Copy address")
                }
            }

            if let problem = Plain.hookProblem(JSON.string(hook["last_error"])) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.bubble")
                            .foregroundStyle(DeskTheme.warn)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last problem")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                            Text(problem.summary)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if problem.raw != problem.summary {
                        DisclosureGroup(isExpanded: $showRaw) {
                            Text(problem.raw)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        } label: {
                            Text("Feathr’s exact words")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .tint(DeskTheme.copper)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(DeskTheme.warn.opacity(0.07)))
            }

            if model.canWriteHooks {
                HStack(spacing: 8) {
                    if active {
                        QuietButton(title: "Pause sync…", systemImage: "pause.fill") { model.setWebhookActive(hook, active: false) }
                    } else {
                        CopperButton(title: "Turn sync back on…", systemImage: "play.fill") { model.setWebhookActive(hook, active: true) }
                    }
                    Text("Desk asks before changing anything.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.32))
                }
                .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.select(hook) }
    }

    private var accent: Color? {
        switch health.level {
        case .problem: return DeskTheme.problem
        case .warning: return DeskTheme.warn
        default: return nil
        }
    }

    private var lastAttempt: String {
        let last = JSON.string(hook["last_delivery_at"])
        guard !last.isEmpty else { return "No delivery attempts recorded yet" }
        return "Last attempt \(Human.relative(last)), \(Human.dateTime(last))"
    }

    private var statePill: some View {
        let text = !active ? "Paused" : (streak > 0 ? "Running · failing" : "Running")
        let color: Color = !active ? DeskTheme.problem : (streak > 0 ? DeskTheme.warn : DeskTheme.good)
        return Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    /// One pip per failed delivery in the current streak, as Feathr counts it.
    private var streakStrip: some View {
        let shown = min(streak, 24)
        return HStack(spacing: 3) {
            ForEach(0..<shown, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DeskTheme.warn.opacity(0.85))
                    .frame(width: 7, height: 14)
            }
            if streak > shown {
                Text("+\(streak - shown)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(DeskTheme.warn)
            }
            Text(streak == 1 ? "1 failed delivery since the last success" : "\(Human.count(streak)) failed deliveries since the last success")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 6)
        }
    }

    private func metric(_ value: String, _ label: String, _ tint: Color?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint ?? .white)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.035)))
    }

    private func line(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 14)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
