import SwiftUI

struct DetailRail: View {
    @ObservedObject var model: DeskModel
    @State private var copiedLabel = ""
    @State private var showRaw = false

    private var row: [String: Any] { model.selected }
    private var kind: RowKind { model.kind(of: row) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RailLabel(text: "DETAILS")
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)
            if row.isEmpty {
                Text(emptyDetail)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(detailRows, id: \.label) { line in
                            LabeledValue(label: line.label, value: line.value)
                        }
                        if kind == .crumb { rawFields }
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 360)
                actions
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                if kind == .tag {
                    VStack(alignment: .leading, spacing: 8) {
                        DeskField("New name", text: $model.renameTag) {
                            model.renameSelectedTag()
                        }
                        CopperButton(title: "Rename tag", enabled: model.canWriteTags && renameChanged) {
                            model.renameSelectedTag()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
                Divider().overlay(Color.white.opacity(0.08))
            }
            RailLabel(text: "WHAT HAPPENED")
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if model.notes.isEmpty {
                        QuietNote(text: "Nothing yet this session.")
                    }
                    ForEach(model.notes) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.time.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(DeskTheme.copper.opacity(0.9))
                            Text(line.text)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 280)
        .background(DeskTheme.rail)
        .onChange(of: JSON.string(model.selected["id"])) { _, _ in showRaw = false }
    }

    private var renameChanged: Bool {
        let name = model.renameTag.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name != JSON.string(row["name"])
    }

    @ViewBuilder
    private var actions: some View {
        FlowLayout {
            let email = JSON.string(row["email"])
            if (kind == .person || kind == .crumb), email.contains("@") {
                QuietButton(title: copiedLabel == "email" ? "Copied" : "Copy email", systemImage: "envelope") {
                    copy(email, as: "email")
                }
            }
            let id = JSON.string(row["id"])
            if !id.isEmpty {
                QuietButton(title: copiedLabel == "id" ? "Copied" : "Copy id", systemImage: "doc.on.doc") {
                    copy(id, as: "id")
                }
            }
            if kind == .crumb {
                QuietButton(title: "Open person", systemImage: "person.crop.circle") {
                    Task { await model.openPerson(from: row) }
                }
                if model.activityPersonID.isEmpty, !JSON.string(row["person_id"]).isEmpty {
                    QuietButton(title: "Their activity", systemImage: "line.3.horizontal.decrease") {
                        model.personActivity(from: row)
                    }
                }
            }
            if kind == .person, !id.isEmpty {
                QuietButton(title: "Their gifts", systemImage: "gift") {
                    model.showActivity(flavor: ActivityKind.donation.flavor, personID: id, label: email.ifEmpty(Plain.personTitle(row)))
                }
            }
        }
    }

    /// Every scalar field on the breadcrumb, so new Feathr fields (such as gift amount) are visible as soon as they arrive.
    @ViewBuilder
    private var rawFields: some View {
        let skip: Set<String> = ["email", "flavor", "created_at"]
        let pairs = row.keys.sorted().compactMap { key -> (String, String)? in
            guard !skip.contains(key), !key.lowercased().contains("secret") else { return nil }
            let text = JSON.display(row[key])
            return text.isEmpty ? nil : (key, text)
        }
        if !pairs.isEmpty {
            DisclosureGroup(isExpanded: $showRaw) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(pairs, id: \.0) { pair in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pair.0)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(pair.1)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                                .textSelection(.enabled)
                                .lineLimit(4)
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                Text("All fields Feathr sent (\(pairs.count))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .tint(DeskTheme.copper)
        }
    }

    private var emptyDetail: String {
        switch model.section {
        case .people: return "Find someone and their name, tags, and custom fields show up here."
        case .tags: return "Click a tag to see it and rename it."
        case .campaigns: return "Click a campaign to see its dates and status."
        case .activity: return "Click a row to see who it was and when. Hover a row to open the person."
        case .webhooks: return "Click a sync card to see its details here."
        default: return "Click something in the list to see it here."
        }
    }

    private var detailRows: [DetailLine] {
        var lines: [DetailLine] = []
        func add(_ label: String, _ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != "—" else { return }
            lines.append(DetailLine(label: label, value: trimmed))
        }
        switch kind {
        case .person:
            add("Name", Plain.personTitle(row))
            add("Email", JSON.string(row["email"]))
            add("Phone", JSON.string(row["phone"]))
            add("Last seen", JSON.shortDate(JSON.string(row["date_last_seen"])))
            add("Tags", JSON.tagIDs(row).map { model.tagName($0) }.joined(separator: ", "))
            for field in model.customFieldRows(row) {
                add(field.label, field.value)
            }
        case .crumb:
            add("Email", JSON.string(row["email"]))
            add("What happened", ActivityKind.label(for: JSON.string(row["flavor"])))
            add("When", JSON.shortDate(JSON.string(row["created_at"])))
            add("Amount", Plain.amount(row))
            add("Campaign", Plain.campaignLabel(row) { model.campaignName($0) })
            add("Project", model.projectName(JSON.string(row["project_id"])))
        case .campaign:
            add("Campaign", JSON.string(row["name"]))
            add("Status", Plain.state(JSON.string(row["state"])))
            add("Type", Plain.kind(JSON.string(row["kind"])))
            add("Project", model.projectName(JSON.string(row["project_id"])))
            add("Starts", JSON.shortDate(JSON.string(row["date_start"])))
            add("Ends", JSON.shortDate(JSON.string(row["date_end"])))
        case .webhook:
            add("Name", JSON.string(row["name"]))
            add("Status", JSON.bool(row["is_active"]) == true ? "Running" : "Paused")
            add("Sends", Plain.hookEvents(row))
            add("Delivered", Plain.successRate(row))
            add("Last try", JSON.shortDate(JSON.string(row["last_delivery_at"])))
            add("Last problem", Plain.hookError(JSON.string(row["last_error"])))
        case .tag:
            add("Tag", JSON.string(row["name"]))
            add("Created", JSON.shortDate(JSON.string(row["date_created"])))
        case .project:
            add("Project", JSON.string(row["name"]))
            add("Website", JSON.string(row["site_url"]))
            let id = JSON.string(row["id"])
            let count = model.campaigns.filter { JSON.string($0["project_id"]) == id }.count
            add("Campaigns", count > 0 ? "\(count)" : "")
        case .field:
            add("Field", JSON.string(row["label"]).ifEmpty(JSON.string(row["key"])))
            add("On", JSON.string(row["collection"]))
            add("Type", JSON.string(row["data_type"]))
            add("Used as", JSON.string(row["key"]))
        case .unknown:
            add("Id", JSON.string(row["id"]))
        }
        return lines
    }

    private func copy(_ text: String, as label: String) {
        Clipboard.copy(text)
        copiedLabel = label
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if copiedLabel == label { copiedLabel = "" }
        }
    }
}

private struct DetailLine {
    var label: String
    var value: String
}
