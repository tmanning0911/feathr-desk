import SwiftUI

struct ActivityPane: View {
    @ObservedObject var model: DeskModel

    private var kindLabel: String { ActivityKind.label(for: model.flavor).lowercased() }
    private var scoped: Bool { !model.activityPersonID.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if scoped { scopeBar }
            FlowLayout {
                ForEach(ActivityKind.allCases) { kind in
                    FilterChip(title: kind.label, count: model.flavorCounts[kind.flavor], selected: model.flavor == kind.flavor, symbol: kind.symbol) {
                        model.setFlavor(kind.flavor)
                    }
                }
            }
            HStack {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button {
                    model.loadActivity(forceCounts: true)
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .disabled(model.activityLoading)
                .help("Reload this list")
            }

            content

            if model.flavor == ActivityKind.donation.flavor, !model.crumbs.isEmpty, !model.crumbs.contains(where: { !Plain.amount($0).isEmpty }) {
                QuietNote(text: "Feathr does not include gift amounts on these records yet. Amounts stay in the CSV export, and Desk will show them as soon as Feathr sends them.")
                    .frame(maxWidth: 620, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.crumbs.isEmpty && (model.activityLoading || !model.activityLoadedOnce) && model.activityError == nil {
            SkeletonRows(count: 8)
        } else if let error = model.activityError, model.crumbs.isEmpty {
            EmptyState(symbol: "exclamationmark.triangle", title: "Activity did not load", message: error, actionTitle: "Try again") {
                model.loadActivity(forceCounts: true)
            }
        } else if model.crumbs.isEmpty {
            EmptyState(symbol: ActivityKind.symbol(for: model.flavor), title: "No \(kindLabel) yet", message: emptyMessage)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(days, id: \.key) { day in
                    HStack(spacing: 8) {
                        Text(day.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(Human.count(day.rows.count))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                        Rectangle().fill(DeskTheme.line).frame(height: 1)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                    ForEach(day.rows, id: \.selfID) { crumb in
                        ActivityRow(model: model, crumb: crumb)
                            .id(crumb.selfID)
                    }
                }
            }
            footer
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let error = model.loadMoreError {
            Banner(tone: .warning, text: "The next page did not load. \(error)", actionTitle: "Try again", action: {
                model.loadMoreActivity()
            })
            .frame(maxWidth: 620)
        } else if model.canLoadMoreActivity {
            HStack(spacing: 10) {
                QuietButton(title: model.loadingMore ? "Loading…" : loadMoreTitle, systemImage: "arrow.down", enabled: !model.loadingMore) {
                    model.loadMoreActivity()
                }
                QuietNote(text: "↓ past the last row loads more too.")
            }
            .padding(.top, 6)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                Text("That is everything Feathr has for this view.")
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.35))
            .padding(.top, 6)
        }
    }

    private var scopeBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .foregroundStyle(DeskTheme.copper)
            Text("Only \(model.activityPersonLabel)")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            Spacer()
            Button("Open person") {
                Task { await model.openPerson(from: ["person_id": model.activityPersonID]) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DeskTheme.copper)
            Button {
                model.clearActivityPerson()
            } label: {
                Label("Everyone", systemImage: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Show the whole account again")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 9).fill(DeskTheme.copper.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(DeskTheme.copper.opacity(0.3)))
        .frame(maxWidth: 680)
    }

    private var loadMoreTitle: String {
        if let total = model.crumbTotal {
            return "Load \(min(DeskModel.activityPageSize, max(total - model.crumbs.count, 0))) more"
        }
        return "Load more"
    }

    private var caption: String {
        if model.crumbs.isEmpty && model.activityLoading { return "Loading \(kindLabel)…" }
        if model.crumbs.isEmpty { return " " }
        let scope = scoped ? "for \(model.activityPersonLabel)" : "on the account"
        if let total = model.crumbTotal {
            return "Showing \(Human.count(model.crumbs.count)) of \(Human.count(total)) \(kindLabel) \(scope). Newest first."
        }
        return "Showing \(Human.count(model.crumbs.count)) \(kindLabel) \(scope). Newest first."
    }

    private var emptyMessage: String {
        if scoped {
            return "Feathr has no \(kindLabel) on record for \(model.activityPersonLabel). Try another kind above, or show everyone."
        }
        switch model.flavor {
        case ActivityKind.donation.flavor:
            return "Feathr has no donation activity on this account yet. Gifts appear here as Feathr records them."
        default:
            return "Feathr has no \(kindLabel) on this account yet."
        }
    }

    private var days: [(key: String, title: String, rows: [[String: Any]])] {
        var result: [(key: String, title: String, rows: [[String: Any]])] = []
        let calendar = Calendar.current
        for crumb in model.crumbs {
            let date = JSON.date(JSON.string(crumb["created_at"]))
            let key = date.map { String(calendar.startOfDay(for: $0).timeIntervalSince1970) } ?? "undated"
            if let last = result.last, last.key == key {
                result[result.count - 1].rows.append(crumb)
            } else {
                result.append((key, date.map(Human.dayHeader) ?? "Date not recorded", [crumb]))
            }
        }
        return result
    }
}

private struct ActivityRow: View {
    @ObservedObject var model: DeskModel
    let crumb: [String: Any]
    @State private var hovering = false

    private var selected: Bool {
        let id = JSON.string(crumb["id"])
        return !id.isEmpty && id == JSON.string(model.selected["id"])
    }

    var body: some View {
        HStack(spacing: 6) {
            RowButton(
                title: JSON.string(crumb["email"]).ifEmpty("Unknown email"),
                subtitle: subtitle,
                trailing: Plain.amount(crumb),
                symbol: ActivityKind.symbol(for: JSON.string(crumb["flavor"]).ifEmpty(model.flavor)),
                selected: selected
            ) { model.select(crumb) }
            HStack(spacing: 2) {
                rowAction("person.crop.circle", help: "Open this person (Return)") {
                    Task { await model.openPerson(from: crumb) }
                }
                if model.activityPersonID.isEmpty, !JSON.string(crumb["person_id"]).isEmpty {
                    rowAction("line.3.horizontal.decrease.circle", help: "Show only this person's activity") {
                        model.personActivity(from: crumb)
                    }
                }
            }
            .frame(width: 56, alignment: .leading)
            .opacity(hovering || selected ? 1 : 0)
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Open person") { Task { await model.openPerson(from: crumb) } }
            if !JSON.string(crumb["person_id"]).isEmpty {
                Button("Show only this person's activity") { model.personActivity(from: crumb) }
            }
            let email = JSON.string(crumb["email"])
            if !email.isEmpty {
                Button("Copy email") { Clipboard.copy(email) }
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let date = JSON.date(JSON.string(crumb["created_at"])) {
            parts.append(date.formatted(date: .omitted, time: .shortened))
        }
        let kind = JSON.string(crumb["flavor"])
        if !kind.isEmpty, kind != model.flavor { parts.append(ActivityKind.label(for: kind)) }
        let campaign = Plain.campaignLabel(crumb) { model.campaignName($0) }
        if !campaign.isEmpty { parts.append(campaign) }
        let project = JSON.string(crumb["project_id"])
        if !project.isEmpty { parts.append(model.projectName(project)) }
        return parts.joined(separator: " · ")
    }

    private func rowAction(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(DeskTheme.copper)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
