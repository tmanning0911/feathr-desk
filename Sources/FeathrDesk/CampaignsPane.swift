import SwiftUI

struct CampaignsPane: View {
    @ObservedObject var model: DeskModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneIntro(text: "Look up a campaign. Starting, stopping, and sending still happen in Feathr.")
            DeskField("Find a campaign or project", text: $model.campaignQuery)
                .focused($searchFocused)
                .searchFocus(model, .campaigns, $searchFocused)

            filterRow("Status") {
                FilterChip(title: "All", count: model.campaignCount(kind: kindFilter), selected: model.campaignState.isEmpty) {
                    model.campaignState = ""
                }
                ForEach(model.campaignStates, id: \.self) { state in
                    FilterChip(title: Plain.state(state), count: model.campaignCount(state: state, kind: kindFilter), selected: model.campaignState == state) {
                        model.campaignState = model.campaignState == state ? "" : state
                    }
                }
            }
            filterRow("Type") {
                FilterChip(title: "All", count: model.campaignCount(state: stateFilter), selected: model.campaignKind.isEmpty) {
                    model.campaignKind = ""
                }
                ForEach(model.campaignKinds, id: \.self) { kind in
                    FilterChip(title: Plain.kind(kind), count: model.campaignCount(state: stateFilter, kind: kind), selected: model.campaignKind == kind) {
                        model.campaignKind = model.campaignKind == kind ? "" : kind
                    }
                }
            }

            let rows = model.filteredCampaigns
            HStack {
                Text("Showing \(rows.count) of \(model.campaigns.count) campaigns.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                if filtering {
                    Button("Clear filters") {
                        model.campaignState = ""
                        model.campaignKind = ""
                        model.campaignQuery = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DeskTheme.copper)
                }
            }
            if rows.isEmpty {
                QuietNote(text: model.campaigns.isEmpty ? "No campaigns loaded." : "No campaigns match these filters.")
            }
            ForEach(rows, id: \.selfID) { row in
                RowButton(
                    title: JSON.string(row["name"]),
                    subtitle: subtitle(row),
                    selected: JSON.string(row["id"]) == JSON.string(model.selected["id"])
                ) { model.select(row) }
            }
        }
    }

    private var stateFilter: String? { model.campaignState.isEmpty ? nil : model.campaignState }
    private var kindFilter: String? { model.campaignKind.isEmpty ? nil : model.campaignKind }
    private var filtering: Bool { stateFilter != nil || kindFilter != nil || !model.campaignQuery.isEmpty }

    private func subtitle(_ row: [String: Any]) -> String {
        var parts = [Plain.state(JSON.string(row["state"])), Plain.kind(JSON.string(row["kind"])), model.projectName(JSON.string(row["project_id"]))]
        let start = JSON.string(row["date_start"])
        if !start.isEmpty { parts.append("from \(JSON.shortDate(start))") }
        return parts.filter { $0 != "—" }.joined(separator: " · ")
    }

    private func filterRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.38))
                .frame(width: 52, alignment: .leading)
                .padding(.top, 6)
            FlowLayout { content() }
        }
    }
}
