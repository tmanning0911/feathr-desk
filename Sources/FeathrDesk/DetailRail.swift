import SwiftUI

struct DetailRail: View {
    @ObservedObject var model: DeskModel
    @State private var copiedLabel = ""
    @State private var showRaw = false

    private var row: [String: Any] { model.selected }
    private var kind: RowKind { model.kind(of: row) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                RailLabel(text: "DETAILS")
                Spacer()
                if !row.isEmpty {
                    Button {
                        model.clearSelection()
                    } label: {
                        KeyCap(text: "esc")
                    }
                    .buttonStyle(.plain)
                    .help("Clear selection (Esc)")
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)
            if row.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(emptyDetail)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)
                    if !model.visibleRows.isEmpty {
                        HStack(spacing: 5) {
                            KeyCap(text: "↑")
                            KeyCap(text: "↓")
                            Text("to move through the list")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(heading)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(detailRows, id: \.label) { line in
                            LabeledValue(label: line.label, value: line.value, mono: line.mono)
                        }
                        if kind == .crumb { rawFields }
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 440)
                actions
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                if kind == .tag, model.canWriteTags {
                    VStack(alignment: .leading, spacing: 8) {
                        DeskField("New name", text: $model.renameTag) {
                            model.renameSelectedTag()
                        }
                        CopperButton(title: "Rename tag…", enabled: renameChanged) {
                            model.renameSelectedTag()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
            Rectangle().fill(DeskTheme.line).frame(height: 1)
            RailLabel(text: "WHAT HAPPENED")
                .padding(.horizontal, 14)
                .padding(.top, 12)
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
                                .fixedSize(horizontal: false, vertical: true)
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

    private var heading: String {
        switch kind {
        case .person: return Plain.personTitle(row).ifEmpty("Person")
        case .crumb: return ActivityKind.label(for: JSON.string(row["flavor"])).replacingOccurrences(of: "s$", with: "", options: .regularExpression)
        case .campaign, .tag, .project: return JSON.string(row["name"]).ifEmpty("Untitled")
        case .webhook: return Plain.hookTitle(row)
        case .field: return JSON.string(row["label"]).ifEmpty(JSON.string(row["key"]))
        case .unknown: return "Record"
        }
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
                QuietButton(title: copiedLabel == "email" ? "Copied" : "Copy email", systemImage: copiedLabel == "email" ? "checkmark" : "envelope") {
                    copy(email, as: "email")
                }
            }
            let id = JSON.string(row["id"])
            if !id.isEmpty {
                QuietButton(title: copiedLabel == "id" ? "Copied" : "Copy id", systemImage: copiedLabel == "id" ? "checkmark" : "doc.on.doc") {
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
            if kind == .project, !id.isEmpty, model.campaignsInProject(id) > 0 {
                QuietButton(title: "Its campaigns", systemImage: "envelope") {
                    model.clearCampaignFilters()
                    model.campaignProject = id
                    model.go(.campaigns)
                }
            }
            if kind == .campaign {
                let project = JSON.string(row["project_id"])
                if !project.isEmpty, model.section == .campaigns, model.campaignProject != project {
                    QuietButton(title: "Same project", systemImage: "folder") {
                        model.campaignProject = project
                    }
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
        case .desk: return "Click a recent gift to see who gave and when."
        case .people: return "Find someone and their name, tags, and custom fields show up here."
        case .tags: return "Click a tag to see it and rename it."
        case .campaigns: return "Click a campaign to see when it runs and which project it belongs to."
        case .activity: return "Click a row to see who it was and when. Return opens the person."
        case .webhooks: return "Click a sync card to see its details here."
        case .projects: return "Click a project to see its site and campaigns."
        case .fields: return "Click a field to see how Feathr stores it."
        }
    }

    private var detailRows: [DetailLine] {
        var lines: [DetailLine] = []
        func add(_ label: String, _ value: String, mono: Bool = false) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != "—" else { return }
            lines.append(DetailLine(label: label, value: trimmed, mono: mono))
        }
        func addDates() {
            for (key, label) in [("date_created", "Created"), ("created_at", "Created"), ("date_last_modified", "Last changed"), ("date_updated", "Last changed"), ("updated_at", "Last changed")] {
                guard !lines.contains(where: { $0.label == label }) else { continue }
                add(label, Human.dateLine(JSON.string(row[key])))
            }
        }
        switch kind {
        case .person:
            add("Email", JSON.string(row["email"]))
            add("Phone", JSON.string(row["phone"]))
            add("Last seen", Human.dateLine(JSON.string(row["date_last_seen"])))
            add("In Feathr since", Human.date(JSON.string(row["date_created"])))
            add("Tags", JSON.tagIDs(row).map { model.tagName($0) }.joined(separator: ", "))
            for field in model.customFieldRows(row) {
                add(field.label, field.value)
            }
        case .crumb:
            add("Email", JSON.string(row["email"]))
            let when = JSON.string(row["created_at"])
            add("When", [Human.dateTime(when), Human.relative(when)].filter { !$0.isEmpty }.joined(separator: " · "))
            add("Amount", Plain.amount(row))
            add("Campaign", Plain.campaignLabel(row) { model.campaignName($0) })
            add("Project", model.projectName(JSON.string(row["project_id"])))
        case .campaign:
            add("Status", Plain.state(JSON.string(row["state"])))
            add("Type", Plain.kind(JSON.string(row["kind"])))
            add("Project", model.projectName(JSON.string(row["project_id"])))
            add("Schedule", Human.campaignWindow(start: JSON.string(row["date_start"]), end: JSON.string(row["date_end"])))
            addDates()
        case .webhook:
            let health = SyncHealth.of(row)
            add("Status", health.headline)
            add("Sends", Plain.hookEvents(row))
            add("Delivered", Plain.successRate(row))
            add("Failures in a row", JSON.int(row["consecutive_failures"]) > 0 ? Human.count(JSON.int(row["consecutive_failures"])) : "")
            add("Last try", Human.dateLine(JSON.string(row["last_delivery_at"])))
            add("Last problem", Plain.hookError(JSON.string(row["last_error"])))
            add("Address", JSON.string(row["target_url"]), mono: true)
        case .tag:
            add("Created", Human.dateLine(JSON.string(row["date_created"])))
            add("Applies to", JSON.string(row["context"]).capitalized)
        case .project:
            add("Website", JSON.string(row["site_url"]))
            let count = model.campaignsInProject(JSON.string(row["id"]))
            add("Campaigns", count > 0 ? Human.count(count) : "")
            addDates()
        case .field:
            add("On", JSON.string(row["collection"]).capitalized)
            add("Type", JSON.string(row["data_type"]))
            add("Stored as", JSON.string(row["key"]), mono: true)
        case .unknown:
            add("Id", JSON.string(row["id"]), mono: true)
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
    var mono = false
}
