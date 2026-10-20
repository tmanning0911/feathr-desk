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

@MainActor
final class DeskModel: ObservableObject {
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
    @Published var crumbs: [[String: Any]] = []
    @Published var crumbTotal = 0
    @Published var flavor = "donation"
    @Published var people: [[String: Any]] = []
    @Published var selected: [String: Any] = [:]
    @Published var notes: [NoteLine] = []
    @Published var pending: PendingWrite?
    @Published var errorText: String?

    @Published var personQuery = ""
    @Published var tagQuery = ""
    @Published var campaignQuery = ""
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

    var scopes: [String] { JSON.strings(me["scopes"]) }
    var canWritePeople: Bool { scopes.contains("persons:write") }
    var canWriteTags: Bool { scopes.contains("tags:write") }
    var canWriteHooks: Bool { scopes.contains("webhooks:write") }

    var serviceName: String { JSON.string(me["service_name"]).ifEmpty("Feathr") }
    var lastFour: String { JSON.string(me["last_four"]) }

    func boot() async {
        if let stored = KeyStore.load() {
            api = FeathrAPI(base: base, key: stored)
            keySource = "Keychain"
        } else if let env = KeyStore.readControlEnv() {
            base = env.base
            do {
                try KeyStore.save(env.key)
                api = FeathrAPI(base: base, key: env.key)
                keySource = "Feathr Control, saved to Keychain"
            } catch {
                api = FeathrAPI(base: base, key: env.key)
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
            api = FeathrAPI(base: base, key: raw.trimmingCharacters(in: .whitespacesAndNewlines))
            keySource = "Keychain"
            await refreshDesk()
        } catch {
            errorText = error.localizedDescription
        }
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
            note("Desk refreshed. \(tags.count) tags, \(campaigns.count) campaigns, \(projects.count) projects.")
            if selected.isEmpty == false {
                reselect()
            }
        } catch {
            errorText = error.localizedDescription
            status = "Feathr did not answer."
        }
    }

    func loadActivity() async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            var query = ["flavor": flavor]
            if !activityPersonID.isEmpty {
                query["person_id"] = activityPersonID
            }
            let page = try await api.get("/breadcrumbs", query: query.merging(["page": "1", "size": "40"]) { $1 })
            crumbs = JSON.array(page["items"])
            crumbTotal = JSON.int(page["total"])
            let who = activityPersonLabel.isEmpty ? "the account" : activityPersonLabel
            note("Loaded \(ActivityKind.label(for: flavor).lowercased()) for \(who).")
        } catch {
            errorText = error.localizedDescription
        }
    }

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
        } catch {
            errorText = error.localizedDescription
        }
    }

    func select(_ row: [String: Any]) {
        selected = row
        fillDrafts()
        if JSON.string(row["context"]) == "person" || tags.contains(where: { JSON.string($0["id"]) == JSON.string(row["id"]) && JSON.string(row["name"]) == JSON.string($0["name"]) && row["email"] == nil && row["kind"] == nil && row["flavor"] == nil && row["collection"] == nil && row["target_url"] == nil }) {
            renameTag = JSON.string(row["name"])
        }
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
        let name = tags.first { JSON.string($0["id"]) == tagToApply }.map { JSON.string($0["name"]) } ?? tagToApply
        confirm("Add \(name)?", "Tags \(JSON.string(selected["email"])).", button: "Add tag") {
            await self.addTag(personID: personID, tagID: self.tagToApply)
        }
    }

    func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, canWriteTags else { return }
        confirm("Create “\(name)”?", "The tag starts empty. You add people to it afterward.", button: "Create tag") {
            await self.createTagNow(name)
        }
    }

    func renameSelectedTag() {
        guard let id = selected["id"] as? String, canWriteTags else { return }
        let name = renameTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
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

    func tagName(_ id: String) -> String {
        tags.first { JSON.string($0["id"]) == id }.map { JSON.string($0["name"]) } ?? id
    }

    func projectName(_ id: String) -> String {
        guard !id.isEmpty else { return "—" }
        return projects.first { JSON.string($0["id"]) == id }.map { JSON.string($0["name"]) } ?? String(id.suffix(6))
    }

    private func writePerson(id: String, body: [String: Any]) async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            let updated = try await api.send("PATCH", "/persons/\(id)", body: body)
            selected = updated
            if let index = people.firstIndex(where: { JSON.string($0["id"]) == id }) {
                people[index] = updated
            }
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
            selected = updated
            if let index = people.firstIndex(where: { JSON.string($0["id"]) == personID }) {
                people[index] = updated
            }
            note("Tagged \(JSON.string(updated["email"])) with \(tagName(tagID)).")
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

    private func fillDrafts() {
        draftFirst = JSON.string(selected["first_name"])
        draftLast = JSON.string(selected["last_name"])
        draftPhone = JSON.string(selected["phone"])
        if tagToApply.isEmpty {
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

    private func note(_ text: String) {
        notes.insert(NoteLine(time: Date(), text: text), at: 0)
        if notes.count > 40 { notes.removeLast(notes.count - 40) }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
