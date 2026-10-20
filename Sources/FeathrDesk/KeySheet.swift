import SwiftUI

struct KeySheet: View {
    @ObservedObject var model: DeskModel
    @Environment(\.dismiss) private var dismiss
    @State private var pasted = ""

    private var looksValid: Bool {
        pasted.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("fthr_")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeskBadge(text: "KEY", size: 11)
            Text("The key stays in the Keychain.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(model.keySource.isEmpty ? "Nothing stored yet." : "Current key from \(model.keySource)\(model.lastFour.isEmpty ? "" : ", ending …\(model.lastFour)").")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            SecureField("fthr_…", text: $pasted)
                .textFieldStyle(.roundedBorder)
            if !pasted.isEmpty && !looksValid {
                Text("A Feathr key starts with fthr_.")
                    .font(.system(size: 11))
                    .foregroundStyle(DeskTheme.copper)
            }
            HStack {
                Button("Save") {
                    Task {
                        await model.replaceKey(pasted)
                        pasted = ""
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!looksValid)
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
