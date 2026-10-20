import SwiftUI

struct FieldsPane: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneIntro(text: "Extra facts stored on a person, such as their Salesforce contact id. Values show on each person in People.")
            if model.fields.isEmpty && !model.connected {
                SkeletonRows(count: 4)
            } else if model.fields.isEmpty {
                EmptyState(symbol: "list.bullet.rectangle", title: "No custom fields", message: "Custom fields are defined in Feathr. Once they exist, their values show on each person.")
            }
            ForEach(model.fields, id: \.selfID) { field in
                RowButton(
                    title: JSON.string(field["label"]).ifEmpty(JSON.string(field["key"])),
                    subtitle: [JSON.string(field["collection"]), JSON.string(field["data_type"]), JSON.string(field["key"])]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · "),
                    symbol: "list.bullet.rectangle",
                    selected: JSON.string(field["id"]) == JSON.string(model.selected["id"])
                ) { model.select(field) }
                .id(field.selfID)
                .frame(maxWidth: 760)
            }
        }
    }
}
