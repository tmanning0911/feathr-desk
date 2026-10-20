import SwiftUI

struct DeskView: View {
    @ObservedObject var model: DeskModel
    @State private var showKey = false
    @State private var showCreate = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(spacing: 0) {
                sideRail
                center
                notesRail
            }
        }
        .background(DeskTheme.desk)
        .preferredColorScheme(.dark)
        .alert("Feathr", isPresented: Binding(get: { model.errorText != nil }, set: { if !$0 { model.errorText = nil } })) {
            Button("OK") { model.errorText = nil }
        } message: {
            Text(model.errorText ?? "")
        }
        .alert(model.pending?.title ?? "Confirm", isPresented: Binding(get: { model.pending != nil }, set: { if !$0 { model.pending = nil } })) {
            Button("Cancel", role: .cancel) { model.pending = nil }
            Button(model.pending?.button ?? "Save") {
                let job = model.pending
                model.pending = nil
                if let job {
                    Task { await job.run() }
                }
            }
        } message: {
            Text(model.pending?.detail ?? "")
        }
        .sheet(isPresented: $showKey) {
            KeySheet(model: model)
        }
        .task { await model.boot() }
        .onChange(of: model.section) { _, section in
            guard section == .activity, model.crumbs.isEmpty, !model.busy else { return }
            Task { await model.loadActivity() }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            DeskBadge(text: "FEATHR")
            Text(model.section.rawValue)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            if model.busy {
                ProgressView().controlSize(.small)
            }
            Spacer()
            if let rate = model.me["rate_limit"] as? [String: Any], JSON.int(rate["remaining"]) < 200 {
                Text("\(JSON.int(rate["remaining"])) requests left this minute")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DeskTheme.copper)
            }
            QuietButton(title: "Refresh", systemImage: "arrow.clockwise") {
                Task { await model.refreshDesk() }
            }
            Button {
                showKey = true
            } label: {
                Image(systemName: "key")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            .help("Feathr key")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DeskTheme.rail)
    }

    private var sideRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            RailLabel(text: "GO TO")
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(DeskSection.allCases) { side in
                        Button {
                            model.section = side
                            model.selected = [:]
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: side.symbol)
                                    .frame(width: 16)
                                    .foregroundStyle(model.section == side ? DeskTheme.ink : .white.opacity(0.55))
                                Text(side.rawValue)
                                    .font(.system(size: 13, weight: model.section == side ? .semibold : .regular, design: .rounded))
                                    .foregroundStyle(model.section == side ? DeskTheme.ink : .white.opacity(0.88))
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(model.section == side ? DeskTheme.copper : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
            }
            Spacer()
            Text(model.lastFour.isEmpty ? "Not connected" : "Key …\(model.lastFour)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
                .padding(14)
        }
        .frame(width: 196)
        .background(DeskTheme.rail)
    }

    @ViewBuilder
    private var center: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch model.section {
                case .desk: deskHome
                case .people: peoplePane
                case .tags: tagsPane
                case .campaigns: campaignsPane
                case .projects: projectsPane
                case .activity: activityPane
                case .fields: fieldsPane
                case .webhooks: webhooksPane
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DeskTheme.desk)
    }

    private var notesRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            RailLabel(text: "DETAILS")
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)
            if model.selected.isEmpty {
                Text(emptyDetail)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(detailRows, id: \.label) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.label.uppercased())
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .tracking(1)
                                    .foregroundStyle(.white.opacity(0.38))
                                Text(row.value)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(maxHeight: 320)
                QuietButton(title: copied ? "Copied" : "Copy id", systemImage: "doc.on.doc") {
                    copy(JSON.string(model.selected["id"]))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                if selectedIsTag {
                    VStack(alignment: .leading, spacing: 8) {
                        field("New name", text: $model.renameTag)
                        CopperButton(title: "Rename tag", enabled: model.canWriteTags) {
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
            }
        }
        .frame(width: 280)
        .background(DeskTheme.rail)
    }

    private var deskHome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.status)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Look someone up, check a tag, or see recent gifts. Email still sends from Feathr.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .frame(maxWidth: 520, alignment: .leading)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                statButton("People", "Search", .people)
                statButton("Tags", "\(model.tags.count)", .tags)
                statButton("Campaigns", "\(model.campaigns.count)", .campaigns)
                statButton("Projects", "\(model.projects.count)", .projects)
                statButton("Gifts", "Recent", .activity)
            }

            if let hook = model.webhooks.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text(JSON.bool(hook["is_active"]) == true ? "Salesforce sync is on" : "Salesforce sync is paused")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(syncExplanation(hook))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                    QuietButton(title: "Open sync") {
                        model.section = .webhooks
                        model.selected = [:]
                    }
                }
                .padding(14)
                .frame(maxWidth: 520, alignment: .leading)
                .background(DeskTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var peoplePane: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Search by the email they used, then update their name, phone, or tags.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 8) {
                field("Email", text: $model.personQuery) {
                    Task { await model.searchPeople() }
                }
                CopperButton(title: "Find", systemImage: "magnifyingglass") {
                    Task { await model.searchPeople() }
                }
            }
            if model.people.count > 1 {
                ForEach(model.people.indices, id: \.self) { index in
                    rowButton(title: JSON.string(model.people[index]["email"]), subtitle: personSubtitle(model.people[index]), selected: sameRow(model.people[index])) {
                        model.select(model.people[index])
                    }
                }
            }
            if JSON.string(model.selected["email"]).contains("@") {
                personEditor
            } else if !model.personQuery.isEmpty && !model.busy && model.people.isEmpty {
                Text("No one in Feathr uses that email.")
                    .foregroundStyle(.white.opacity(0.45))
            } else if model.people.isEmpty {
                Text("Press Return after the email.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
            }
            DisclosureGroup(isExpanded: $showCreate) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This adds them in Feathr. It does not email them.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                    field("Email", text: $model.draftEmail)
                    HStack {
                        field("First name", text: $model.createFirst)
                        field("Last name", text: $model.createLast)
                    }
                    field("Phone", text: $model.createPhone)
                    CopperButton(title: "Create person", enabled: model.canWritePeople) {
                        model.createPerson()
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

    private var personEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(personTitle(model.selected))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(JSON.string(model.selected["email"]))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Text("Last seen \(JSON.shortDate(JSON.string(model.selected["date_last_seen"])))")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
            HStack {
                field("First name", text: $model.draftFirst)
                field("Last name", text: $model.draftLast)
            }
            field("Phone", text: $model.draftPhone)
            CopperButton(title: "Save person", enabled: model.canWritePeople) {
                model.savePerson()
            }
            Text("Tags")
                .font(.system(size: 12, weight: .semibold))
                .padding(.top, 6)
            let ids = JSON.strings(model.selected["tag_ids"])
            if ids.isEmpty {
                Text("None on this person.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                FlowChips(items: ids.map { model.tagName($0) })
            }
            HStack {
                Picker("Add", selection: $model.tagToApply) {
                    ForEach(model.tags, id: \.selfID) { tag in
                        Text(JSON.string(tag["name"])).tag(JSON.string(tag["id"]))
                    }
                }
                .labelsHidden()
                CopperButton(title: "Add tag", enabled: model.canWriteTags && !model.tagToApply.isEmpty) {
                    model.applyTag()
                }
            }
            Button("See their gifts and form fills") {
                model.activityPersonID = JSON.string(model.selected["id"])
                model.activityPersonLabel = JSON.string(model.selected["email"])
                model.crumbs = []
                model.crumbTotal = 0
                model.section = .activity
                Task { await model.loadActivity() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DeskTheme.copper)
        }
        .padding(14)
        .background(DeskTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var tagsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Click a tag to rename it. Creating one does not add people.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            HStack {
                field("Find a tag", text: $model.tagQuery)
                field("New tag name", text: $model.newTagName)
                CopperButton(title: "Create", enabled: model.canWriteTags && !model.newTagName.trimmingCharacters(in: .whitespaces).isEmpty) { model.createTag() }
            }
            ForEach(filteredTags, id: \.selfID) { tag in
                rowButton(title: JSON.string(tag["name"]), subtitle: "Created \(JSON.shortDate(JSON.string(tag["date_created"])))", selected: sameRow(tag)) {
                    model.select(tag)
                }
            }
        }
    }

    private var filteredTags: [[String: Any]] {
        let q = model.tagQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = model.tags.sorted { JSON.string($0["name"]).localizedCaseInsensitiveCompare(JSON.string($1["name"])) == .orderedAscending }
        guard !q.isEmpty else { return rows }
        return rows.filter { JSON.string($0["name"]).localizedCaseInsensitiveContains(q) }
    }

    private var campaignsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Look up a campaign. Starting, stopping, and sending still happen in Feathr.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            field("Find a campaign", text: $model.campaignQuery)
            ForEach(filteredCampaigns, id: \.selfID) { row in
                rowButton(
                    title: JSON.string(row["name"]),
                    subtitle: "\(plainState(JSON.string(row["state"]))) · \(plainKind(JSON.string(row["kind"]))) · \(model.projectName(JSON.string(row["project_id"])))",
                    selected: sameRow(row)
                ) { model.select(row) }
            }
        }
    }

    private var filteredCampaigns: [[String: Any]] {
        let q = model.campaignQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rows = model.campaigns.sorted { JSON.string($0["name"]).localizedCaseInsensitiveCompare(JSON.string($1["name"])) == .orderedAscending }
        guard !q.isEmpty else { return rows }
        return rows.filter {
            JSON.string($0["name"]).lowercased().contains(q)
                || JSON.string($0["state"]).lowercased().contains(q)
                || JSON.string($0["kind"]).lowercased().contains(q)
        }
    }

    private var projectsPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The websites and events Feathr is tracking.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            ForEach(model.projects.sorted { JSON.string($0["name"]).localizedCaseInsensitiveCompare(JSON.string($1["name"])) == .orderedAscending }, id: \.selfID) { row in
                rowButton(title: JSON.string(row["name"]), subtitle: JSON.string(row["site_url"]), selected: sameRow(row)) {
                    model.select(row)
                }
            }
        }
    }

    private var activityPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Show", selection: $model.flavor) {
                    ForEach(ActivityKind.allCases) { kind in
                        Text(kind.label).tag(kind.flavor)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
                .onChange(of: model.flavor) { _, _ in
                    Task { await model.loadActivity() }
                }
                CopperButton(title: "Load", systemImage: "arrow.down") {
                    Task { await model.loadActivity() }
                }
                if !model.activityPersonID.isEmpty {
                    QuietButton(title: "Everyone") {
                        model.activityPersonID = ""
                        model.activityPersonLabel = ""
                        Task { await model.loadActivity() }
                    }
                }
            }
            Text(activityCaption)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
            ForEach(model.crumbs, id: \.selfID) { crumb in
                rowButton(
                    title: JSON.string(crumb["email"]).ifEmpty("Unknown email"),
                    subtitle: "\(JSON.shortDate(JSON.string(crumb["created_at"]))) · \(model.projectName(JSON.string(crumb["project_id"])))",
                    selected: sameRow(crumb)
                ) { model.select(crumb) }
            }
        }
    }

    private var activityCaption: String {
        let kind = ActivityKind.label(for: model.flavor).lowercased()
        if model.busy && model.crumbs.isEmpty { return "Loading \(kind)…" }
        if model.crumbTotal == 0 {
            return model.activityPersonLabel.isEmpty ? "No \(kind) yet." : "No \(kind) for \(model.activityPersonLabel)."
        }
        let scope = model.activityPersonLabel.isEmpty ? "on the account" : "for \(model.activityPersonLabel)"
        return "\(model.crumbTotal) \(kind) \(scope). Newest first."
    }

    private var fieldsPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extra facts stored on a person, such as their Salesforce contact id.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
            ForEach(model.fields, id: \.selfID) { field in
                rowButton(
                    title: JSON.string(field["label"]).ifEmpty(JSON.string(field["key"])),
                    subtitle: "\(JSON.string(field["collection"])) · \(JSON.string(field["data_type"])) · \(JSON.string(field["key"]))"
                , selected: sameRow(field)) { model.select(field) }
            }
        }
    }

    private var webhooksPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This is the link that sends new and updated people to Salesforce. The signing secret stays hidden.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
            ForEach(model.webhooks, id: \.selfID) { hook in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill((JSON.bool(hook["is_active"]) == true && JSON.int(hook["consecutive_failures"]) == 0) ? Color.green : DeskTheme.copper)
                            .frame(width: 8, height: 8)
                        Text(JSON.string(hook["name"]))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(JSON.bool(hook["is_active"]) == true ? "Running" : "Paused")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Text(JSON.string(hook["target_url"]))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .textSelection(.enabled)
                    Text(hookEvents(hook))
                        .font(.system(size: 12))
                        .foregroundStyle(DeskTheme.copper)
                    Text("\(JSON.int(hook["num_success"])) delivered · \(JSON.int(hook["num_failure"])) failed · \(JSON.int(hook["consecutive_failures"])) in a row recently")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                    if !JSON.string(hook["last_error"]).isEmpty {
                        Text(friendlyError(JSON.string(hook["last_error"])))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    HStack {
                        if JSON.bool(hook["is_active"]) == true {
                            QuietButton(title: "Pause") { model.setWebhookActive(hook, active: false) }
                        } else {
                            QuietButton(title: "Turn on") { model.setWebhookActive(hook, active: true) }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: 640, alignment: .leading)
                .background(DeskTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func statButton(_ label: String, _ value: String, _ section: DeskSection) -> some View {
        Button {
            model.section = section
            model.selected = [:]
            if section == .activity {
                model.flavor = "donation"
                model.activityPersonID = ""
                model.activityPersonLabel = ""
                model.crumbs = []
                model.crumbTotal = 0
            }
        } label: {
            stat(label, value)
        }
        .buttonStyle(.plain)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DeskTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func field(_ placeholder: String, text: Binding<String>, onSubmit: (() -> Void)? = nil) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onSubmit { onSubmit?() }
    }

    private func rowButton(title: String, subtitle: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.isEmpty ? "Untitled" : title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? DeskTheme.ink : .white.opacity(0.92))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(selected ? DeskTheme.ink.opacity(0.7) : .white.opacity(0.4))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selected ? DeskTheme.copper : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func sameRow(_ row: [String: Any]) -> Bool {
        let id = JSON.string(row["id"])
        return !id.isEmpty && id == JSON.string(model.selected["id"])
    }

    private var selectedIsTag: Bool {
        model.tags.contains { JSON.string($0["id"]) == JSON.string(model.selected["id"]) } && model.selected["email"] == nil && model.selected["target_url"] == nil
    }

    private var emptyDetail: String {
        switch model.section {
        case .people: return "Find someone and their name, tags, and last visit show up here."
        case .tags: return "Click a tag to see it and rename it."
        case .campaigns: return "Click a campaign to see its dates and status."
        case .activity: return "Click a row to see who it was and when."
        case .webhooks: return "Sync status is on the card."
        default: return "Click something in the list to see it here."
        }
    }

    private var detailRows: [DetailRow] {
        let row = model.selected
        var lines: [DetailRow] = []
        func add(_ label: String, _ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != "—" else { return }
            lines.append(DetailRow(label: label, value: trimmed))
        }
        if JSON.string(row["email"]).contains("@") && row["flavor"] == nil {
            add("Name", personTitle(row))
            add("Email", JSON.string(row["email"]))
            add("Phone", JSON.string(row["phone"]))
            add("Last seen", JSON.shortDate(JSON.string(row["date_last_seen"])))
            let tags = JSON.strings(row["tag_ids"]).map { model.tagName($0) }.joined(separator: ", ")
            add("Tags", tags)
        } else if row["flavor"] != nil {
            add("Email", JSON.string(row["email"]))
            add("What happened", ActivityKind.label(for: JSON.string(row["flavor"])))
            add("When", JSON.shortDate(JSON.string(row["created_at"])))
            add("Project", model.projectName(JSON.string(row["project_id"])))
        } else if row["kind"] != nil {
            add("Campaign", JSON.string(row["name"]))
            add("Status", plainState(JSON.string(row["state"])))
            add("Type", plainKind(JSON.string(row["kind"])))
            add("Project", model.projectName(JSON.string(row["project_id"])))
            add("Starts", JSON.shortDate(JSON.string(row["date_start"])))
            add("Ends", JSON.shortDate(JSON.string(row["date_end"])))
        } else if row["target_url"] != nil {
            add("Name", JSON.string(row["name"]))
            add("Status", JSON.bool(row["is_active"]) == true ? "Running" : "Paused")
            add("Sends", hookEvents(row))
            add("Last try", JSON.shortDate(JSON.string(row["last_delivery_at"])))
            add("Last problem", friendlyError(JSON.string(row["last_error"])))
        } else if row["context"] != nil {
            add("Tag", JSON.string(row["name"]))
            add("Created", JSON.shortDate(JSON.string(row["date_created"])))
        } else if row["site_url"] != nil || (row["name"] != nil && row["location"] != nil) {
            add("Project", JSON.string(row["name"]))
            add("Website", JSON.string(row["site_url"]))
        } else if row["collection"] != nil {
            add("Field", JSON.string(row["label"]).ifEmpty(JSON.string(row["key"])))
            add("On", JSON.string(row["collection"]))
            add("Used as", JSON.string(row["key"]))
        }
        return lines
    }

    private func personTitle(_ row: [String: Any]) -> String {
        let name = [JSON.string(row["first_name"]), JSON.string(row["last_name"])]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? JSON.string(row["email"]) : name
    }

    private func personSubtitle(_ row: [String: Any]) -> String {
        let name = [JSON.string(row["first_name"]), JSON.string(row["last_name"])]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name
    }

    private func plainState(_ raw: String) -> String {
        switch raw {
        case "published": return "Sending"
        case "draft": return "Draft"
        case "stopped": return "Stopped"
        case "paused": return "Paused"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func plainKind(_ raw: String) -> String {
        switch raw {
        case "email": return "Email"
        case "auto_send", "autosend": return "Auto send"
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func hookEvents(_ hook: [String: Any]) -> String {
        JSON.strings(hook["events"]).map { event in
            switch event {
            case "person.created": return "New people"
            case "person.updated": return "Updated people"
            default: return event.replacingOccurrences(of: ".", with: " ")
            }
        }.joined(separator: " and ")
    }

    private func friendlyError(_ raw: String) -> String {
        if raw.localizedCaseInsensitiveContains("connect") {
            return "Feathr could not connect to the website."
        }
        return raw
    }

    private func syncExplanation(_ hook: [String: Any]) -> String {
        let failures = JSON.int(hook["consecutive_failures"])
        if JSON.bool(hook["is_active"]) != true {
            if failures > 0 {
                return "It is paused after \(failures) deliveries in a row could not reach the website. Leave it paused until that connection works."
            }
            return "People are not being sent to Salesforce right now."
        }
        if failures > 0 {
            return "It is on, and the last \(failures) deliveries could not reach the website."
        }
        return "New and updated people are being sent to Salesforce."
    }

    private func copy(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            copied = false
        }
    }
}

private struct DetailRow: Identifiable {
    var label: String
    var value: String
    var id: String { label }
}

struct FlowChips: View {
    let items: [String]
    var body: some View {
        FlexibleWrap(items: items)
    }
}

struct FlexibleWrap: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var rows: [[String]] {
        var result: [[String]] = []
        var current: [String] = []
        for item in items {
            current.append(item)
            if current.count == 3 {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

struct KeySheet: View {
    @ObservedObject var model: DeskModel
    @Environment(\.dismiss) private var dismiss
    @State private var pasted = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeskBadge(text: "KEY", size: 11)
            Text("The key stays in the Keychain.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(model.keySource.isEmpty ? "Nothing stored yet." : model.keySource)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            SecureField("fthr_…", text: $pasted)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Save") {
                    Task {
                        await model.replaceKey(pasted)
                        pasted = ""
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                Button("Cancel") { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

private extension Dictionary where Key == String, Value == Any {
    var selfID: String { JSON.string(self["id"]).ifEmpty(JSON.string(self["key"])).ifEmpty(JSON.string(self["email"])) }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
