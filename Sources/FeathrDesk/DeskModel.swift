import Foundation
import SwiftUI

enum ActivityKind: String, CaseIterable, Identifiable {
    case donation
    case form
    case emailClick = "email_link_click"
    case trackedClick = "pinpoint_tracked_email_click"
    case pageView = "page_view"
    case custom

    var id: String { rawValue }

    var flavor: String {
        switch self {
        case .donation: return "donation"
        case .form: return "form_submission"
        default: return rawValue
        }
    }

    var label: String {
        switch self {
        case .donation: return "Gifts"
        case .form: return "Form fills"
        case .emailClick: return "Email clicks"
        case .trackedClick: return "Tracked email clicks"
        case .pageView: return "Page views"
        case .custom: return "Custom"
        }
    }

    static func label(for flavor: String) -> String {
        allCases.first { $0.flavor == flavor }?.label ?? flavor.replacingOccurrences(of: "_", with: " ")
    }
}

enum DeskSection: String, CaseIterable, Identifiable {
    case desk = "Desk"
    case people = "People"
    case tags = "Tags"
    case campaigns = "Campaigns"
    case projects = "Projects"
    case activity = "Activity"
    case fields = "Fields"
    case webhooks = "Webhooks"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .desk: return "square.grid.2x2"
        case .people: return "person"
        case .tags: return "tag"
        case .campaigns: return "envelope"
        case .projects: return "folder"
        case .activity: return "point.topleft.down.to.point.bottomright.curvepath"
        case .fields: return "list.bullet.rectangle"
        case .webhooks: return "arrow.left.arrow.right"
        }
    }

    var hasSearch: Bool { self == .people || self == .tags || self == .campaigns }
}

enum RowKind {
    case person, crumb, campaign, webhook, tag, project, field, unknown
}

struct NoteLine: Identifiable {
    let id = UUID()
    let time: Date
    let text: String
}

struct PendingWrite: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let button: String
    let run: () async -> Void
}

struct SyncHealth {
    enum Level { case good, warning, problem, none }
    var level: Level
    var headline: String
    var detail: String
    var hook: [String: Any]?
}

@MainActor
final class DeskModel: ObservableObject {
    static let activityPageSize = 40

    @Published var section: DeskSection = .desk
    @Published var busy = false
    @Published var status = "Looking for the Feathr key."
    @Published var keySource = ""
    @Published var me: [String: Any] = [:]
    @Published var tags: [[String: Any]] = []
    @Published var campaigns: [[String: Any]] = []
    @Published var projects: [[String: Any]] = []
    @Published var fields: [[String: Any]] = []
    @Published var webhooks: [[String: Any]] = []
    @Published var recentGifts: [[String: Any]] = []
    @Published var lastRefresh: Date?
    @Published var crumbs: [[String: Any]] = []
    @Published var crumbTotal = 0
    @Published var crumbPage = 0
    @Published var loadingMore = false
    @Published var flavor = "donation"
    @Published var people: [[String: Any]] = []
    @Published var selected: [String: Any] = [:]
    @Published var notes: [NoteLine] = []
    @Published var pending: PendingWrite?
    @Published var errorText: String?
    @Published var rate: RateSnapshot?
    @Published var focusRequest: DeskSection?

    @Published var personQuery = ""
    @Published var tagQuery = ""
    @Published var campaignQuery = ""
    @Published var campaignState = ""
    @Published var campaignKind = ""
    @Published var newTagName = ""
    @Published var renameTag = ""
    @Published var draftFirst = ""
    @Published var draftLast = ""
    @Published var draftPhone = ""
    @Published var draftEmail = ""
    @Published var createFirst = ""
    @Published var createLast = ""
    @Published var createPhone = ""
    @Published var tagToApply = ""
    @Published var activityPersonID = ""
    @Published var activityPersonLabel = ""

    private var api: FeathrAPI?
    private var base = "https://api.feathr.co"
    private var activityGeneration = 0
    private var activityLoadScheduled = false

    var scopes: [String] { JSON.strings(me["scopes"]) }
    var canWritePeople: Bool { scopes.contains("persons:write") }
    var canWriteTags: Bool { scopes.contains("tags:write") }
    var canWriteHooks: Bool { scopes.contains("webhooks:write") }
    var connected: Bool { api != nil && !me.isEmpty }

