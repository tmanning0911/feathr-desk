import SwiftUI

struct CampaignsPane: View {
    @ObservedObject var model: DeskModel
    @FocusState private var searchFocused: Bool

    private var stateFilter: String? { model.campaignState.isEmpty ? nil : model.campaignState }
    private var kindFilter: String? { model.campaignKind.isEmpty ? nil : model.campaignKind }
    private var projectFilter: String? { model.campaignProject.isEmpty ? nil : model.campaignProject }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneIntro(text: "Look up a campaign. Starting, stopping, and sending still happen in Feathr.")
            DeskField("Find a campaign or project", text: $model.campaignQuery, icon: "magnifyingglass")
                .focused($searchFocused)
                .searchFocus(model, .campaigns, $searchFocused)
                .frame(maxWidth: 460)

            filterRow("Status") {
                FilterChip(title: "All", count: model.campaignCount(kind: kindFilter, project: projectFilter), selected: model.campaignState.isEmpty) {
                    model.campaignState = ""
                }
                ForEach(model.campaignStates, id: \.self) { state in
                    FilterChip(title: Plain.state(state), count: model.campaignCount(state: state, kind: kindFilter, project: projectFilter), selected: model.campaignState == state) {
                        model.campaignState = model.campaignState == state ? "" : state
                    }
                }
            }
            filterRow("Type") {
                FilterChip(title: "All", count: model.campaignCount(state: stateFilter, project: projectFilter), selected: model.campaignKind.isEmpty) {
                    model.campaignKind = ""
                }
                ForEach(model.campaignKinds, id: \.self) { kind in
                    FilterChip(title: Plain.kind(kind), count: model.campaignCount(state: stateFilter, kind: kind, project: projectFilter), selected: model.campaignKind == kind) {
                        model.campaignKind = model.campaignKind == kind ? "" : kind
                    }
                }
            }
            filterRow("Project") {
                Menu {
                    Button("All projects (\(model.campaignCount(state: stateFilter, kind: kindFilter)))") { model.campaignProject = "" }
                    Divider()
                    ForEach(model.campaignProjects, id: \.id) { project in
                        Button("\(project.name) (\(model.campaignCount(state: stateFilter, kind: kindFilter, project: project.id)))") {
                            model.campaignProject = project.id
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                        Text(projectFilter.map { model.projectName($0) } ?? "All projects")
                            .lineLimit(1)
                        Text(Human.count(model.campaignCount(state: stateFilter, kind: kindFilter, project: projectFilter)))
                            .foregroundStyle(projectFilter == nil ? .white.opacity(0.4) : DeskTheme.ink.opacity(0.6))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(projectFilter == nil ? .white.opacity(0.82) : DeskTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(projectFilter == nil ? Color.white.opacity(0.07) : DeskTheme.copper))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(model.campaignProjects.isEmpty)
            }

            let rows = model.filteredCampaigns
            HStack(spacing: 12) {
                Text("Showing \(Human.count(rows.count)) of \(Human.plural(model.campaigns.count, "campaign")).")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                if model.campaignFiltering {
                    Button("Clear filters") { model.clearCampaignFilters() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DeskTheme.copper)
                }
                Spacer()
                Picker("Sort", selection: $model.campaignSort) {
                    ForEach(CampaignSort.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
                .help("Sort campaigns")
            }
            .frame(maxWidth: 760)

            if model.campaigns.isEmpty && !model.connected {
                SkeletonRows(count: 6)
            } else if model.campaigns.isEmpty {
                EmptyState(symbol: "envelope", title: "No campaigns on this account", message: "Campaigns built in Feathr show up here after the next refresh.")
            } else if rows.isEmpty {
                EmptyState(symbol: "line.3.horizontal.decrease.circle", title: "No campaigns match", message: "Nothing fits these filters together. Loosen one, or clear them all.", actionTitle: "Clear filters") {
                    model.clearCampaignFilters()
                }
            }
            ForEach(rows, id: \.selfID) { row in
                RowButton(
                    title: JSON.string(row["name"]),
                    subtitle: subtitle(row),
                    dot: Plain.stateLevel(JSON.string(row["state"])),
                    selected: JSON.string(row["id"]) == JSON.string(model.selected["id"])
                ) { model.select(row) }
                .id(row.selfID)
                .frame(maxWidth: 760)
            }
        }
    }

    private func subtitle(_ row: [String: Any]) -> String {
        var parts = [Plain.state(JSON.string(row["state"])), Plain.kind(JSON.string(row["kind"])), model.projectName(JSON.string(row["project_id"]))]
        let window = Human.campaignWindow(start: JSON.string(row["date_start"]), end: JSON.string(row["date_end"]))
        if !window.isEmpty { parts.append(window) }
        return parts.filter { $0 != "—" }.joined(separator: " · ")
    }

    private func filterRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.38))
                .frame(width: 58, alignment: .leading)
                .padding(.top, 6)
            FlowLayout { content() }
        }
    }
}
