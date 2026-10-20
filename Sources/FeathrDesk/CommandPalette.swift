import SwiftUI

struct PaletteItem: Identifiable {
    let id: String
    let group: String
    let title: String
    var subtitle: String = ""
    let symbol: String
    var shortcut: String = ""
    var score: Int = 0
    let run: @MainActor () -> Void
}

extension DeskModel {
    private static let groupOrder = ["Find person", "Actions", "Recent people", "Tags", "Campaigns", "Projects", "Recent gifts", "Go to"]

    var paletteItems: [PaletteItem] {
        let q = paletteQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var pool: [PaletteItem] = []

        if q.contains("@") || Self.looksLikeID(q) {
            pool.append(PaletteItem(
                id: "find-direct", group: "Find person",
                title: q.contains("@") ? "Find \(q.lowercased())" : "Open person \(q)",
                subtitle: "Look them up in Feathr", symbol: "magnifyingglass", score: 10_000
            ) { [weak self] in self?.findPerson(q) })
        }

        pool += actionItems
        pool += DeskSection.allCases.map { side in
            PaletteItem(id: "go-\(side.rawValue)", group: "Go to", title: side.rawValue, symbol: side.symbol, shortcut: side.shortcut) { [weak self] in
                self?.go(side)
            }
        }
        pool += recentPeople.prefix(q.isEmpty ? 4 : 8).map { person in
            PaletteItem(id: "recent-\(person.selfID)", group: "Recent people", title: Plain.personTitle(person), subtitle: JSON.string(person["email"]), symbol: "person.crop.circle") { [weak self] in
                self?.showPerson(person)
            }
        }
        pool += recentGifts.prefix(q.isEmpty ? 3 : Self.recentGiftCount).map { gift in
            let amount = Plain.amount(gift)
            let when = Human.relative(JSON.string(gift["created_at"]))
            return PaletteItem(id: "gift-\(gift.selfID)", group: "Recent gifts", title: JSON.string(gift["email"]).ifEmpty("Unknown email"), subtitle: ["Gift", when, amount].filter { !$0.isEmpty }.joined(separator: " · "), symbol: "gift") { [weak self] in
                Task { await self?.openPerson(from: gift) }
            }
        }
        if !q.isEmpty {
            pool += tags.map { tag in
                PaletteItem(id: "tag-\(tag.selfID)", group: "Tags", title: JSON.string(tag["name"]), subtitle: "Tag", symbol: "tag") { [weak self] in
                    self?.go(.tags)
                    self?.tagQuery = ""
                    self?.select(tag)
                }
            }
            pool += campaigns.map { row in
                let parts = [Plain.state(JSON.string(row["state"])), Plain.kind(JSON.string(row["kind"])), projectName(JSON.string(row["project_id"]))]
                return PaletteItem(id: "campaign-\(row.selfID)", group: "Campaigns", title: JSON.string(row["name"]), subtitle: parts.filter { $0 != "—" }.joined(separator: " · "), symbol: "envelope") { [weak self] in
                    self?.clearCampaignFilters()
                    self?.go(.campaigns)
                    self?.select(row)
                }
            }
            pool += projects.map { row in
                PaletteItem(id: "project-\(row.selfID)", group: "Projects", title: JSON.string(row["name"]), subtitle: JSON.string(row["site_url"]), symbol: "folder") { [weak self] in
                    self?.go(.projects)
                    self?.select(row)
                }
            }
        }

        let limits = ["Tags": 5, "Campaigns": 6, "Projects": 4, "Recent gifts": 5, "Recent people": 6, "Go to": q.isEmpty ? 8 : 4]
        var grouped: [String: [PaletteItem]] = [:]
        for var item in pool {
            if item.group != "Find person" {
                guard let score = Fuzzy.score(q, item.title) ?? Fuzzy.score(q, item.subtitle).map({ $0 / 2 }) else { continue }
                item.score = score
            }
            grouped[item.group, default: []].append(item)
        }
        return Self.groupOrder.flatMap { group -> [PaletteItem] in
            let items = grouped[group] ?? []
            let ranked = q.isEmpty ? items : items.sorted { $0.score > $1.score }
            return Array(ranked.prefix(limits[group] ?? 12))
        }
    }

