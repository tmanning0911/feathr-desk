import SwiftUI

struct ProjectsPane: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneIntro(text: "The websites and events Feathr is tracking, with how many campaigns each one has.")
            if model.projects.isEmpty && !model.connected {
                SkeletonRows(count: 4)
            } else if model.projects.isEmpty {
                EmptyState(symbol: "folder", title: "No projects on this account", message: "Projects are set up in Feathr and show up here after the next refresh.")
            }
            ForEach(model.projects, id: \.selfID) { row in
                let id = JSON.string(row["id"])
                let count = model.campaignsInProject(id)
                RowButton(
                    title: JSON.string(row["name"]),
                    subtitle: JSON.string(row["site_url"]),
                    trailing: count > 0 ? Human.plural(count, "campaign") : "",
                    symbol: "folder",
                    selected: id == JSON.string(model.selected["id"])
                ) {
                    model.select(row)
                }
                .id(row.selfID)
                .frame(maxWidth: 760)
            }
        }
    }
}
