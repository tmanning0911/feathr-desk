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

    var symbol: String {
        switch self {
        case .donation: return "gift"
        case .form: return "doc.text"
        case .emailClick: return "envelope.open"
        case .trackedClick: return "cursorarrow.click"
        case .pageView: return "eye"
        case .custom: return "sparkle"
        }
    }

    static func label(for flavor: String) -> String {
        allCases.first { $0.flavor == flavor }?.label ?? flavor.replacingOccurrences(of: "_", with: " ")
    }

    static func symbol(for flavor: String) -> String {
        allCases.first { $0.flavor == flavor }?.symbol ?? "circle"
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

    var shortcut: String {
        let index = (Self.allCases.firstIndex(of: self) ?? 0) + 1
        return "⌘\(index)"
    }

    var hasSearch: Bool { self == .people || self == .tags || self == .campaigns }
}

enum RowKind {
    case person, crumb, campaign, webhook, tag, project, field, unknown
}

enum CampaignSort: String, CaseIterable, Identifiable {
    case name = "Name"
    case newest = "Newest start"
    var id: String { rawValue }
}

enum DeskPhase {
    case lookingForKey, noKey, connecting, connected, keyRejected, unreachable
}

struct NoteLine: Identifiable {
    let id = UUID()
    let time: Date
    let text: String
}

struct PendingWrite: Identifiable {
    enum Tone { case standard, caution }

    let id = UUID()
    let title: String
    let detail: String
    let button: String
    var tone: Tone = .standard
    var points: [String] = []
    /// When set, the confirm button stays disabled until this statement is checked.
    var acknowledge: String? = nil
    let run: () async -> Void
}

struct SyncHealth {
    enum Level { case good, warning, problem, none }
    var level: Level
    var headline: String
    var detail: String
    var hook: [String: Any]?

    static func of(_ hook: [String: Any]) -> SyncHealth {
        let name = Plain.hookTitle(hook)
        let destination = Plain.destination(hook)
        let active = JSON.bool(hook["is_active"]) == true
        let streak = JSON.int(hook["consecutive_failures"])
        let lastTry = JSON.string(hook["last_delivery_at"])
        let when = lastTry.isEmpty ? "" : " Last attempt \(Human.relative(lastTry))."
        let problem = Plain.hookProblem(JSON.string(hook["last_error"]))?.summary
        if !active {
            let why = streak > 0
                ? "It stopped after \(Human.plural(streak, "delivery", "deliveries")) in a row could not reach \(destination)."
                : "People are not being sent to \(destination) right now."
            return SyncHealth(level: .problem, headline: "\(name) is paused", detail: why + when, hook: hook)
        }
        if streak > 0 {
            let reason = problem.map { " \($0)" } ?? ""
            return SyncHealth(level: .warning, headline: "\(name) is on, but failing", detail: "The last \(Human.plural(streak, "delivery", "deliveries")) did not go through.\(reason)\(when)", hook: hook)
        }
        return SyncHealth(level: .good, headline: "\(name) is on", detail: "New and updated people are being sent to \(destination).\(when)", hook: hook)
    }
}

struct NextAction: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let detail: String
    var level: SyncHealth.Level = .none
    let run: @MainActor () -> Void
}

@MainActor
final class DeskModel: ObservableObject {
    static let activityPageSize = 40
    static let recentGiftCount = 6

    private enum Keys {
        static let lastSection = "FeathrDesk.lastSection"
        static let cleanExit = "FeathrDesk.cleanExit"
        static let sidebar = "FeathrDesk.sidebarCollapsed"
    }

    nonisolated static func markCleanExit() {
        UserDefaults.standard.set(true, forKey: Keys.cleanExit)
    }

    // MARK: - Published state

    @Published var section: DeskSection = .desk {
        didSet { sectionChanged(from: oldValue) }
    }
    @Published private(set) var inFlight = 0
    @Published var phase: DeskPhase = .lookingForKey
    @Published var keySource = ""
    @Published var keychainWaiting = false
    @Published var me: [String: Any] = [:]
    @Published var tags: [[String: Any]] = []
    @Published var campaigns: [[String: Any]] = []
    @Published var projects: [[String: Any]] = []
    @Published var fields: [[String: Any]] = []
    @Published var webhooks: [[String: Any]] = []
    @Published var recentGifts: [[String: Any]] = []
    @Published var giftTotal: Int?
    @Published var peopleOnAccount: Int?
    @Published var listProblems: [String] = []
    @Published var lastRefresh: Date?
    @Published var refreshing = false

    @Published var crumbs: [[String: Any]] = []
    @Published var crumbTotal: Int?
    @Published var crumbPage = 0
    @Published var crumbHasMore = false
    @Published var activityLoading = false
    @Published var activityLoadedOnce = false
    @Published var loadingMore = false
    @Published var activityError: String?
    @Published var loadMoreError: String?
    @Published var flavor = "donation"
    @Published var flavorCounts: [String: Int] = [:]
    @Published var activityPersonID = ""
    @Published var activityPersonLabel = ""

    @Published var people: [[String: Any]] = []
    @Published var peopleMatchTotal: Int?
    @Published var peopleQueryRan = ""
    @Published var peopleSearching = false
    @Published var peopleHint: String?
    @Published var recentPeople: [[String: Any]] = []

