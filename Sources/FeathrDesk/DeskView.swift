import SwiftUI

struct DeskView: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model)
            ProgressLine(active: model.busy)
            HStack(spacing: 0) {
                SideRail(model: model)
                Rectangle().fill(DeskTheme.line).frame(width: 1)
                center
                Rectangle().fill(DeskTheme.line).frame(width: 1)
                DetailRail(model: model)
            }
        }
        .background(DeskTheme.desk)
        .overlay {
            if model.paletteOpen {
                CommandPalette(model: model)
            }
        }
        .animation(.easeOut(duration: 0.14), value: model.paletteOpen)
        .preferredColorScheme(.dark)
        .sheet(item: $model.pending) { write in
            ConfirmSheet(model: model, write: write)
        }
        .task {
            KeyMonitor.shared.install(model)
            await model.boot()
        }
    }

    private var center: some View {
        VStack(spacing: 0) {
            banners
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch model.section {
                        case .desk: DeskHomeView(model: model)
                        case .people: PeoplePane(model: model)
                        case .tags: TagsPane(model: model)
                        case .campaigns: CampaignsPane(model: model)
                        case .projects: ProjectsPane(model: model)
                        case .activity: ActivityPane(model: model)
                        case .fields: FieldsPane(model: model)
                        case .webhooks: WebhooksPane(model: model)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(model.section)
                .onChange(of: model.selected.selfID) { _, id in
                    guard !id.isEmpty else { return }
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(DeskTheme.desk)
    }

    @ViewBuilder
    private var banners: some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                if let until = model.rateLimitedUntil {
                    Banner(tone: .warning, text: "Feathr asked Desk to slow down. Requests open again in \(Human.seconds(Int(until.timeIntervalSinceNow.rounded(.up)))). Nothing is lost; try again then.")
                } else if model.rateLow, let remaining = model.rateRemaining {
                    Banner(tone: .info, text: "Feathr requests are running low: \(Human.count(remaining))\(model.rateLimit.map { " of \(Human.count($0))" } ?? "") left in this window.")
                }
            }
            if model.phase == .keyRejected {
                Banner(tone: .problem, text: "Feathr stopped accepting this key. It may have been revoked or rotated.", actionTitle: "Replace key", action: {
                    model.showKeySheet = true
                })
            }
            if let error = model.errorText {
                Banner(tone: .problem, text: error, onDismiss: { model.errorText = nil })
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, hasBanner ? 14 : 0)
        .animation(.easeOut(duration: 0.18), value: model.errorText)
    }

    private var hasBanner: Bool {
        model.errorText != nil || model.phase == .keyRejected || model.rateLimitedUntil != nil || model.rateLow
    }
}

private struct TopBar: View {
    @ObservedObject var model: DeskModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.toggleSidebar()
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(model.sidebarCollapsed ? "Show sidebar labels (⌃⌘S)" : "Collapse sidebar (⌃⌘S)")
            DeskBadge(text: "FEATHR")
            HStack(spacing: 6) {
                Text(model.section.rawValue)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if let scope = scope {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(scope)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            paletteTrigger
            Spacer(minLength: 12)
            if let last = model.lastRefresh {
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text(model.refreshing ? "Refreshing…" : "Refreshed \(Human.relative(last))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            QuietButton(title: "Refresh", systemImage: "arrow.clockwise", enabled: model.hasKey && !model.refreshing && model.rateLimitedUntil == nil) {
                Task { await model.refreshAll() }
            }
            .help("Refresh from Feathr (⌘R)")
            Button {
                model.showKeySheet = true
            } label: {
                Image(systemName: model.phase == .keyRejected ? "key.slash" : "key")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(model.phase == .keyRejected ? DeskTheme.problem : .white.opacity(0.55))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Feathr key (⌘,)")
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .background(DeskTheme.rail)
        .sheet(isPresented: $model.showKeySheet) {
            KeySheet(model: model)
        }
    }

    private var scope: String? {
        switch model.section {
        case .activity:
            let kind = ActivityKind.label(for: model.flavor)
            return model.activityPersonLabel.isEmpty ? kind : "\(kind) for \(model.activityPersonLabel)"
        case .people where model.kind(of: model.selected) == .person:
            return Plain.personTitle(model.selected)
        default:
            return nil
        }
    }

    private var paletteTrigger: some View {
        Button {
            model.openPalette()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                Text("Search or jump to…")
                    .font(.system(size: 12, design: .rounded))
                Spacer(minLength: 16)
                KeyCap(text: "⌘K")
            }
            .foregroundStyle(.white.opacity(0.45))
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 5)
            .frame(width: 260)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DeskTheme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Command palette (⌘K)")
    }
}

private struct SideRail: View {
    @ObservedObject var model: DeskModel

    private var collapsed: Bool { model.sidebarCollapsed }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !collapsed {
                RailLabel(text: "GO TO")
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
            } else {
                Color.clear.frame(height: 14)
            }
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(DeskSection.allCases) { side in
                        RailItem(model: model, side: side, collapsed: collapsed)
                    }
                }
                .padding(.horizontal, 8)
            }
            Spacer(minLength: 0)
            footer
        }
        .frame(width: collapsed ? 56 : 196)
        .background(DeskTheme.rail)
    }

    @ViewBuilder
    private var footer: some View {
        if collapsed {
            StatusDot(level: model.connected ? .good : (model.phase == .keyRejected ? .problem : .none), size: 7)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
                .help(model.connected ? "Connected to \(model.serviceName)" : model.status)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    StatusDot(level: model.connected ? .good : (model.phase == .keyRejected ? .problem : .none), size: 6)
                    Text(model.connected ? model.serviceName : model.status)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Text(model.lastFour.isEmpty ? "No key" : "Key …\(model.lastFour)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.32))
                Text("Feathr Desk \(DeskInfo.version)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.22))
            }
            .padding(14)
        }
    }
}

private struct RailItem: View {
    @ObservedObject var model: DeskModel
    let side: DeskSection
    let collapsed: Bool
    @State private var hovering = false

    private var active: Bool { model.section == side }

    var body: some View {
        Button {
            model.go(side)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: side.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(active ? DeskTheme.ink : .white.opacity(0.55))
                if !collapsed {
                    Text(side.rawValue)
                        .font(.system(size: 13, weight: active ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(active ? DeskTheme.ink : .white.opacity(0.88))
                    Spacer(minLength: 4)
                    trailing
                }
            }
            .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
            .padding(.horizontal, collapsed ? 0 : 10)
            .padding(.vertical, 8)
            .background(active ? DeskTheme.copper : Color.white.opacity(hovering ? 0.06 : 0))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                if collapsed, side == .webhooks, let level = hookLevel, level != .good {
                    StatusDot(level: level, size: 5).offset(x: -6, y: 6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(collapsed ? "\(side.rawValue) (\(side.shortcut))" : side.shortcut)
    }

    @ViewBuilder
    private var trailing: some View {
        if hovering && !active {
            Text(side.shortcut)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        } else if side == .webhooks, let level = hookLevel {
            StatusDot(level: level, size: 6)
        } else if let count {
            Text(Human.count(count))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(active ? DeskTheme.ink.opacity(0.6) : .white.opacity(0.3))
        }
    }

    private var count: Int? {
        guard model.connected else { return nil }
        switch side {
        case .tags: return model.tags.count
        case .campaigns: return model.campaigns.count
        case .projects: return model.projects.count
        case .fields: return model.fields.count
        default: return nil
        }
    }

    private var hookLevel: SyncHealth.Level? {
        guard model.connected, !model.webhooks.isEmpty else { return nil }
        return model.syncHealth.level
    }
}
