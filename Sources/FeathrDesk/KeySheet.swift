import SwiftUI

struct KeySheet: View {
    @ObservedObject var model: DeskModel
    @Environment(\.dismiss) private var dismiss
    @State private var pasted = ""
    @State private var saving = false

    private var looksValid: Bool {
        pasted.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("fthr_")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeskBadge(text: "FEATHR KEY", size: 10)
            Text("The key stays in this Mac’s Keychain.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(currentKey)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
            SecureField("fthr_…", text: $pasted)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if looksValid { save() } }
            if !pasted.isEmpty && !looksValid {
                Text("A Feathr key starts with fthr_.")
                    .font(.system(size: 11))
                    .foregroundStyle(DeskTheme.copper)
            }
            Text("Create keys in Feathr settings. Reading works with any key; editing people, tags, or sync needs persons:write, tags:write, or webhooks:write.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(saving ? "Connecting…" : "Save and connect") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!looksValid || saving)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(DeskTheme.paper)
        .preferredColorScheme(.dark)
    }

    private var currentKey: String {
        guard !model.keySource.isEmpty else { return "Nothing stored yet." }
        let ending = model.lastFour.isEmpty ? "" : ", ending …\(model.lastFour)"
        let state = model.phase == .keyRejected ? " Feathr is no longer accepting it." : ""
        return "Current key from \(model.keySource)\(ending).\(state)"
    }

    private func save() {
        saving = true
        Task {
            await model.replaceKey(pasted)
            pasted = ""
            saving = false
            dismiss()
        }
    }
}