    @Published var selected: [String: Any] = [:]
    @Published var notes: [NoteLine] = []
    @Published var pending: PendingWrite?
    @Published var errorText: String?
    @Published var rate: RateSnapshot?
    @Published var focusRequest: DeskSection?
    @Published var showKeySheet = false
    @Published var showCreatePerson = false

    @Published var paletteOpen = false
    @Published var paletteQuery = "" { didSet { paletteIndex = 0 } }
    @Published var paletteIndex = 0

    @Published var sidebarCollapsed = false {
        didSet { UserDefaults.standard.set(sidebarCollapsed, forKey: Keys.sidebar) }
    }

    @Published var personQuery = ""
    @Published var tagQuery = ""
    @Published var campaignQuery = ""
    @Published var campaignState = ""
    @Published var campaignKind = ""
    @Published var campaignProject = ""
    @Published var campaignSort: CampaignSort = .name
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

    private var api: FeathrAPI?
    private var base = "https://api.feathr.co"
    private var activityGeneration = 0
    private var peopleGeneration = 0
    private var countsScope: String?
    private var sectionTasks: [String: Task<Void, Never>] = [:]
    private var history: [DeskSection] = []
    private var navigatingBack = false
    private var restoreSection: DeskSection?

    init() {
        let defaults = UserDefaults.standard
        sidebarCollapsed = defaults.bool(forKey: Keys.sidebar)
        let clean = defaults.object(forKey: Keys.cleanExit) as? Bool ?? true
        if clean, let raw = defaults.string(forKey: Keys.lastSection), let last = DeskSection(rawValue: raw) {
            restoreSection = last
        }
        defaults.set(false, forKey: Keys.cleanExit)
    }

    // MARK: - Derived state

    var busy: Bool { inFlight > 0 }
    var scopes: [String] { JSON.strings(me["scopes"]) }
    var canWritePeople: Bool { scopes.contains("persons:write") }
    var canWriteTags: Bool { scopes.contains("tags:write") }
    var canWriteHooks: Bool { scopes.contains("webhooks:write") }
    var connected: Bool { api != nil && !me.isEmpty }
    var hasKey: Bool { api != nil }
    var canGoBack: Bool { !history.isEmpty }

    var serviceName: String { JSON.string(me["service_name"]).ifEmpty("Feathr") }
    var lastFour: String { JSON.string(me["last_four"]) }
    var canLoadMoreActivity: Bool { !crumbs.isEmpty && crumbHasMore }

    var status: String {
        switch phase {
        case .lookingForKey:
            return keychainWaiting
                ? "Waiting for Keychain access. Choose Always Allow so Desk can read the Feathr key."
                : "Looking for the Feathr key."
        case .noKey: return "No Feathr key yet."
        case .connecting: return "Connecting to Feathr…"
        case .connected: return "Connected"
        case .keyRejected: return "Feathr did not accept the key."
        case .unreachable: return "Feathr did not answer."
        }
    }

    /// Rate limit from response headers, falling back to the `/me` payload.
    var rateRemaining: Int? {
        if let remaining = rate?.remaining { return remaining }
        if let info = me["rate_limit"] as? [String: Any], info["remaining"] != nil { return JSON.int(info["remaining"]) }
        return nil
    }

    var rateLimit: Int? {
        if let limit = rate?.limit { return limit }
        if let info = me["rate_limit"] as? [String: Any], info["limit"] != nil { return JSON.int(info["limit"]) }
        return nil
    }

    var rateLow: Bool {
        guard let remaining = rateRemaining else { return false }
        if let limit = rateLimit, limit > 0 { return Double(remaining) / Double(limit) < 0.15 }
        return remaining < 50
    }

    var rateLimitedUntil: Date? {
        guard let at = rate?.limitedAt else { return nil }
        let until = at.addingTimeInterval(TimeInterval(rate?.retryAfter ?? 60))
        return until > Date() ? until : nil
    }

    // MARK: - Boot and refresh

