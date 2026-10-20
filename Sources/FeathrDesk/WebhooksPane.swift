import SwiftUI

struct WebhooksPane: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneIntro(text: "This is the link that sends new and updated people to Salesforce. The signing secret stays hidden.")
            if model.webhooks.isEmpty {
                QuietNote(text: model.connected ? "No webhooks on this account." : "Connect a key to see sync.")
            }
            if !model.webhooks.isEmpty && !model.canWriteHooks {
                QuietNote(text: "This key can read sync status but cannot pause or restart it. Do that in Feathr.")
            }
            ForEach(model.webhooks, id: \.selfID) { hook in
                HookCard(model: model, hook: hook)
            }
        }
    }
}

private struct HookCard: View {
    @ObservedObject var model: DeskModel
    let hook: [String: Any]

    private var active: Bool { JSON.bool(hook["is_active"]) == true }
    private var streak: Int { JSON.int(hook["consecutive_failures"]) }
    private var level: SyncHealth.Level { !active ? .problem : (streak > 0 ? .warning : .good) }

    var body: some View {
        DeskCard {
            HStack {
                StatusDot(level: level)
                Text(JSON.string(hook["name"]).ifEmpty("Webhook"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text(active ? (streak > 0 ? "Running, failing" : "Running") : "Paused")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text(JSON.string(hook["target_url"]))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .textSelection(.enabled)
            Text(Plain.hookEvents(hook))
                .font(.system(size: 12))
                .foregroundStyle(DeskTheme.copper)
            let rate = Plain.successRate(hook)
            Text("\(JSON.int(hook["num_success"])) delivered · \(JSON.int(hook["num_failure"])) failed · \(streak) in a row recently\(rate.isEmpty ? "" : " · \(rate)")")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
            let last = JSON.string(hook["last_delivery_at"])
            if !last.isEmpty {
                Text("Last attempt \(JSON.relative(last)) (\(JSON.shortDate(last)))")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            let problem = Plain.hookError(JSON.string(hook["last_error"]))
            if !problem.isEmpty {
                Text("Last problem: \(problem)")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .textSelection(.enabled)
            }
            if model.canWriteHooks {
                HStack {
                    if active {
                        QuietButton(title: "Pause") { model.setWebhookActive(hook, active: false) }
                    } else {
                        QuietButton(title: "Turn on") { model.setWebhookActive(hook, active: true) }
                    }
                }
            }
        }
        .onTapGesture { model.select(hook) }
    }
}
