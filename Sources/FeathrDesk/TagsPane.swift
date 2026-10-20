import SwiftUI

struct TagsPane: View {
    @ObservedObject var model: DeskModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneIntro(text: "Click a tag to rename it in the details rail. Creating one does not add people.")
            HStack {
                DeskField("Find a tag", text: $model.tagQuery)
                    .focused($searchFocused)
                    .searchFocus(model, .tags, $searchFocused)
                DeskField("New tag name", text: $model.newTagName) {
                    if canCreate { model.createTag() }
                }
                CopperButton(title: "Create", enabled: canCreate) { model.createTag() }
            }
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
            ForEach(filteredTags, id: \.selfID) { tag in
                RowButton(
                    title: JSON.string(tag["name"]),
                    subtitle: "Created \(JSON.shortDate(JSON.string(tag["date_created"])))",
                    selected: JSON.string(tag["id"]) == JSON.string(model.selected["id"])
                ) {
                    model.select(tag)
                }
            }
        }
    }

    private var canCreate: Bool {
        model.canWriteTags && !model.newTagName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var caption: String {
        let shown = filteredTags.count
        if model.tagQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return "\(shown) tag\(shown == 1 ? "" : "s"), A to Z."
        }
        return "\(shown) of \(model.tags.count) tags match."
    }

    private var filteredTags: [[String: Any]] {
        let q = model.tagQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = model.tags.sorted { JSON.string($0["name"]).localizedCaseInsensitiveCompare(JSON.string($1["name"])) == .orderedAscending }
        guard !q.isEmpty else { return rows }
        return rows.filter { JSON.string($0["name"]).localizedCaseInsensitiveContains(q) }
    }
}