    func boot() async {
        let waiting = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { self?.keychainWaiting = true }
        }
        let stored = await Task.detached(priority: .userInitiated) { KeyStore.load() }.value
        waiting.cancel()
        keychainWaiting = false
        if let stored {
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
            phase = .noKey
            return
        }
        if let last = restoreSection, last != .desk {
            restoreSection = nil
            section = last
            if last.hasSearch { focusRequest = last }
        }
        await refreshDesk()
    }

    func replaceKey(_ raw: String) async {
        do {
            try KeyStore.save(raw)
            api = makeAPI(raw.trimmingCharacters(in: .whitespacesAndNewlines))
            keySource = "Keychain"
            rate = nil
            await refreshAll()
        } catch {
            report(error)
        }
    }

    private func makeAPI(_ key: String) -> FeathrAPI {
        var client = FeathrAPI(base: base, key: key)
        client.onRate = { [weak self] snapshot in
            Task { @MainActor in self?.rate = snapshot }
        }
        return client
    }

    /// ⌘R: reload reference lists, the open person, and the open activity list.
    func refreshAll() async {
        if let until = rateLimitedUntil {
            errorText = "Feathr asked Desk to slow down. Refresh opens up \(Human.relative(until))."
            return
        }
        await refreshDesk()
        guard connected else { return }
        if section == .activity {
            loadActivity(forceCounts: true)
        }
        if section == .people, kind(of: selected) == .person, let id = selected["id"] as? String, let api {
            await working {
                if let fresh = try? await api.get("/persons/\(id)") { replacePerson(fresh, id: id) }
            }
        }
    }

    func refreshDesk() async {
        guard let api else { return }
        refreshing = true
        defer { refreshing = false }
        if me.isEmpty { phase = .connecting }
        await working {
            do {
                me = try await api.get("/me")
            } catch {
                if let feathr = error as? FeathrError, feathr.isCancelled { return }
                phase = (error as? FeathrError)?.status == 401 ? .keyRejected : .unreachable
                report(error)
                return
            }
            phase = .connected

            async let tagResult = Self.list(api, "/tags")
            async let campaignResult = Self.list(api, "/campaigns")
            async let projectResult = Self.list(api, "/projects")
            async let fieldResult = Self.list(api, "/custom-fields")
            async let hookResult = Self.list(api, "/webhooks", pageSize: 50, maxPages: 2)
            async let giftPage = try? api.get("/breadcrumbs", query: ["flavor": "donation", "page": "1", "size": String(Self.recentGiftCount)])
            async let peoplePage = try? api.get("/persons", query: ["page": "1", "size": "1"])

            var problems: [String] = []
            func take(_ result: Result<[[String: Any]], Error>, _ label: String) -> [[String: Any]]? {
                switch result {
                case .success(let items): return items
                case .failure(let error):
                    if (error as? FeathrError)?.isCancelled != true { problems.append("\(label): \(Self.shortReason(error))") }
                    return nil
                }
            }
            if let rows = take(await tagResult, "Tags") { tags = Self.byName(rows) }
            if let rows = take(await campaignResult, "Campaigns") { campaigns = rows }
            if let rows = take(await projectResult, "Projects") { projects = Self.byName(rows) }
            if let rows = take(await fieldResult, "Custom fields") { fields = rows }
            if let rows = take(await hookResult, "Webhooks") { webhooks = rows }
            if let gifts = await giftPage {
                recentGifts = JSON.array(gifts["items"])
                giftTotal = gifts["total"] == nil ? nil : JSON.int(gifts["total"])
            }
            if let page = await peoplePage, page["total"] != nil {
                peopleOnAccount = JSON.int(page["total"])
            }
            listProblems = problems
            lastRefresh = Date()
            if problems.isEmpty {
                note("Desk refreshed. \(Human.plural(tags.count, "tag")), \(Human.plural(campaigns.count, "campaign")), \(Human.plural(projects.count, "project")).")
            } else {
                note("Desk refreshed, but some lists did not load: \(problems.joined(separator: "; ")).")
            }
            if !selected.isEmpty { reselect() }
            if tagToApply.isEmpty { tagToApply = tags.first.map { JSON.string($0["id"]) } ?? "" }
        }
        if connected, section == .activity, crumbs.isEmpty, !activityLoading {
            loadActivity()
        }
    }

    nonisolated private static func list(_ api: FeathrAPI, _ path: String, pageSize: Int = 100, maxPages: Int = 30) async -> Result<[[String: Any]], Error> {
        do {
            return .success(try await api.paginate(path, pageSize: pageSize, maxPages: maxPages).items)
        } catch {
            return .failure(error)
        }
    }

    nonisolated private static func shortReason(_ error: Error) -> String {
        switch (error as? FeathrError)?.status {
        case 401: return "the key was not accepted"
        case 403: return "this key cannot read them"
        case 429: return "Feathr asked Desk to slow down"
        default: return "Feathr did not answer"
        }
    }

    private static func byName(_ rows: [[String: Any]]) -> [[String: Any]] {
        rows.sorted { JSON.string($0["name"]).localizedCaseInsensitiveCompare(JSON.string($1["name"])) == .orderedAscending }
    }

    // MARK: - Section work

    private func sectionChanged(from old: DeskSection) {
        guard old != section else { return }
        cancelSectionWork()
        if navigatingBack {
            navigatingBack = false
        } else {
            history.append(old)
            if history.count > 30 { history.removeFirst(history.count - 30) }
        }
        UserDefaults.standard.set(section.rawValue, forKey: Keys.lastSection)
        if section == .activity, crumbs.isEmpty, connected {
            loadActivity()
        }
    }

    /// Runs work that belongs to the open section. Moving to another section cancels it, request and all.
    private func launch(_ key: String, _ body: @escaping @MainActor () async -> Void) {
        sectionTasks[key]?.cancel()
        sectionTasks[key] = Task { @MainActor in await body() }
    }

    private func cancelSectionWork() {
        sectionTasks.values.forEach { $0.cancel() }
        sectionTasks.removeAll()
    }

    private func working(_ body: () async -> Void) async {
        inFlight += 1
        defer { inFlight -= 1 }
        await body()
    }

    func report(_ error: Error) {
        if let feathr = error as? FeathrError {
            if feathr.isCancelled { return }
            if feathr.status == 401 {
                phase = .keyRejected
                return
            }
        }
        if error is CancellationError { return }
        errorText = FeathrAPI.scrub(error.localizedDescription)
    }

    // MARK: - Activity

    func loadActivity(forceCounts: Bool = false) {
        activityGeneration += 1
        let generation = activityGeneration
        activityError = nil
        loadMoreError = nil
        activityLoading = true
        launch("activity") { [self] in
            defer { if generation == activityGeneration { activityLoading = false } }
            guard let api else { return }
            await working {
                do {
                    let page = try await api.get("/breadcrumbs", query: activityQuery(page: 1))
                    guard generation == activityGeneration else { return }
                    let batch = JSON.array(page["items"])
                    crumbs = batch
                    crumbPage = 1
                    crumbTotal = page["total"] == nil ? nil : JSON.int(page["total"])
                    crumbHasMore = Self.hasMore(loaded: batch.count, batch: batch.count, total: crumbTotal)
                    activityLoadedOnce = true
                    let who = activityPersonLabel.isEmpty ? "the account" : activityPersonLabel
                    note("Loaded \(ActivityKind.label(for: flavor).lowercased()) for \(who).")
                } catch {
                    guard generation == activityGeneration, (error as? FeathrError)?.isCancelled != true else { return }
                    if (error as? FeathrError)?.status == 401 { phase = .keyRejected }
                    activityError = FeathrAPI.scrub(error.localizedDescription)
                }
            }
        }
        loadActivityCounts(force: forceCounts)
    }

    func loadMoreActivity() {
        guard canLoadMoreActivity, !loadingMore else { return }
        let generation = activityGeneration
        let next = crumbPage + 1
        loadingMore = true
        loadMoreError = nil
        launch("activityMore") { [self] in
            defer { if generation == activityGeneration { loadingMore = false } }
            guard let api else { return }
            await working {
                do {
                    let page = try await api.get("/breadcrumbs", query: activityQuery(page: next))
                    guard generation == activityGeneration else { return }
                    let batch = JSON.array(page["items"])
                    let known = Set(crumbs.map { JSON.string($0["id"]) }.filter { !$0.isEmpty })
                    let fresh = batch.filter { row in
                        let id = JSON.string(row["id"])
                        return id.isEmpty || !known.contains(id)
                    }
                    crumbs.append(contentsOf: fresh)
                    crumbPage = next
                    if page["total"] != nil { crumbTotal = JSON.int(page["total"]) }
                    // A page of nothing but repeats means Feathr's list shifted; stop rather than loop.
                    crumbHasMore = !fresh.isEmpty && Self.hasMore(loaded: crumbs.count, batch: batch.count, total: crumbTotal)
                } catch {
                    guard generation == activityGeneration, (error as? FeathrError)?.isCancelled != true else { return }
                    loadMoreError = FeathrAPI.scrub(error.localizedDescription)
                }
            }
        }
    }

    private static func hasMore(loaded: Int, batch: Int, total: Int?) -> Bool {
        if let total { return loaded < total && batch > 0 }
        return batch >= activityPageSize
    }

    /// Totals per flavor for the current scope. Only shown when Feathr reports a total.
    private func loadActivityCounts(force: Bool) {
        let scope = activityPersonID
        guard force || countsScope != scope else { return }
        countsScope = scope
        flavorCounts = [:]
        launch("counts") { [self] in
            guard let api else { return }
            let results = await withTaskGroup(of: (String, Int?).self) { group -> [(String, Int?)] in
                for kind in ActivityKind.allCases {
                    var query = ["flavor": kind.flavor, "page": "1", "size": "1"]
                    if !scope.isEmpty { query["person_id"] = scope }
                    group.addTask {
                        guard let page = try? await api.get("/breadcrumbs", query: query), page["total"] != nil else { return (kind.flavor, nil) }
                        return (kind.flavor, JSON.int(page["total"]))
                    }
                }
                var collected: [(String, Int?)] = []
                for await pair in group { collected.append(pair) }
                return collected
            }
            if Task.isCancelled {
                if countsScope == scope { countsScope = nil }
                return
            }
            guard countsScope == scope else { return }
            for (key, value) in results {
                if let value { flavorCounts[key] = value }
            }
        }
    }

    private func activityQuery(page: Int) -> [String: String] {
        var query = ["flavor": flavor, "page": String(page), "size": String(Self.activityPageSize)]
        if !activityPersonID.isEmpty { query["person_id"] = activityPersonID }
        return query
    }

    private func resetActivity() {
        activityGeneration += 1
        crumbs = []
        crumbTotal = nil
        crumbPage = 0
        crumbHasMore = false
        activityError = nil
        loadMoreError = nil
        activityLoadedOnce = false
        if kind(of: selected) == .crumb { selected = [:] }
    }

    func setFlavor(_ next: String) {
        guard next != flavor || crumbs.isEmpty else { return }
        flavor = next
        resetActivity()
        loadActivity()
    }

    func clearActivityPerson() {
        activityPersonID = ""
        activityPersonLabel = ""
        resetActivity()
        loadActivity()
    }

    func showActivity(flavor: String, personID: String = "", label: String = "") {
        self.flavor = flavor
        activityPersonID = personID
        activityPersonLabel = label
        resetActivity()
        selected = [:]
        if section == .activity {
            loadActivity()
        } else {
            section = .activity
        }
    }

    /// Opens the person behind a breadcrumb or gift row in People.
    func openPerson(from crumb: [String: Any]) async {
        guard let api else { return }
        let id = JSON.string(crumb["person_id"])
        let email = JSON.string(crumb["email"]).lowercased()
        await working {
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
                peopleMatchTotal = 1
                peopleHint = nil
                personQuery = JSON.string(person["email"]).ifEmpty(JSON.string(person["id"]))
                peopleQueryRan = personQuery
                section = .people
                select(person)
                note("Opened \(JSON.string(person["email"]).ifEmpty("person")) from activity.")
            } catch {
                report(error)
            }
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

    static func looksLikeID(_ text: String) -> Bool {
        text.count >= 20 && !text.contains(" ") && !text.contains("@")
    }

    func searchPeople() {
        let query = personQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let byEmail = query.contains("@")
        guard byEmail || Self.looksLikeID(query) else {
            peopleHint = "Desk looks people up by the full email they used, or by a Feathr person id."
            return
        }
        peopleHint = nil
        peopleGeneration += 1
        let generation = peopleGeneration
        peopleSearching = true
        selected = [:]
        launch("people") { [self] in
            defer { if generation == peopleGeneration { peopleSearching = false } }
            guard let api else { return }
            await working {
                do {
                    if byEmail {
                        let page = try await api.get("/persons", query: ["email": query.lowercased(), "page": "1", "size": "10"])
                        guard generation == peopleGeneration else { return }
                        people = JSON.array(page["items"])
                        peopleMatchTotal = page["total"] == nil ? people.count : JSON.int(page["total"])
                    } else {
                        let person = try await api.get("/persons/\(query)")
                        guard generation == peopleGeneration else { return }
                        people = [person]
                        peopleMatchTotal = 1
                    }
                    peopleQueryRan = query
                    if people.count == 1, let only = people.first { select(only) }
                    switch people.count {
                    case 0: note("No person for \(query).")
                    case 1: note("Found \(JSON.string(people[0]["email"]).ifEmpty("one person")).")
                    default: note("\(people.count) people share \(query).")
                    }
                } catch let error as FeathrError where error.status == 404 {
                    guard generation == peopleGeneration else { return }
                    people = []
                    peopleMatchTotal = 0
                    peopleQueryRan = query
                    note("No person with that id.")
                } catch {
                    guard generation == peopleGeneration else { return }
                    report(error)
                }
            }
        }
    }

    func startCreate(withEmail email: String) {
        draftEmail = email
        showCreatePerson = true
    }

    func select(_ row: [String: Any]) {
        selected = row
        fillDrafts()
        switch kind(of: row) {
        case .tag: renameTag = JSON.string(row["name"])
        case .person: remember(row)
        default: break
        }
    }

    func clearSelection() {
        selected = [:]
    }

    private func remember(_ person: [String: Any]) {
        let id = JSON.string(person["id"])
        guard !id.isEmpty else { return }
        recentPeople.removeAll { JSON.string($0["id"]) == id }
        recentPeople.insert(person, at: 0)
        if recentPeople.count > 8 { recentPeople.removeLast(recentPeople.count - 8) }
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

    func confirm(_ write: PendingWrite) {
        pending = write
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
        var points: [String] = []
        func change(_ label: String, _ old: String, _ new: String) {
            guard old != new else { return }
            points.append("\(label): \(old.ifEmpty("blank")) → \(new.ifEmpty("blank"))")
        }
        change("First name", JSON.string(selected["first_name"]), body["first_name"] as? String ?? "")
        change("Last name", JSON.string(selected["last_name"]), body["last_name"] as? String ?? "")
        change("Phone", JSON.string(selected["phone"]), body["phone"] as? String ?? "")
        confirm(PendingWrite(
            title: "Save changes to \(JSON.string(selected["email"]).ifEmpty("this person"))?",
            detail: "Updates their record in Feathr. Nothing is emailed to them.",
            button: "Save",
            points: points
        ) {
            await self.writePerson(id: id, body: body)
        })
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
        confirm("Add \(tagName(tagID))?", "Tags \(JSON.string(selected["email"])). Nothing is emailed to them.", button: "Add tag") {
            await self.addTag(personID: personID, tagID: tagID)
        }
    }

    func removeTag(_ tagID: String) {
        guard let personID = selected["id"] as? String, canWriteTags, canWritePeople else { return }
        let email = JSON.string(selected["email"])
        let remaining = JSON.tagIDs(selected).filter { $0 != tagID }
        confirm(PendingWrite(
            title: "Remove \(tagName(tagID))?",
            detail: "Takes the tag off \(email).",
            button: "Remove tag",
            tone: .caution,
            points: [
                "The tag itself stays, and everyone else keeps it.",
                "Desk re-reads the person afterward and tells you if Feathr kept the tag.",
            ]
        ) {
            await self.removeTagNow(personID: personID, tagID: tagID, remaining: remaining)
        })
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
        let name = Plain.hookTitle(hook)
        let destination = Plain.destination(hook)
        let events = Plain.hookEvents(hook).lowercased().ifEmpty("people")
        let streak = JSON.int(hook["consecutive_failures"])
        let problem = Plain.hookProblem(JSON.string(hook["last_error"]))?.summary
        let catchUp = "Desk cannot tell whether Feathr re-sends changes made while it was paused. Spot-check \(destination) afterward."
        let write: PendingWrite
        if active {
            var points = ["Feathr starts sending \(events) to \(destination) again."]
            if streak > 0 {
                points.append("The last \(Human.plural(streak, "delivery", "deliveries")) failed.\(problem.map { " \($0)" } ?? "") If that is not fixed, the failures will continue.")
            }
            points.append(catchUp)
            write = PendingWrite(
                title: "Turn \(name) back on?",
                detail: "Sync has been paused. Turning it on affects every new and updated person from now on.",
                button: "Turn on",
                tone: streak > 0 ? .caution : .standard,
                points: points,
                acknowledge: streak > 0 ? "The receiving side is fixed, or I am watching the next deliveries." : nil
            ) {
                await self.patchWebhook(id: id, active: true, hook: hook)
            }
        } else {
            write = PendingWrite(
                title: "Pause \(name)?",
                detail: "While paused, Feathr stops sending \(events) to \(destination) until someone turns it back on.",
                button: "Pause sync",
                tone: .caution,
                points: [
                    "Nothing already in \(destination) changes.",
                    catchUp,
                ],
                acknowledge: "I understand people will not reach \(destination) while this is paused."
            ) {
                await self.patchWebhook(id: id, active: false, hook: hook)
            }
        }
        confirm(write)
    }

    // MARK: - Lookups

    func tagName(_ id: String) -> String {
        tags.first { JSON.string($0["id"]) == id }.map { JSON.string($0["name"]) } ?? "Tag …\(id.suffix(6))"
    }

    func projectName(_ id: String) -> String {
        guard !id.isEmpty else { return "—" }
        return projects.first { JSON.string($0["id"]) == id }.map { JSON.string($0["name"]) } ?? "Project …\(id.suffix(6))"
    }

    func campaignName(_ id: String) -> String {
        guard !id.isEmpty else { return "" }
        return campaigns.first { JSON.string($0["id"]) == id }.map { JSON.string($0["name"]) } ?? "Campaign …\(id.suffix(6))"
    }

    func fieldLabel(_ key: String) -> String {
        fieldDefinition(key).map { JSON.string($0["label"]).ifEmpty(key) } ?? key
    }

    func fieldDefinition(_ key: String) -> [String: Any]? {
        fields.first { JSON.string($0["key"]) == key || JSON.string($0["id"]) == key }
    }

    /// Custom field values on a person, in label order. Only fields Feathr actually returned.
    func customFieldRows(_ person: [String: Any]) -> [(key: String, label: String, value: String)] {
        let values = JSON.object(person["custom_fields"])
        return values.compactMap { key, value -> (String, String, String)? in
            let text = JSON.display(value)
            return text.isEmpty ? nil : (key, fieldLabel(key), text)
        }
        .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    var campaignStates: [String] { Array(Set(campaigns.map { JSON.string($0["state"]) }.filter { !$0.isEmpty })).sorted() }
    var campaignKinds: [String] { Array(Set(campaigns.map { JSON.string($0["kind"]) }.filter { !$0.isEmpty })).sorted() }

    /// Projects that own at least one loaded campaign, by name.
    var campaignProjects: [(id: String, name: String)] {
        Array(Set(campaigns.map { JSON.string($0["project_id"]) }.filter { !$0.isEmpty }))
            .map { ($0, projectName($0)) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    func campaignCount(state: String? = nil, kind: String? = nil, project: String? = nil) -> Int {
        campaigns.filter { row in
            (state == nil || JSON.string(row["state"]) == state)
                && (kind == nil || JSON.string(row["kind"]) == kind)
                && (project == nil || JSON.string(row["project_id"]) == project)
        }.count
    }

    var campaignFiltering: Bool {
        !campaignState.isEmpty || !campaignKind.isEmpty || !campaignProject.isEmpty || !campaignQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func clearCampaignFilters() {
        campaignState = ""
        campaignKind = ""
        campaignProject = ""
        campaignQuery = ""
    }

    var filteredCampaigns: [[String: Any]] {
        let q = campaignQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rows = campaigns
            .filter { campaignState.isEmpty || JSON.string($0["state"]) == campaignState }
            .filter { campaignKind.isEmpty || JSON.string($0["kind"]) == campaignKind }
            .filter { campaignProject.isEmpty || JSON.string($0["project_id"]) == campaignProject }
            .filter { q.isEmpty || JSON.string($0["name"]).lowercased().contains(q) || projectName(JSON.string($0["project_id"])).lowercased().contains(q) }
        switch campaignSort {
        case .name:
            return Self.byName(rows)
        case .newest:
            return rows.sorted {
                (JSON.date(JSON.string($0["date_start"])) ?? .distantPast) > (JSON.date(JSON.string($1["date_start"])) ?? .distantPast)
            }
        }
    }

    var filteredTags: [[String: Any]] {
        let q = tagQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return tags }
        return tags.filter { JSON.string($0["name"]).localizedCaseInsensitiveContains(q) }
    }

    func campaignsInProject(_ id: String) -> Int {
        campaigns.filter { JSON.string($0["project_id"]) == id }.count
    }

    /// The Salesforce link if there is one, otherwise the first webhook.
    var primaryHook: [String: Any]? {
        webhooks.first(where: Plain.isSalesforce) ?? webhooks.first
    }

    var syncHealth: SyncHealth {
        guard let hook = primaryHook else {
            if !connected {
                return SyncHealth(level: .none, headline: "Checking sync…", detail: "", hook: nil)
            }
            return SyncHealth(level: .none, headline: "No Salesforce sync link", detail: connected ? "Feathr has no webhook set up on this account, so people are not sent to Salesforce automatically." : "Connect a key to check sync.", hook: nil)
        }
        return SyncHealth.of(hook)
    }

    var giftsToday: Int {
        recentGifts.filter { JSON.date(JSON.string($0["created_at"])).map(Calendar.current.isDateInToday) ?? false }.count
    }

    var latestGiftDate: Date? {
        recentGifts.compactMap { JSON.date(JSON.string($0["created_at"])) }.max()
    }

    /// Short, grounded list of things worth a look. Empty means nothing needs the operator.
    var nextActions: [NextAction] {
        var list: [NextAction] = []
        if phase == .keyRejected {
            list.append(NextAction(id: "key", symbol: "key", title: "Replace the Feathr key", detail: "Feathr stopped accepting the current key.", level: .problem) { [weak self] in
                self?.showKeySheet = true
            })
        }
        for hook in webhooks {
            let health = SyncHealth.of(hook)
            guard health.level == .problem || health.level == .warning else { continue }
            list.append(NextAction(id: "hook-\(JSON.string(hook["id"]))", symbol: "arrow.left.arrow.right", title: health.headline, detail: health.detail, level: health.level) { [weak self] in
                self?.go(.webhooks)
                self?.select(hook)
            })
        }
        if !listProblems.isEmpty {
            list.append(NextAction(id: "lists", symbol: "exclamationmark.triangle", title: "Some lists did not load", detail: listProblems.joined(separator: " · "), level: .warning) { [weak self] in
                Task { await self?.refreshAll() }
            })
        }
        if rateLow, let remaining = rateRemaining {
            list.append(NextAction(id: "rate", symbol: "gauge.with.dots.needle.33percent", title: "Feathr requests are running low", detail: "\(Human.count(remaining)) left in this window. Desk will wait if Feathr asks it to.", level: .warning) {})
        }
        if let last = lastRefresh, Date().timeIntervalSince(last) > 30 * 60 {
            list.append(NextAction(id: "stale", symbol: "clock.arrow.circlepath", title: "Desk was last refreshed \(Human.relative(last))", detail: "Refresh to see the latest from Feathr.") { [weak self] in
                Task { await self?.refreshAll() }
            })
        }
        if giftsToday > 0 {
            list.append(NextAction(id: "gifts", symbol: "gift", title: giftsToday >= Self.recentGiftCount ? "Gifts came in today" : "\(Human.plural(giftsToday, "gift")) today", detail: "Open Activity to see who gave.") { [weak self] in
                self?.showActivity(flavor: ActivityKind.donation.flavor)
            })
        }
        let sending = campaignCount(state: "published")
        if sending > 0 {
            list.append(NextAction(id: "sending", symbol: "envelope", title: "\(Human.plural(sending, "campaign")) sending", detail: "Look over what is going out this week.") { [weak self] in
                self?.showCampaigns(state: "published")
            })
        }
        return list
    }

    func showCampaigns(state: String) {
        clearCampaignFilters()
        campaignState = state
        go(.campaigns)
    }

    // MARK: - Navigation

    func requestFocus(_ target: DeskSection? = nil) {
        let destination = target ?? (section.hasSearch ? section : .people)
        go(destination)
        focusRequest = destination
    }

    func go(_ destination: DeskSection) {
        guard destination != section else { return }
        section = destination
        selected = [:]
    }

    func goBack() {
        guard let previous = history.popLast() else { return }
        navigatingBack = true
        section = previous
        selected = [:]
    }

    func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.18)) { sidebarCollapsed.toggle() }
    }

    func openPalette() {
        paletteQuery = ""
        paletteIndex = 0
        paletteOpen = true
    }

    func closePalette() {
        paletteOpen = false
    }

    /// Rows in the open section, in on-screen order, for ↑/↓ navigation.
    var visibleRows: [[String: Any]] {
        switch section {
        case .desk: return recentGifts
        case .people: return people
        case .tags: return filteredTags
        case .campaigns: return filteredCampaigns
        case .projects: return projects
        case .activity: return crumbs
        case .fields: return fields
        case .webhooks: return webhooks
        }
    }

    func moveSelection(_ step: Int) {
        let rows = visibleRows
        guard !rows.isEmpty else { return }
        let current = JSON.string(selected["id"])
        let index = rows.firstIndex { !current.isEmpty && $0.selfID == current } ?? (step > 0 ? -1 : rows.count)
        let next = min(max(index + step, 0), rows.count - 1)
        select(rows[next])
        if section == .activity, next >= rows.count - 3 { loadMoreActivity() }
    }

    /// Return or ⌘O on a selected row.
    func activateSelection() {
        switch kind(of: selected) {
        case .crumb:
            let row = selected
            Task { await openPerson(from: row) }
        case .person where section != .people:
            let row = selected
            people = [row]
            peopleMatchTotal = 1
            personQuery = JSON.string(row["email"])
            peopleQueryRan = personQuery
            section = .people
            select(row)
        default:
            break
        }
    }

    // MARK: - Writes

    private func writePerson(id: String, body: [String: Any]) async {
        guard let api else { return }
        await working {
            do {
                var updated = try await api.send("PATCH", "/persons/\(id)", body: body)
                if updated.isEmpty { updated = try await api.get("/persons/\(id)") }
                replacePerson(updated, id: id)
                fillDrafts()
                note("Saved \(JSON.string(selected["email"]).ifEmpty("person")).")
            } catch {
                report(error)
            }
        }
    }

    private func createPersonNow(email: String) async {
        guard let api else { return }
        await working {
            do {
                var body: [String: Any] = ["email": email]
                let first = createFirst.trimmingCharacters(in: .whitespaces)
                let last = createLast.trimmingCharacters(in: .whitespaces)
                let phone = createPhone.trimmingCharacters(in: .whitespaces)
                if !first.isEmpty { body["first_name"] = first }
                if !last.isEmpty { body["last_name"] = last }
                if !phone.isEmpty { body["phone"] = phone }
                let created = try await api.send("POST", "/persons", body: body)
                people = [created]
                peopleMatchTotal = 1
                personQuery = email
                peopleQueryRan = email
                draftEmail = ""
                createFirst = ""
                createLast = ""
                createPhone = ""
                showCreatePerson = false
                select(created)
                note("Created \(email).")
            } catch {
                report(error)
            }
        }
    }

    private func addTag(personID: String, tagID: String) async {
        guard let api else { return }
        await working {
            do {
                _ = try await api.send("POST", "/persons/\(personID)/tags", body: ["tag_ids": [tagID]])
                let updated = try await api.get("/persons/\(personID)")
                replacePerson(updated, id: personID)
                note("Tagged \(JSON.string(updated["email"])) with \(tagName(tagID)).")
            } catch {
                report(error)
            }
        }
    }

    private func removeTagNow(personID: String, tagID: String, remaining: [String]) async {
        guard let api else { return }
        await working {
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
                report(error)
            }
        }
    }

    private func createTagNow(_ name: String) async {
        guard let api else { return }
        await working {
            do {
                let created = try await api.send("POST", "/tags", body: ["name": name, "context": "person"])
                tags = Self.byName(tags + [created])
                selected = created
                newTagName = ""
                renameTag = name
                note("Created tag \(name).")
            } catch {
                report(error)
            }
        }
    }

    private func renameTagNow(id: String, name: String) async {
        guard let api else { return }
        await working {
            do {
                let updated = try await api.send("PATCH", "/tags/\(id)", body: ["name": name])
                if let index = tags.firstIndex(where: { JSON.string($0["id"]) == id }) {
                    tags[index] = updated
                }
                tags = Self.byName(tags)
                selected = updated
                note("Renamed tag to \(name).")
            } catch {
                report(error)
            }
        }
    }

    private func patchWebhook(id: String, active: Bool, hook: [String: Any]) async {
        guard let api else { return }
        let name = Plain.hookTitle(hook)
        await working {
            do {
                let updated = try await api.send("PATCH", "/webhooks/\(id)", body: [
                    "name": JSON.string(hook["name"]),
                    "target_url": JSON.string(hook["target_url"]),
                    "events": JSON.strings(hook["events"]),
                    "is_active": active,
                ])
                if let fresh = try? await api.paginate("/webhooks", pageSize: 50, maxPages: 2).items {
                    webhooks = fresh
                } else if let index = webhooks.firstIndex(where: { JSON.string($0["id"]) == id }), !updated.isEmpty {
                    webhooks[index] = updated
                }
                if let current = webhooks.first(where: { JSON.string($0["id"]) == id }) {
                    selected = current
                    if (JSON.bool(current["is_active"]) == true) != active {
                        errorText = "Feathr accepted the change, but \(name) still reads as \(active ? "paused" : "running"). Check it in Feathr."
                        return
                    }
                }
                note(active ? "Turned \(name) on." : "Paused \(name).")
            } catch {
                report(error)
            }
        }
    }

    private func replacePerson(_ updated: [String: Any], id: String) {
        if JSON.string(selected["id"]) == id {
            selected = updated
        }
        if let index = people.firstIndex(where: { JSON.string($0["id"]) == id }) {
            people[index] = updated
        }
        if let index = recentPeople.firstIndex(where: { JSON.string($0["id"]) == id }) {
            recentPeople[index] = updated
        }
    }

    private func fillDrafts() {
        draftFirst = JSON.string(selected["first_name"])
        draftLast = JSON.string(selected["last_name"])
        draftPhone = JSON.string(selected["phone"])
        let have = Set(JSON.tagIDs(selected))
        if tagToApply.isEmpty || have.contains(tagToApply) || !tags.contains(where: { JSON.string($0["id"]) == tagToApply }) {
            tagToApply = tags.first { !have.contains(JSON.string($0["id"])) }.map { JSON.string($0["id"]) } ?? ""
        }
    }

    private func reselect() {
        let id = JSON.string(selected["id"])
        guard !id.isEmpty else { return }
        let pools = [people, tags, campaigns, projects, fields, webhooks, crumbs, recentGifts]
        if let match = pools.lazy.compactMap({ pool in pool.first { JSON.string($0["id"]) == id } }).first {
            selected = match
        }
    }

    func note(_ text: String) {
        notes.insert(NoteLine(time: Date(), text: text), at: 0)
        if notes.count > 40 { notes.removeLast(notes.count - 40) }
    }
}
