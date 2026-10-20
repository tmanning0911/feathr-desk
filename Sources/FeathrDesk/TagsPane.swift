import SwiftUI

struct TagsPane: View {
    @ObservedObject var model: DeskModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaneIntro(text: "Click a tag to rename it in the details rail. Creating one does not add people.")
            HStack {
                DeskField("Find a tag", text: $model.tagQuery, icon: "magnifyingglass")
                    .focused($searchFocused)
                    .searchFocus(model, .tags, $searchFocused)
                if model.canWriteTags {
                    DeskField("New tag name", text: $model.newTagName) {
                        if canCreate { model.createTag() }
                    }
                    CopperButton(title: "Create…", enabled: canCreate) { model.createTag() }
                }
            }
            .frame(maxWidth: 760)
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))

            let rows = model.filteredTags
            if model.tags.isEmpty && !model.connected {
                SkeletonRows(count: 6)
            } else if model.tags.isEmpty {
                EmptyState(symbol: "tag", title: "No tags yet", message: model.canWriteTags ? "Name one above to create it. It starts empty." : "Tags created in Feathr show up here after the next refresh.")
            } else if rows.isEmpty {
                let name = model.tagQuery.trimmingCharacters(in: .whitespaces)
                EmptyState(
                    symbol: "magnifyingglass",
                    title: "No tag named like “\(name)”",
                    message: "Check the spelling, or create it if it should exist.",
                    actionTitle: model.canWriteTags ? "Create “\(name)”…" : nil
                ) {
                    model.newTagName = name
                    model.createTag()
                }
            }
            ForEach(rows, id: \.selfID) { tag in
                RowButton(
                    title: JSON.string(tag["name"]),
                    subtitle: created(tag),
                    symbol: "tag",
                    selected: JSON.string(tag["id"]) == JSON.string(model.selected["id"])
                ) {
                    model.select(tag)
                }
                .id(tag.selfID)
                .frame(maxWidth: 760)
            }
        }
    }

    private func created(_ tag: [String: Any]) -> String {
        let date = Human.date(JSON.string(tag["date_created"]))
        return date.isEmpty ? "" : "Created \(date)"
    }

    private var canCreate: Bool {
        model.canWriteTags && !model.newTagName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var caption: String {
        let shown = model.filteredTags.count
        if model.tagQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return "\(Human.plural(shown, "tag")), A to Z."
        }
        return "\(Human.count(shown)) of \(Human.plural(model.tags.count, "tag")) match."
    }
}
