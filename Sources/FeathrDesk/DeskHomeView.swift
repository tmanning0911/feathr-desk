import SwiftUI

struct DeskHomeView: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.status)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: 520, alignment: .leading)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                StatTile(label: "People", value: "Search") { model.go(.people); model.requestFocus(.people) }
                StatTile(label: "Tags", value: "\(model.tags.count)") { model.go(.tags) }
                StatTile(label: "Campaigns", value: "\(model.campaigns.count)", note: sendingNote) { model.go(.campaigns) }
                StatTile(label: "Projects", value: "\(model.projects.count)") { model.go(.projects) }
                StatTile(label: "Gifts", value: model.recentGifts.isEmpty ? "Recent" : "\(model.recentGifts.count)") {
                    model.showActivity(flavor: ActivityKind.donation.flavor)
                }
            }

            syncCard

            if !model.recentGifts.isEmpty {
                recentGifts
            }

            quickActions
        }
    }

    private var subtitle: String {
        if let when = model.lastRefresh {
            return "Look someone up, check a tag, or see recent gifts. Email still sends from Feathr. Last refresh \(when.formatted(date: .omitted, time: .shortened))."
        }
        return "Look someone up, check a tag, or see recent gifts. Email still sends from Feathr."
    }

    private var sendingNote: String {
        let n = model.campaignCount(state: "published")
        return n == 0 ? "" : "\(n) sending"
    }

    private var syncCard: some View {
        let health = model.syncHealth
        return DeskCard(maxWidth: 520) {
            HStack(spacing: 8) {
                StatusDot(level: health.level)
                Text(health.headline)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(health.detail)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
            if let hook = health.hook {
                let rate = Plain.successRate(hook)
                Text("\(JSON.int(hook["num_success"])) delivered · \(JSON.int(hook["num_failure"])) failed\(rate.isEmpty ? "" : " · \(rate)")")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            HStack(spacing: 8) {
                QuietButton(title: "Open sync") { model.go(.webhooks) }
                if let hook = health.hook, model.canWriteHooks {
                    if JSON.bool(hook["is_active"]) == true {
                        QuietButton(title: "Pause") { model.setWebhookActive(hook, active: false) }
                    } else {
                        QuietButton(title: "Turn on") { model.setWebhookActive(hook, active: true) }
                    }
                }
            }
        }
    }

    private var recentGifts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT GIFTS")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.4))
            ForEach(model.recentGifts, id: \.selfID) { gift in
                RowButton(
                    title: JSON.string(gift["email"]).ifEmpty("Unknown email"),
                    subtitle: giftSubtitle(gift),
                    trailing: Plain.amount(gift)
                ) {
                    model.select(gift)
                    model.showActivity(flavor: ActivityKind.donation.flavor)
                }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ACTIONS")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 8) {
                QuietButton(title: "Find a person", systemImage: "person") {
                    model.go(.people)
                    model.requestFocus(.people)
                }
                QuietButton(title: "Recent gifts", systemImage: "gift") {
                    model.showActivity(flavor: ActivityKind.donation.flavor)
                }
                QuietButton(title: "Sending campaigns", systemImage: "envelope") {
                    model.campaignState = "published"
                    model.campaignKind = ""
                    model.go(.campaigns)
                }
            }
        }
    }

    private func giftSubtitle(_ gift: [String: Any]) -> String {
        var parts = [JSON.shortDate(JSON.string(gift["created_at"]))]
        let campaign = model.campaignName(JSON.string(gift["campaign_id"]))
        if !campaign.isEmpty { parts.append(campaign) }
        let project = model.projectName(JSON.string(gift["project_id"]))
        if project != "—" { parts.append(project) }
        return parts.joined(separator: " · ")
    }
}
