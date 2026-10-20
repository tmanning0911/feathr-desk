import SwiftUI

struct ActivityPane: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Show", selection: $model.flavor) {
                    ForEach(ActivityKind.allCases) { kind in
                        Text(kind.label).tag(kind.flavor)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
                .onChange(of: model.flavor) { _, _ in
                    model.crumbs = []
                    model.crumbTotal = 0
                    model.scheduleActivityLoad()
                }
                CopperButton(title: "Reload", systemImage: "arrow.clockwise") {
                    Task { await model.loadActivity() }
                }
                if !model.activityPersonID.isEmpty {
                    QuietButton(title: "Everyone", systemImage: "person.2") {
                        model.activityPersonID = ""
                        model.activityPersonLabel = ""
                        Task { await model.loadActivity() }
                    }
                }
            }
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))

            ForEach(model.crumbs, id: \.selfID) { crumb in
                ActivityRow(model: model, crumb: crumb)
            }

            if model.canLoadMoreActivity {
                HStack(spacing: 10) {
                    QuietButton(title: model.loadingMore ? "Loading…" : "Load \(min(DeskModel.activityPageSize, model.crumbTotal - model.crumbs.count)) more", systemImage: "arrow.down") {
                        Task { await model.loadMoreActivity() }
                    }
                    .disabled(model.loadingMore)
                    if model.loadingMore { ProgressView().controlSize(.small) }
                }
                .padding(.top, 4)
            } else if !model.crumbs.isEmpty {
                QuietNote(text: "That is everything Feathr has for this view.")
                    .padding(.top, 4)
            }

            if model.flavor == ActivityKind.donation.flavor, !model.crumbs.isEmpty, !model.crumbs.contains(where: { !Plain.amount($0).isEmpty }) {
                Text("Feathr does not include gift amounts on these records yet. Amounts stay in the CSV export.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private var caption: String {
        let kind = ActivityKind.label(for: model.flavor).lowercased()
        if model.busy && model.crumbs.isEmpty { return "Loading \(kind)…" }
        if model.crumbTotal == 0 {
            return model.activityPersonLabel.isEmpty ? "No \(kind) yet." : "No \(kind) for \(model.activityPersonLabel)."
        }
        let scope = model.activityPersonLabel.isEmpty ? "on the account" : "for \(model.activityPersonLabel)"
        return "Showing \(model.crumbs.count) of \(model.crumbTotal) \(kind) \(scope). Newest first."
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
                selected: selected
            ) { model.select(crumb) }
            if hovering || selected {
                rowAction("person.crop.circle", help: "Open this person") {
                    Task { await model.openPerson(from: crumb) }
                }
                if model.activityPersonID.isEmpty, !JSON.string(crumb["person_id"]).isEmpty {
                    rowAction("line.3.horizontal.decrease.circle", help: "Show only this person's activity") {
                        model.personActivity(from: crumb)
                    }
                }
            }
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
        var parts = [JSON.shortDate(JSON.string(crumb["created_at"]))]
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
