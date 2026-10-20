import SwiftUI

struct PeoplePane: View {
    @ObservedObject var model: DeskModel
    @State private var showCreate = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaneIntro(text: "Search by the email they used, or paste a Feathr person id. Then update their name, phone, or tags.")
            HStack(spacing: 8) {
                DeskField("Email or person id", text: $model.personQuery) {
                    Task { await model.searchPeople() }
                }
                .focused($searchFocused)
                .searchFocus(model, .people, $searchFocused)
                CopperButton(title: "Find", systemImage: "magnifyingglass") {
                    Task { await model.searchPeople() }
                }
            }
            if model.people.count > 1 {
                ForEach(model.people, id: \.selfID) { person in
                    RowButton(
                        title: JSON.string(person["email"]),
                        subtitle: JSON.personName(person),
                        selected: JSON.string(person["id"]) == JSON.string(model.selected["id"])
                    ) {
                        model.select(person)
                    }
                }
            }
            if model.kind(of: model.selected) == .person {
                PersonEditor(model: model)
            } else if !model.personQuery.isEmpty && !model.busy && model.people.isEmpty {
                QuietNote(text: "No one in Feathr matches that search.")
            } else if model.people.isEmpty {
                QuietNote(text: "Press Return after the email. ⌘F jumps here from anywhere.")
            }
            DisclosureGroup(isExpanded: $showCreate) {
                VStack(alignment: .leading, spacing: 8) {
                    QuietNote(text: "This adds them in Feathr. It does not email them.")
                    DeskField("Email", text: $model.draftEmail)
                    HStack {
                        DeskField("First name", text: $model.createFirst)
                        DeskField("Last name", text: $model.createLast)
                    }
                    DeskField("Phone", text: $model.createPhone)
                    CopperButton(title: "Create person", enabled: model.canWritePeople) {
                        model.createPerson()
                    }
                    if !model.canWritePeople {
                        QuietNote(text: "This key cannot create people.")
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Add someone who is not in Feathr yet")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .tint(DeskTheme.copper)
        }
    }
}

private struct PersonEditor: View {
    @ObservedObject var model: DeskModel

    private var person: [String: Any] { model.selected }
    private var canRemoveTags: Bool { model.canWriteTags && model.canWritePeople }

    var body: some View {
        DeskCard(maxWidth: 680) {
            Text(Plain.personTitle(person))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(JSON.string(person["email"]))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .textSelection(.enabled)
            Text("Last seen \(JSON.shortDate(JSON.string(person["date_last_seen"])))")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
            HStack {
                DeskField("First name", text: $model.draftFirst)
                DeskField("Last name", text: $model.draftLast)
            }
            DeskField("Phone", text: $model.draftPhone)
            CopperButton(title: "Save person", enabled: model.canWritePeople && hasChanges) {
                model.savePerson()
            }

            sectionLabel("Tags")
            let ids = JSON.tagIDs(person)
            if ids.isEmpty {
                QuietNote(text: "None on this person.")
            } else {
                FlowLayout {
                    ForEach(ids, id: \.self) { id in
                        TagChip(name: model.tagName(id), onRemove: canRemoveTags ? { model.removeTag(id) } : nil)
                    }
                }
            }
            HStack {
                Picker("Add", selection: $model.tagToApply) {
                    ForEach(availableTags, id: \.selfID) { tag in
                        Text(JSON.string(tag["name"])).tag(JSON.string(tag["id"]))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320)
                CopperButton(title: "Add tag", enabled: model.canWriteTags && !model.tagToApply.isEmpty) {
                    model.applyTag()
                }
            }

            let custom = model.customFieldRows(person)
            if !custom.isEmpty {
                sectionLabel("Custom fields")
                ForEach(custom, id: \.label) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 180, alignment: .leading)
                        Text(row.value)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .textSelection(.enabled)
                    }
                }
                QuietNote(text: "Custom fields are read-only here.")
            }

            HStack(spacing: 14) {
                link("Their gifts") { openActivity(.donation) }
                link("Their form fills") { openActivity(.form) }
                link("All their email clicks") { openActivity(.emailClick) }
            }
            .padding(.top, 6)
        }
    }

    private var hasChanges: Bool {
        model.draftFirst.trimmingCharacters(in: .whitespaces) != JSON.string(person["first_name"])
            || model.draftLast.trimmingCharacters(in: .whitespaces) != JSON.string(person["last_name"])
            || model.draftPhone.trimmingCharacters(in: .whitespaces) != JSON.string(person["phone"])
    }

    private var availableTags: [[String: Any]] {
        let have = Set(JSON.tagIDs(person))
        return model.tags
            .filter { !have.contains(JSON.string($0["id"])) || JSON.string($0["id"]) == model.tagToApply }
            .sorted { JSON.string($0["name"]).localizedCaseInsensitiveCompare(JSON.string($1["name"])) == .orderedAscending }
    }

    private func openActivity(_ kind: ActivityKind) {
        model.showActivity(
            flavor: kind.flavor,
            personID: JSON.string(person["id"]),
            label: JSON.string(person["email"]).ifEmpty(Plain.personTitle(person))
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.top, 6)
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DeskTheme.copper)
    }
}