    var serviceName: String { JSON.string(me["service_name"]).ifEmpty("Feathr") }
    var lastFour: String { JSON.string(me["last_four"]) }
    var canLoadMoreActivity: Bool { !crumbs.isEmpty && crumbs.count < crumbTotal }

    /// Rate limit from response headers, falling back to the `/me` payload.
    var rateRemaining: Int? {
        if let remaining = rate?.remaining { return remaining }
        if let info = me["rate_limit"] as? [String: Any], info["remaining"] != nil { return JSON.int(info["remaining"]) }
        return nil
    }

    var rateLimitedUntil: Date? {
        guard let at = rate?.limitedAt else { return nil }
        let until = at.addingTimeInterval(TimeInterval(rate?.retryAfter ?? 60))
        return until > Date() ? until : nil
    }

    // MARK: - Boot and refresh

    func boot() async {
        if let stored = KeyStore.load() {
            api = makeAPI(stored)
            keySource = "Keychain"
        } else if let env = KeyStore.readControlEnv() {
            base = env.base
            do {
                try KeyStore.save(env.key)
                api = makeAPI(env.key)
                keySource = "Feathr Control, saved to Keychain"
            } catch {
                api = makeAPI(env.key)
                keySource = "Feathr Control .env"
            }
        } else {
            status = "No Feathr key yet."
            return
        }
        await refreshDesk()
    }

    func replaceKey(_ raw: String) async {
        do {
            try KeyStore.save(raw)
            api = makeAPI(raw.trimmingCharacters(in: .whitespacesAndNewlines))
            keySource = "Keychain"
            rate = nil
            await refreshDesk()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func makeAPI(_ key: String) -> FeathrAPI {
        var client = FeathrAPI(base: base, key: key)
        client.onRate = { [weak self] snapshot in
            Task { @MainActor in self?.rate = snapshot }
        }
        return client
    }

    /// Cmd+R: reload the reference lists, and the current activity list when on Activity.
    func refreshAll() async {
        await refreshDesk()
        if section == .activity { await loadActivity() }
    }

    func refreshDesk() async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            me = try await api.get("/me")
            async let tagPage = api.paginate("/tags")
            async let campaignPage = api.paginate("/campaigns")
            async let projectPage = api.paginate("/projects")
            async let fieldPage = api.paginate("/custom-fields")
            async let hookPage = api.paginate("/webhooks", pageSize: 50, maxPages: 2)
            tags = try await tagPage.items
            campaigns = try await campaignPage.items
            projects = try await projectPage.items
            fields = try await fieldPage.items
            webhooks = try await hookPage.items
            status = "Connected"
            lastRefresh = Date()
            note("Desk refreshed. \(tags.count) tags, \(campaigns.count) campaigns, \(projects.count) projects.")
            if selected.isEmpty == false {
                reselect()
            }
        } catch {
            errorText = error.localizedDescription
            status = (error as? FeathrError)?.status == 401 ? "Feathr did not accept the key." : "Feathr did not answer."
            return
        }
        if let gifts = try? await api.get("/breadcrumbs", query: ["flavor": "donation", "page": "1", "size": "5"]) {
            recentGifts = JSON.array(gifts["items"])
        }
    }

    // MARK: - Activity

    func loadActivity() async {
        guard let api else { return }
        activityGeneration += 1
        let generation = activityGeneration
        busy = true
        defer { if generation == activityGeneration { busy = false } }
        do {
            let page = try await api.get("/breadcrumbs", query: activityQuery(page: 1))
            guard generation == activityGeneration else { return }
            crumbs = JSON.array(page["items"])
            crumbTotal = JSON.int(page["total"])
            crumbPage = 1
            let who = activityPersonLabel.isEmpty ? "the account" : activityPersonLabel
            note("Loaded \(ActivityKind.label(for: flavor).lowercased()) for \(who).")
        } catch {
            guard generation == activityGeneration else { return }
            errorText = error.localizedDescription
        }
    }

