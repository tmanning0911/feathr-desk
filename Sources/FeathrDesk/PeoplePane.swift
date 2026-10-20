import SwiftUI

struct PeoplePane: View {
    @ObservedObject var model: DeskModel
    @FocusState private var searchFocused: Bool

    private var isPerson: Bool { model.kind(of: model.selected) == .person }
    private var ranQuery: String { model.peopleQueryRan }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaneIntro(text: "Look someone up by the email they used, or paste a Feathr person id. Then update their name, phone, or tags.")
            HStack(spacing: 8) {
                DeskField("Email or Feathr person id", text: $model.personQuery, icon: "magnifyingglass") {
                    model.searchPeople()
                }
                .focused($searchFocused)
                .searchFocus(model, .people, $searchFocused)
                .frame(maxWidth: 460)
                CopperButton(title: "Find", enabled: !model.personQuery.trimmingCharacters(in: .whitespaces).isEmpty && model.connected) {
                    model.searchPeople()
                }
            }
            if let hint = model.peopleHint {
                Banner(tone: .info, text: hint, onDismiss: { model.peopleHint = nil })
                    .frame(maxWidth: 680)
            }

            if model.peopleSearching {
                SkeletonRows(count: 2).frame(maxWidth: 680)
            } else if model.people.count > 1 {
                MultiMatch(model: model)
            }

            if model.peopleSearching {
                EmptyView()
            } else if isPerson {
                PersonCard(model: model)
            } else if !ranQuery.isEmpty && model.people.isEmpty {
                noMatch
            } else if model.people.isEmpty {
                idle
            }

            DisclosureGroup(isExpanded: $model.showCreatePerson) {
                CreatePerson(model: model)
            } label: {
                Text("Add someone who is not in Feathr yet")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .tint(DeskTheme.copper)
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.top, 6)
        }
    }

    private var noMatch: some View {
        let email = ranQuery.contains("@") ? ranQuery.lowercased() : ""
        return EmptyState(
            symbol: "person.crop.circle.badge.questionmark",
            title: email.isEmpty ? "No person with that id" : "No one in Feathr uses \(email)",
            message: email.isEmpty
                ? "The id may belong to someone who was merged or deleted. Try their email instead."
                : "Check the spelling, or try another address they might use. Feathr only matches the full email.",
            actionTitle: !email.isEmpty && model.canWritePeople ? "Add \(email) to Feathr…" : nil
        ) {
            model.startCreate(withEmail: email)
        }
    }

    @ViewBuilder
    private var idle: some View {
        EmptyState(
            symbol: "person.text.rectangle",
            title: "Look someone up",
            message: "Type the email they gave and press Return. ⌘F jumps here from anywhere, and ⌘K finds people, tags, and campaigns in one place."
        )
        if !model.recentPeople.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Opened this session")
                FlowLayout {
                    ForEach(model.recentPeople, id: \.selfID) { person in
                        Button {
                            model.showPerson(person)
                        } label: {
                            HStack(spacing: 6) {
                                Avatar(person: person, size: 18)
                                Text(Plain.personTitle(person))
                                    .lineLimit(1)
                            }
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.leading, 4)
                            .padding(.trailing, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
        }
    }
}

private struct MultiMatch: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(DeskTheme.warn)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Human.count(model.peopleMatchTotal ?? model.people.count)) people in Feathr share \(model.peopleQueryRan.lowercased()).")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(caption)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(DeskTheme.warn.opacity(0.08)))

            ForEach(Array(model.people.enumerated()), id: \.element.selfID) { index, person in
                MatchRow(model: model, person: person, index: index + 1)
                    .id(person.selfID)
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
    }

    private var caption: String {
        var text = "They are likely duplicate records. Pick one to see its tags and fields. Merging happens in Feathr."
        if let total = model.peopleMatchTotal, total > model.people.count {
            text += " Showing the first \(model.people.count)."
        }
        return text
    }
}

private struct MatchRow: View {
    @ObservedObject var model: DeskModel
    let person: [String: Any]
    let index: Int

    private var selected: Bool { person.selfID == model.selected.selfID }

