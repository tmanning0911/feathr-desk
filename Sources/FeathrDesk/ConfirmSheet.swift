import SwiftUI

/// Every Feathr write goes through this sheet. Serious changes can require an explicit acknowledgement.
struct ConfirmSheet: View {
    @ObservedObject var model: DeskModel
    let write: PendingWrite
    @State private var acknowledged = false

    private var ready: Bool { write.acknowledge == nil || acknowledged }
    private var caution: Bool { write.tone == .caution }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: caution ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .foregroundStyle(caution ? DeskTheme.warn : DeskTheme.copper)
                DeskBadge(text: caution ? "PLEASE CONFIRM" : "CONFIRM", size: 10)
            }
            Text(write.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(write.detail)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            if !write.points.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(write.points, id: \.self) { point in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(DeskTheme.copper.opacity(0.8)).frame(width: 4, height: 4).offset(y: -2)
                            Text(point)
                                .font(.system(size: 12.5))
                                .foregroundStyle(.white.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.04)))
            }
            if let acknowledge = write.acknowledge {
                Toggle(isOn: $acknowledged) {
                    Text(acknowledge)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox)
                .tint(DeskTheme.copper)
            }
            HStack(spacing: 10) {
                Text("Sent to Feathr only after you confirm.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                Button {
                    model.pending = nil
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.09)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                Button {
                    let job = write
                    model.pending = nil
                    Task { await job.run() }
                } label: {
                    Text(write.button)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(DeskTheme.ink.opacity(ready ? 1 : 0.55))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(ready ? (caution ? DeskTheme.warn : DeskTheme.copper) : DeskTheme.copper.opacity(0.3)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!ready)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 460)
        .background(DeskTheme.paper)
        .preferredColorScheme(.dark)
    }
}