    func loadMoreActivity() async {
        guard let api, canLoadMoreActivity, !loadingMore else { return }
        let generation = activityGeneration
        let next = crumbPage + 1
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await api.get("/breadcrumbs", query: activityQuery(page: next))
            guard generation == activityGeneration else { return }
            let batch = JSON.array(page["items"])
            let known = Set(crumbs.map { JSON.string($0["id"]) })
            crumbs.append(contentsOf: batch.filter { !known.contains(JSON.string($0["id"])) || JSON.string($0["id"]).isEmpty })
            crumbTotal = JSON.int(page["total"])
            crumbPage = next
            if batch.isEmpty { crumbTotal = crumbs.count }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func activityQuery(page: Int) -> [String: String] {
        var query = ["flavor": flavor, "page": String(page), "size": String(Self.activityPageSize)]
        if !activityPersonID.isEmpty { query["person_id"] = activityPersonID }
        return query
    }

    /// Coalesces the several UI triggers for one user action into a single request.
    func scheduleActivityLoad() {
        guard !activityLoadScheduled else { return }
        activityLoadScheduled = true
        Task {
            await Task.yield()
            activityLoadScheduled = false
            await loadActivity()
        }
    }

    func showActivity(flavor: String, personID: String = "", label: String = "") {
        self.flavor = flavor
        activityPersonID = personID
        activityPersonLabel = label
        crumbs = []
        crumbTotal = 0
        crumbPage = 0
        selected = [:]
        section = .activity
        scheduleActivityLoad()
    }

    /// Opens the person behind a breadcrumb or gift row in People.
    func openPerson(from crumb: [String: Any]) async {
        guard let api else { return }
        let id = JSON.string(crumb["person_id"])
        let email = JSON.string(crumb["email"]).lowercased()
        busy = true
        defer { busy = false }
        do {
            var person: [String: Any] = [:]
            if !id.isEmpty {
                person = try await api.get("/persons/\(id)")
            } else if email.contains("@") {
                let page = try await api.get("/persons", query: ["email": email, "page": "1", "size": "1"])
                person = JSON.array(page["items"]).first ?? [:]
            }
            guard !person.isEmpty else {
                errorText = "This activity is not linked to a person Feathr can find."
                return
            }
            people = [person]
            personQuery = JSON.string(person["email"]).ifEmpty(JSON.string(person["id"]))
            section = .people
            selected = person
            fillDrafts()
            note("Opened \(JSON.string(person["email"]).ifEmpty("person")) from activity.")
        } catch {
            errorText = error.localizedDescription
        }
    }

    func personActivity(from crumb: [String: Any]) {
        let id = JSON.string(crumb["person_id"])
        guard !id.isEmpty else {
            errorText = "This activity is not linked to a person id."
            return
        }
        showActivity(flavor: flavor, personID: id, label: JSON.string(crumb["email"]).ifEmpty("this person"))
    }

    // MARK: - People

    func searchPeople() async {
        guard let api else { return }
        let query = personQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            if query.contains("@") {
                let page = try await api.get("/persons", query: ["email": query.lowercased(), "page": "1", "size": "10"])
                people = JSON.array(page["items"])
            } else if query.count >= 20 {
                let person = try await api.get("/persons/\(query)")
                people = [person]
            } else {
                errorText = "Search with an email, or paste a person id."
                return
            }
            selected = people.first ?? [:]
            fillDrafts()
            note(people.isEmpty ? "No person for that search." : "Found \(people.count) person\(people.count == 1 ? "" : "s").")
        } catch let error as FeathrError where error.status == 404 {
            people = []
            selected = [:]
            note("No person with that id.")
        } catch {
            errorText = error.localizedDescription
        }
    }

    func select(_ row: [String: Any]) {
        selected = row
        fillDrafts()
        if kind(of: row) == .tag {
            renameTag = JSON.string(row["name"])
        }
    }

