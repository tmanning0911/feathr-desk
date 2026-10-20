import SwiftUI

struct DeskView: View {
    @ObservedObject var model: DeskModel
    @State private var showKey = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(spacing: 0) {
                sideRail
                center
                DetailRail(model: model)
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
            model.scheduleActivityLoad()
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
            if let until = model.rateLimitedUntil {
                Text("Limited until \(until.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DeskTheme.copper)
            } else if let remaining = model.rateRemaining, remaining < 200 {
                Text("\(remaining) requests left this minute")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(DeskTheme.copper)
            }
            QuietButton(title: "Refresh", systemImage: "arrow.clockwise") {
                Task { await model.refreshAll() }
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
                            model.go(side)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(model.lastFour.isEmpty ? "Not connected" : "Key …\(model.lastFour)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                Text("Desk \(DeskInfo.version)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
            }
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
        .background(DeskTheme.desk)
    }
}