    var body: some View {
        Button {
            model.select(person)
        } label: {
            HStack(spacing: 10) {
                Text("\(index)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? DeskTheme.ink.opacity(0.6) : .white.opacity(0.3))
                    .frame(width: 14)
                Avatar(person: person, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(JSON.personName(person).ifEmpty("No name on record"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(facts)
                        .font(.system(size: 11))
                        .opacity(0.7)
                }
                .foregroundStyle(selected ? DeskTheme.ink : .white.opacity(0.9))
                Spacer()
                Text("…\(String(JSON.string(person["id"]).suffix(6)))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(selected ? DeskTheme.ink.opacity(0.6) : .white.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? DeskTheme.copper : Color.white.opacity(0.04)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var facts: String {
        var parts: [String] = []
        let created = Human.date(JSON.string(person["date_created"]))
        if !created.isEmpty { parts.append("Created \(created)") }
        let seen = Human.relative(JSON.string(person["date_last_seen"]))
        if !seen.isEmpty { parts.append("seen \(seen)") }
        parts.append(Human.plural(JSON.tagIDs(person).count, "tag"))
        let phone = JSON.string(person["phone"])
        if !phone.isEmpty { parts.append(phone) }
        return parts.joined(separator: " · ")
    }
}

private struct PersonCard: View {
    @ObservedObject var model: DeskModel

    private var person: [String: Any] { model.selected }
    private var canRemoveTags: Bool { model.canWriteTags && model.canWritePeople }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            DeskCard(maxWidth: 680) {
                SectionLabel(text: "Their activity")
                FlowLayout {
                    ForEach([ActivityKind.donation, .form, .emailClick, .pageView]) { kind in
                        FilterChip(title: kind.label, count: nil, selected: false, symbol: kind.symbol) {
                            model.showActivity(flavor: kind.flavor, personID: JSON.string(person["id"]), label: JSON.string(person["email"]).ifEmpty(Plain.personTitle(person)))
                        }
                    }
                }
            }
            details
            tagsCard
            customFields
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Avatar(person: person, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(Plain.personTitle(person).ifEmpty("No name on record"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                let email = JSON.string(person["email"])
                if !email.isEmpty {
                    HStack(spacing: 4) {
                        Text(email)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .textSelection(.enabled)
                        CopyButton(text: email, label: "Copy email")
                    }
                }
                Text(facts)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.42))
                let id = JSON.string(person["id"])
                if !id.isEmpty {
                    HStack(spacing: 4) {
                        Text(id)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.32))
                            .textSelection(.enabled)
                        CopyButton(text: id, label: "Copy Feathr id")
                    }
                }
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
    }

    private var facts: String {
        var parts: [String] = []
        let seen = Human.relative(JSON.string(person["date_last_seen"]))
        parts.append(seen.isEmpty ? "Not seen on a tracked site yet" : "Last seen \(seen)")
        let created = Human.date(JSON.string(person["date_created"]))
        if !created.isEmpty { parts.append("in Feathr since \(created)") }
        return parts.joined(separator: " · ")
    }

    private var details: some View {
        DeskCard(maxWidth: 680) {
            SectionLabel(text: "Details")
            HStack {
                DeskField("First name", text: $model.draftFirst)
                DeskField("Last name", text: $model.draftLast)
            }
            DeskField("Phone", text: $model.draftPhone)
            HStack(spacing: 10) {
                CopperButton(title: "Save person…", enabled: model.canWritePeople && hasChanges) {
                    model.savePerson()
                }
                if !model.canWritePeople {
                    QuietNote(text: "This key can read people but not edit them.")
                } else if hasChanges {
                    Button("Undo changes") {
                        model.draftFirst = JSON.string(person["first_name"])
                        model.draftLast = JSON.string(person["last_name"])
                        model.draftPhone = JSON.string(person["phone"])
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private var tagsCard: some View {
        let ids = JSON.tagIDs(person)
        return DeskCard(maxWidth: 680) {
            SectionLabel(text: "Tags", count: ids.count)
            if ids.isEmpty {
                QuietNote(text: "No tags on this person yet.")
            } else {
                FlowLayout {
                    ForEach(ids, id: \.self) { id in
                        TagChip(name: model.tagName(id), onRemove: canRemoveTags ? { model.removeTag(id) } : nil)
                    }
                }
            }
            if model.canWriteTags {
                HStack {
                    Picker("Add", selection: $model.tagToApply) {
                        ForEach(availableTags, id: \.selfID) { tag in
                            Text(JSON.string(tag["name"])).tag(JSON.string(tag["id"]))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                    .disabled(availableTags.isEmpty)
                    CopperButton(title: "Add tag…", enabled: !model.tagToApply.isEmpty && !ids.contains(model.tagToApply)) {
                        model.applyTag()
                    }
                }
                .padding(.top, 2)
            } else {
                QuietNote(text: "This key cannot change tags.")
            }
        }
    }

    @ViewBuilder
    private var customFields: some View {
        let rows = model.customFieldRows(person)
        if !rows.isEmpty || !model.fields.isEmpty {
            DeskCard(maxWidth: 680) {
                SectionLabel(text: "Custom fields", count: rows.isEmpty ? nil : rows.count)
                if rows.isEmpty {
                    QuietNote(text: "No custom field values on this person.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.key) { index, row in
                            FieldLine(label: row.label, key: row.key, value: row.value, type: JSON.string(model.fieldDefinition(row.key)?["data_type"]))
                            if index < rows.count - 1 {
                                Rectangle().fill(DeskTheme.line).frame(height: 1)
                            }
                        }
                    }
                    QuietNote(text: "Read-only here. Edit custom fields in Feathr.")
                        .padding(.top, 4)
                }
            }
        }
    }

    private var hasChanges: Bool {
        model.draftFirst.trimmingCharacters(in: .whitespaces) != JSON.string(person["first_name"])
            || model.draftLast.trimmingCharacters(in: .whitespaces) != JSON.string(person["last_name"])
            || model.draftPhone.trimmingCharacters(in: .whitespaces) != JSON.string(person["phone"])
    }

    private var availableTags: [[String: Any]] {
        let have = Set(JSON.tagIDs(person))
        return model.tags.filter { !have.contains(JSON.string($0["id"])) }
    }
}

private struct FieldLine: View {
    let label: String
    let key: String
    let value: String
    let type: String
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 190, alignment: .leading)
                .help(type.isEmpty ? key : "\(key) · \(type)")
            Text(value)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            CopyButton(text: value, label: "Copy \(label)")
                .opacity(hovering ? 1 : 0)
        }
        .padding(.vertical, 7)
        .onHover { hovering = $0 }
    }
}

private struct CreatePerson: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            QuietNote(text: "This adds them in Feathr. It does not email them.")
            DeskField("Email", text: $model.draftEmail)
            HStack {
                DeskField("First name", text: $model.createFirst)
                DeskField("Last name", text: $model.createLast)
            }
            DeskField("Phone", text: $model.createPhone)
            HStack(spacing: 10) {
                CopperButton(title: "Create person…", enabled: model.canWritePeople && model.draftEmail.contains("@")) {
                    model.createPerson()
                }
                if !model.canWritePeople {
                    QuietNote(text: "This key cannot create people.")
                }
            }
        }
        .padding(.top, 8)
    }
}