    private var actionItems: [PaletteItem] {
        var items: [PaletteItem] = [
            PaletteItem(id: "find", group: "Actions", title: "Find a person", subtitle: "By email or Feathr id", symbol: "person", shortcut: "⌘F") { [weak self] in
                self?.requestFocus(.people)
            },
            PaletteItem(id: "gifts", group: "Actions", title: "Recent gifts", subtitle: giftTotal.map { "\(Human.count($0)) on record" } ?? "", symbol: "gift", shortcut: "⇧⌘G") { [weak self] in
                self?.showActivity(flavor: ActivityKind.donation.flavor)
            },
            PaletteItem(id: "forms", group: "Actions", title: "Recent form fills", symbol: "doc.text") { [weak self] in
                self?.showActivity(flavor: ActivityKind.form.flavor)
            },
            PaletteItem(id: "sync", group: "Actions", title: "Salesforce sync", subtitle: syncHealth.headline, symbol: "arrow.left.arrow.right") { [weak self] in
                guard let self else { return }
                go(.webhooks)
                if let hook = primaryHook { select(hook) }
            },
            PaletteItem(id: "sending", group: "Actions", title: "Sending campaigns", subtitle: "\(campaignCount(state: "published")) sending", symbol: "envelope") { [weak self] in
                self?.showCampaigns(state: "published")
            },
            PaletteItem(id: "refresh", group: "Actions", title: "Refresh from Feathr", subtitle: lastRefresh.map { "Last refreshed \(Human.relative($0))" } ?? "", symbol: "arrow.clockwise", shortcut: "⌘R") { [weak self] in
                Task { await self?.refreshAll() }
            },
        ]
        if let hook = primaryHook, canWriteHooks {
            let active = JSON.bool(hook["is_active"]) == true
            items.append(PaletteItem(id: "toggle-sync", group: "Actions", title: active ? "Pause Salesforce sync…" : "Turn Salesforce sync back on…", subtitle: "Asks before changing anything", symbol: active ? "pause.circle" : "play.circle") { [weak self] in
                self?.go(.webhooks)
                self?.select(hook)
                self?.setWebhookActive(hook, active: !active)
            })
        }
        if canGoBack {
            items.append(PaletteItem(id: "back", group: "Actions", title: "Back", symbol: "chevron.left", shortcut: "⌘[") { [weak self] in self?.goBack() })
        }
        items.append(PaletteItem(id: "sidebar", group: "Actions", title: sidebarCollapsed ? "Show sidebar labels" : "Collapse sidebar", symbol: "sidebar.left", shortcut: "⌃⌘S") { [weak self] in
            self?.toggleSidebar()
        })
        items.append(PaletteItem(id: "key", group: "Actions", title: "Replace Feathr key…", subtitle: lastFour.isEmpty ? "" : "Current key ends …\(lastFour)", symbol: "key", shortcut: "⌘,") { [weak self] in
            self?.showKeySheet = true
        })
        return items
    }

    func findPerson(_ query: String) {
        go(.people)
        personQuery = query
        searchPeople()
    }

    func showPerson(_ person: [String: Any]) {
        people = [person]
        peopleMatchTotal = 1
        peopleHint = nil
        personQuery = JSON.string(person["email"]).ifEmpty(JSON.string(person["id"]))
        peopleQueryRan = personQuery
        go(.people)
        select(person)
    }

    func movePalette(_ step: Int) {
        let count = paletteItems.count
        guard count > 0 else { return }
        paletteIndex = (paletteIndex + step + count) % count
    }

    func runPalette(_ index: Int? = nil) {
        let items = paletteItems
        let target = index ?? paletteIndex
        guard items.indices.contains(target) else { return }
        closePalette()
        items[target].run()
    }
}

struct CommandPalette: View {
    @ObservedObject var model: DeskModel
    @FocusState private var focused: Bool

    var body: some View {
        let items = model.paletteItems
        ZStack(alignment: .top) {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture { model.closePalette() }
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DeskTheme.copper)
                    TextField("Find a person, tag, campaign, or action", text: $model.paletteQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, design: .rounded))
                        .focused($focused)
                    KeyCap(text: "esc")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                Divider().overlay(DeskTheme.line)
                if items.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nothing matches “\(model.paletteQuery)”.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                        Text("Type a full email to look a person up in Feathr.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    if index == 0 || items[index - 1].group != item.group {
                                        SectionLabel(text: item.group)
                                            .padding(.horizontal, 12)
                                            .padding(.top, index == 0 ? 8 : 12)
                                            .padding(.bottom, 4)
                                    }
                                    PaletteRow(item: item, highlighted: index == model.paletteIndex)
                                        .id(item.id)
                                        .onTapGesture { model.runPalette(index) }
                                        .onHover { if $0 { model.paletteIndex = index } }
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.bottom, 8)
                        }
                        .frame(maxHeight: 380)
                        .onChange(of: model.paletteIndex) { _, index in
                            guard items.indices.contains(index) else { return }
                            proxy.scrollTo(items[index].id)
                        }
                    }
                }
                Divider().overlay(DeskTheme.line)
                HStack(spacing: 14) {
                    hint("↑↓", "move")
                    hint("↩", "open")
                    hint("esc", "close")
                    Spacer()
                    Text("Writes always ask first")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(width: 580)
            .background(DeskTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1)))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 14)
            .padding(.top, 70)
        }
        .onAppear { DispatchQueue.main.async { focused = true } }
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            KeyCap(text: key)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

private struct PaletteRow: View {
    let item: PaletteItem
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(highlighted ? DeskTheme.copperHighlight : .white.opacity(0.5))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(highlighted ? 1 : 0.86))
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if !item.shortcut.isEmpty {
                KeyCap(text: item.shortcut)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(highlighted ? Color.white.opacity(0.08) : .clear))
        .overlay(alignment: .leading) {
            if highlighted {
                RoundedRectangle(cornerRadius: 1.5).fill(DeskTheme.copper).frame(width: 3, height: 18).offset(x: -1)
            }
        }
        .contentShape(Rectangle())
    }
}