    func kind(of row: [String: Any]) -> RowKind {
        if row.isEmpty { return .unknown }
        if row["flavor"] != nil { return .crumb }
        let id = JSON.string(row["id"])
        func listed(_ pool: [[String: Any]]) -> Bool { !id.isEmpty && pool.contains { JSON.string($0["id"]) == id } }
        if listed(webhooks) || row["target_url"] != nil { return .webhook }
        if listed(fields) || row["collection"] != nil { return .field }
        if listed(campaigns) { return .campaign }
        if listed(tags) { return .tag }
        if listed(projects) { return .project }
        if JSON.string(row["email"]).contains("@") || row["first_name"] != nil || row["custom_fields"] != nil { return .person }
        if row["context"] != nil { return .tag }
        if row["kind"] != nil { return .campaign }
        if row["site_url"] != nil { return .project }
        return .unknown
    }

    func confirm(_ title: String, _ detail: String, button: String, run: @escaping () async -> Void) {
        pending = PendingWrite(title: title, detail: detail, button: button, run: run)
    }

    func savePerson() {
        guard let id = selected["id"] as? String, canWritePeople else { return }
        let body: [String: Any] = [
            "first_name": draftFirst.trimmingCharacters(in: .whitespaces),
            "last_name": draftLast.trimmingCharacters(in: .whitespaces),
            "phone": draftPhone.trimmingCharacters(in: .whitespaces),
        ]
        confirm("Save this person?", "Updates the name and phone for \(JSON.string(selected["email"])).", button: "Save") {
            await self.writePerson(id: id, body: body)
        }
    }

    func createPerson() {
        let email = draftEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.contains("@"), canWritePeople else {
            errorText = "A new person needs an email."
            return
        }
        confirm("Add \(email)?", "Creates a Feathr person. This does not send them an email.", button: "Create") {
            await self.createPersonNow(email: email)
        }
    }

    func applyTag() {
        guard let personID = selected["id"] as? String, !tagToApply.isEmpty, canWriteTags else { return }
        let tagID = tagToApply
        if JSON.tagIDs(selected).contains(tagID) {
            errorText = "\(JSON.string(selected["email"])) already has \(tagName(tagID))."
            return
        }
        confirm("Add \(tagName(tagID))?", "Tags \(JSON.string(selected["email"])).", button: "Add tag") {
            await self.addTag(personID: personID, tagID: tagID)
        }
    }

    func removeTag(_ tagID: String) {
        guard let personID = selected["id"] as? String, canWriteTags, canWritePeople else { return }
        let email = JSON.string(selected["email"])
        let remaining = JSON.tagIDs(selected).filter { $0 != tagID }
        confirm(
            "Remove \(tagName(tagID))?",
            "Takes the tag off \(email). The tag itself stays, and everyone else keeps it. The desk checks afterward that Feathr actually removed it.",
            button: "Remove tag"
        ) {
            await self.removeTagNow(personID: personID, tagID: tagID, remaining: remaining)
        }
    }

    // MARK: - Tags and webhooks

