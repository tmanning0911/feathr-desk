import SwiftUI

struct ProjectsPane: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneIntro(text: "The websites and events Feathr is tracking, with how many campaigns each one has.")
            if model.projects.isEmpty {
                QuietNote(text: "No projects loaded.")
            }
            ForEach(sorted, id: \.selfID) { row in
                let id = JSON.string(row["id"])
                let count = model.campaigns.filter { JSON.string($0["project_id"]) == id }.count
                RowButton(
                    title: JSON.string(row["name"]),
                    subtitle: JSON.string(row["site_url"]),
                    trailing: count > 0 ? "\(count) campaign\(count == 1 ? "" : "s")" : "",
                    selected: id == JSON.string(model.selected["id"])
                ) {
                    model.select(row)
                }
            }
        }
    }

    private var sorted: [[String: Any]] {
        model.projects.sorted { JSON.string($0["name"]).localizedCaseInsensitiveCompare(JSON.string($1["name"])) == .orderedAscending }
    }
}
