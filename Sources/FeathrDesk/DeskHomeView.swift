import SwiftUI

struct DeskHomeView: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            switch model.phase {
            case .noKey:
                EmptyState(
                    symbol: "key",
                    title: "Connect Mid-Fairfield’s Feathr account",
                    message: "Paste an API key from Feathr settings. Desk keeps it in this Mac’s Keychain and only talks to Feathr.",
                    actionTitle: "Add Feathr key"
                ) { model.showKeySheet = true }
            case .keyRejected where !model.connected:
                EmptyState(
                    symbol: "key.slash",
                    title: "Feathr did not accept the key",
                    message: "It may have been revoked or rotated. Paste a fresh key from Feathr settings and Desk will reconnect.",
                    actionTitle: "Replace key"
                ) { model.showKeySheet = true }
            case .unreachable where !model.connected:
                EmptyState(
                    symbol: "wifi.exclamationmark",
                    title: "Feathr did not answer",
                    message: "Check the internet connection. Nothing was changed, and Desk will pick up where it left off.",
                    actionTitle: "Try again"
                ) { Task { await model.refreshAll() } }
            default:
                pulse
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        syncCard.frame(width: 320)
                        nextActions.frame(minWidth: 260, idealWidth: 300, maxWidth: .infinity)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        syncCard
                        nextActions
                    }
                }
                recentGifts
                if model.connected { access }
            }
        }
    }

    private var loading: Bool { !model.connected }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Human.greeting()).")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                StatusDot(level: model.connected ? .good : (model.phase == .keyRejected ? .problem : .none), size: 7)
                Text(statusLine)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var statusLine: String {
        guard model.connected else { return model.status }
        var parts = ["Connected to \(model.serviceName)"]
        if let last = model.lastRefresh { parts.append("refreshed \(Human.relative(last))") }
        return parts.joined(separator: " · ")
    }

    // MARK: Pulse

    private var pulse: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 122), spacing: 10)], spacing: 10) {
            StatTile(
                label: "Gifts",
                value: model.giftTotal.map(Human.count) ?? (model.recentGifts.isEmpty ? "—" : "Recent"),
                note: model.latestGiftDate.map { "Latest \(Human.relative($0))" } ?? "",
                symbol: "gift",
                loading: loading
            ) { model.showActivity(flavor: ActivityKind.donation.flavor) }
            StatTile(
                label: "People",
                value: model.peopleOnAccount.map(Human.count) ?? "Search",
                note: "Look up by email",
                symbol: "person",
                loading: loading
            ) { model.requestFocus(.people) }
            StatTile(
                label: "Campaigns",
                value: Human.count(model.campaigns.count),
                note: sendingNote,
                symbol: "envelope",
                loading: loading
            ) { model.go(.campaigns) }
            StatTile(label: "Tags", value: Human.count(model.tags.count), note: "A to Z", symbol: "tag", loading: loading) { model.go(.tags) }
            StatTile(label: "Projects", value: Human.count(model.projects.count), note: "Sites and events", symbol: "folder", loading: loading) { model.go(.projects) }
        }
    }

    private var sendingNote: String {
        let n = model.campaignCount(state: "published")
        return n == 0 ? "None sending" : "\(Human.count(n)) sending"
    }

    // MARK: Sync

    private var syncCard: some View {
        let health = model.syncHealth
        return DeskCard(maxWidth: .infinity, accent: health.level == .problem ? DeskTheme.problem : (health.level == .warning ? DeskTheme.warn : nil)) {
            SectionLabel(text: "Sync")
            HStack(spacing: 8) {
                StatusDot(level: health.level)
                Text(health.headline)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            if loading {
                SkeletonBar(height: 9)
                SkeletonBar(width: 180, height: 9)
            } else {
                Text(health.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let hook = health.hook {
                HStack(spacing: 14) {
                    miniMetric(Human.count(JSON.int(hook["num_success"])), "delivered")
                    miniMetric(Human.count(JSON.int(hook["num_failure"])), "failed")
                    if let pct = Plain.successPercent(hook) {
                        miniMetric(String(format: "%.0f%%", pct), "success")
                    }
                }
                .padding(.top, 2)
            }
            HStack(spacing: 8) {
                QuietButton(title: "Open sync", systemImage: "arrow.left.arrow.right") {
                    model.go(.webhooks)
                    if let hook = health.hook { model.select(hook) }
                }
                if let hook = health.hook, model.canWriteHooks {
                    if JSON.bool(hook["is_active"]) == true {
                        QuietButton(title: "Pause…", systemImage: "pause") { model.setWebhookActive(hook, active: false) }
                    } else {
                        QuietButton(title: "Turn on…", systemImage: "play") { model.setWebhookActive(hook, active: true) }
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func miniMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: Next actions

    private var nextActions: some View {
        let actions = model.nextActions
        return DeskCard(maxWidth: .infinity) {
            SectionLabel(text: "Worth a look")
            if loading {
                SkeletonBar(height: 9)
                SkeletonBar(width: 160, height: 9)
            } else if actions.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(DeskTheme.good)
                    Text("Nothing needs you right now.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text(model.syncHealth.level == .good ? "Sync is healthy and every list loaded." : "Every list loaded.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(actions) { action in
                        NextActionRow(action: action)
                    }
                }
            }
        }
    }

    // MARK: Recent gifts

    @ViewBuilder
    private var recentGifts: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Recent gifts")
                Spacer()
                if !model.recentGifts.isEmpty {
                    Button("See all gifts") { model.showActivity(flavor: ActivityKind.donation.flavor) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DeskTheme.copper)
                }
            }
            if loading {
                SkeletonRows(count: 3)
            } else if model.recentGifts.isEmpty {
                QuietNote(text: "No gifts on record in Feathr yet.")
            } else {
                ForEach(model.recentGifts, id: \.selfID) { gift in
                    RowButton(
                        title: JSON.string(gift["email"]).ifEmpty("Unknown email"),
                        subtitle: giftSubtitle(gift),
                        trailing: Plain.amount(gift),
                        symbol: "gift",
                        selected: !gift.selfID.isEmpty && gift.selfID == model.selected.selfID
                    ) {
                        model.select(gift)
                    }
                    .id(gift.selfID)
                    .contextMenu {
                        Button("Open person") { Task { await model.openPerson(from: gift) } }
                        if !JSON.string(gift["person_id"]).isEmpty {
                            Button("All their gifts") { model.personActivity(from: gift) }
                        }
                        let email = JSON.string(gift["email"])
                        if !email.isEmpty { Button("Copy email") { Clipboard.copy(email) } }
                    }
                }
                QuietNote(text: "Click a gift to see it in the details rail. Return opens the person.")
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
    }

    private func giftSubtitle(_ gift: [String: Any]) -> String {
        let created = JSON.string(gift["created_at"])
        var parts = [Human.relative(created).ifEmpty(JSON.shortDate(created))]
        let campaign = Plain.campaignLabel(gift) { model.campaignName($0) }
        if !campaign.isEmpty { parts.append(campaign) }
        let project = model.projectName(JSON.string(gift["project_id"]))
        if project != "—" { parts.append(project) }
        return parts.joined(separator: " · ")
    }

    // MARK: Access

    private var access: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "What this key can change")
            HStack(spacing: 8) {
                accessPill("People", model.canWritePeople)
                accessPill("Tags", model.canWriteTags)
                accessPill("Sync", model.canWriteHooks)
            }
            QuietNote(text: "Campaigns, sends, and projects are always changed in Feathr. Every change made here asks first.")
        }
        .padding(.top, 4)
    }

    private func accessPill(_ area: String, _ can: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: can ? "pencil" : "eye")
                .font(.system(size: 10, weight: .semibold))
            Text("\(area) · \(can ? "can edit" : "read only")")
        }
        .font(.system(size: 11.5, weight: .medium, design: .rounded))
        .foregroundStyle(can ? DeskTheme.copperHighlight : .white.opacity(0.5))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(can ? DeskTheme.copper.opacity(0.12) : Color.white.opacity(0.05)))
    }
}

private struct NextActionRow: View {
    let action: NextAction
    @State private var hovering = false

    var body: some View {
        Button(action: action.run) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: action.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 18)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(action.detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(hovering ? 0.5 : 0.2))
                    .padding(.top, 3)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(hovering ? 0.05 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var color: Color {
        switch action.level {
        case .problem: return DeskTheme.problem
        case .warning: return DeskTheme.warn
        default: return DeskTheme.copper
        }
    }
}