    func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, canWriteTags else { return }
        if tags.contains(where: { JSON.string($0["name"]).caseInsensitiveCompare(name) == .orderedSame }) {
            errorText = "A tag named “\(name)” already exists."
            return
        }
        confirm("Create “\(name)”?", "The tag starts empty. You add people to it afterward.", button: "Create tag") {
            await self.createTagNow(name)
        }
    }

    func renameSelectedTag() {
        guard let id = selected["id"] as? String, canWriteTags else { return }
        let name = renameTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != JSON.string(selected["name"]) else { return }
        confirm("Rename this tag?", "Everyone who has it keeps it. The new name is \(name).", button: "Rename") {
            await self.renameTagNow(id: id, name: name)
        }
    }

    func setWebhookActive(_ hook: [String: Any], active: Bool) {
        guard canWriteHooks, let id = hook["id"] as? String else { return }
        let name = JSON.string(hook["name"])
        let detail = active
            ? "Feathr will start sending people to the website again. Leave it off if those deliveries are still failing."
            : "Feathr will stop sending people to Salesforce until you turn it back on."
        confirm(active ? "Turn sync back on?" : "Pause Salesforce sync?", detail, button: active ? "Turn on" : "Pause") {
            await self.patchWebhook(id: id, active: active, name: name, url: JSON.string(hook["target_url"]), events: JSON.strings(hook["events"]))
        }
    }

    // MARK: - Lookups

    func tagName(_ id: String) -> String {
        tags.first { JSON.string($0["id"]) == id }.map { JSON.string($0["name"]) } ?? id
    }

    func projectName(_ id: String) -> String {
        guard !id.isEmpty else { return "—" }
        return projects.first { JSON.string($0["id"]) == id }.map { JSON.string($0["name"]) } ?? String(id.suffix(6))
    }

    func campaignName(_ id: String) -> String {
        guard !id.isEmpty else { return "" }
        return campaigns.first { JSON.string($0["id"]) == id }.map { JSON.string($0["name"]) } ?? "Campaign …\(id.suffix(6))"
    }

    func fieldLabel(_ key: String) -> String {
        fields.first { JSON.string($0["key"]) == key || JSON.string($0["id"]) == key }
            .map { JSON.string($0["label"]).ifEmpty(key) } ?? key
    }

    /// Custom field values on a person, in label order. Only fields Feathr actually returned.
    func customFieldRows(_ person: [String: Any]) -> [(label: String, value: String)] {
        let values = JSON.object(person["custom_fields"])
        return values.compactMap { key, value -> (String, String)? in
            let text = JSON.display(value)
            return text.isEmpty ? nil : (fieldLabel(key), text)
        }
        .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    var campaignStates: [String] { Array(Set(campaigns.map { JSON.string($0["state"]) }.filter { !$0.isEmpty })).sorted() }
    var campaignKinds: [String] { Array(Set(campaigns.map { JSON.string($0["kind"]) }.filter { !$0.isEmpty })).sorted() }

    func campaignCount(state: String? = nil, kind: String? = nil) -> Int {
        campaigns.filter { row in
            (state == nil || JSON.string(row["state"]) == state) && (kind == nil || JSON.string(row["kind"]) == kind)
        }.count
    }

    var filteredCampaigns: [[String: Any]] {
        let q = campaignQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return campaigns
            .filter { campaignState.isEmpty || JSON.string($0["state"]) == campaignState }
            .filter { campaignKind.isEmpty || JSON.string($0["kind"]) == campaignKind }
            .filter { q.isEmpty || JSON.string($0["name"]).lowercased().contains(q) || projectName(JSON.string($0["project_id"])).lowercased().contains(q) }
            .sorted { JSON.string($0["name"]).localizedCaseInsensitiveCompare(JSON.string($1["name"])) == .orderedAscending }
    }

    var syncHealth: SyncHealth {
        guard let hook = webhooks.first(where: { JSON.string($0["target_url"]).localizedCaseInsensitiveContains("salesforce") }) ?? webhooks.first else {
            return SyncHealth(level: .none, headline: "No Salesforce sync link", detail: connected ? "Feathr has no webhook set up on this account, so people are not sent to Salesforce automatically." : "Connect a key to check sync.", hook: nil)
        }
        let active = JSON.bool(hook["is_active"]) == true
        let streak = JSON.int(hook["consecutive_failures"])
        let lastTry = JSON.string(hook["last_delivery_at"])
        let when = lastTry.isEmpty ? "" : " Last attempt \(JSON.relative(lastTry))."
        if !active {
            let why = streak > 0 ? "It stopped after \(streak) deliveries in a row could not reach the website." : "People are not being sent to Salesforce right now."
            return SyncHealth(level: .problem, headline: "Salesforce sync is paused", detail: why + when, hook: hook)
        }
        if streak > 0 {
            return SyncHealth(level: .warning, headline: "Salesforce sync is on, but failing", detail: "The last \(streak) deliver\(streak == 1 ? "y" : "ies") could not reach the website.\(when)", hook: hook)
        }
        return SyncHealth(level: .good, headline: "Salesforce sync is on", detail: "New and updated people are being sent to Salesforce.\(when)", hook: hook)
    }

    func requestFocus(_ target: DeskSection? = nil) {
        let destination = target ?? (section.hasSearch ? section : .people)
        if section != destination {
            section = destination
            selected = [:]
        }
        focusRequest = destination
    }

    func go(_ destination: DeskSection) {
        section = destination
        selected = [:]
    }

    // MARK: - Writes

    private func writePerson(id: String, body: [String: Any]) async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            let updated = try await api.send("PATCH", "/persons/\(id)", body: body)
            replacePerson(updated, id: id)
            fillDrafts()
            note("Saved person \(JSON.string(updated["email"])).")
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func createPersonNow(email: String) async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            var body: [String: Any] = ["email": email]
            if !createFirst.trimmingCharacters(in: .whitespaces).isEmpty { body["first_name"] = createFirst.trimmingCharacters(in: .whitespaces) }
            if !createLast.trimmingCharacters(in: .whitespaces).isEmpty { body["last_name"] = createLast.trimmingCharacters(in: .whitespaces) }
            if !createPhone.trimmingCharacters(in: .whitespaces).isEmpty { body["phone"] = createPhone.trimmingCharacters(in: .whitespaces) }
            let created = try await api.send("POST", "/persons", body: body)
            people = [created]
            selected = created
            personQuery = email
            draftEmail = ""
            createFirst = ""
            createLast = ""
            createPhone = ""
            fillDrafts()
            note("Created \(email).")
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func addTag(personID: String, tagID: String) async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await api.send("POST", "/persons/\(personID)/tags", body: ["tag_ids": [tagID]])
            let updated = try await api.get("/persons/\(personID)")
            replacePerson(updated, id: personID)
            note("Tagged \(JSON.string(updated["email"])) with \(tagName(tagID)).")
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func removeTagNow(personID: String, tagID: String, remaining: [String]) async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await api.send("PATCH", "/persons/\(personID)", body: ["tag_ids": remaining])
            let updated = try await api.get("/persons/\(personID)")
            replacePerson(updated, id: personID)
            if JSON.tagIDs(updated).contains(tagID) {
                errorText = "Feathr accepted the request but kept \(tagName(tagID)) on this person. The API may not support removing tags yet. Remove it in Feathr instead."
                note("Tag \(tagName(tagID)) is still on \(JSON.string(updated["email"])).")
            } else {
                note("Removed \(tagName(tagID)) from \(JSON.string(updated["email"])).")
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func createTagNow(_ name: String) async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            let created = try await api.send("POST", "/tags", body: ["name": name, "context": "person"])
            tags.insert(created, at: 0)
            tags.sort { JSON.string($0["name"]).localizedCaseInsensitiveCompare(JSON.string($1["name"])) == .orderedAscending }
            selected = created
            newTagName = ""
            renameTag = name
            note("Created tag \(name).")
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func renameTagNow(id: String, name: String) async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            let updated = try await api.send("PATCH", "/tags/\(id)", body: ["name": name])
            if let index = tags.firstIndex(where: { JSON.string($0["id"]) == id }) {
                tags[index] = updated
            }
            selected = updated
            note("Renamed tag to \(name).")
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func patchWebhook(id: String, active: Bool, name: String, url: String, events: [String]) async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            let updated = try await api.send("PATCH", "/webhooks/\(id)", body: [
                "name": name,
                "target_url": url,
                "events": events,
                "is_active": active,
            ])
            if let index = webhooks.firstIndex(where: { JSON.string($0["id"]) == id }) {
                webhooks[index] = updated
            }
            selected = updated
            note(active ? "Turned \(name) on." : "Paused \(name).")
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func replacePerson(_ updated: [String: Any], id: String) {
        if JSON.string(selected["id"]) == id {
            selected = updated
        }
        if let index = people.firstIndex(where: { JSON.string($0["id"]) == id }) {
            people[index] = updated
        }
    }

    private func fillDrafts() {
        draftFirst = JSON.string(selected["first_name"])
        draftLast = JSON.string(selected["last_name"])
        draftPhone = JSON.string(selected["phone"])
        if tagToApply.isEmpty || !tags.contains(where: { JSON.string($0["id"]) == tagToApply }) {
            tagToApply = tags.first.map { JSON.string($0["id"]) } ?? ""
        }
    }

    private func reselect() {
        let id = JSON.string(selected["id"])
        guard !id.isEmpty else { return }
        let pools = [people, tags, campaigns, projects, fields, webhooks, crumbs]
        if let match = pools.lazy.compactMap({ pool in pool.first { JSON.string($0["id"]) == id } }).first {
            selected = match
        }
    }

    func note(_ text: String) {
        notes.insert(NoteLine(time: Date(), text: text), at: 0)
        if notes.count > 40 { notes.removeLast(notes.count - 40) }
    }
}
