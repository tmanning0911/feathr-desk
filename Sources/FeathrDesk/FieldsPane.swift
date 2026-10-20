import SwiftUI

struct FieldsPane: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneIntro(text: "Extra facts stored on a person, such as their Salesforce contact id. Values show on each person in People.")
            if model.fields.isEmpty {
                QuietNote(text: "No custom fields loaded.")
            }
            ForEach(model.fields, id: \.selfID) { field in
                RowButton(
                    title: JSON.string(field["label"]).ifEmpty(JSON.string(field["key"])),
                    subtitle: [JSON.string(field["collection"]), JSON.string(field["data_type"]), JSON.string(field["key"])]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · "),
                    selected: JSON.string(field["id"]) == JSON.string(model.selected["id"])
                ) { model.select(field) }
            }
        }
    }
}
