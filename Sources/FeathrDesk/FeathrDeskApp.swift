import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            for window in NSApp.windows where !(window is NSPanel) {
                window.title = "Feathr Desk"
                window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor(calibratedRed: 0.11, green: 0.10, blue: 0.09, alpha: 1)
                window.tabbingMode = .disallowed
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct FeathrDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = DeskModel()

    var body: some Scene {
        WindowGroup {
            DeskView(model: model)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About Feathr Desk") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Feathr Desk",
                        .applicationVersion: DeskInfo.version,
                    ])
                }
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh Desk") {
                    Task { await model.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: .command)
                Button("Find…") {
                    model.requestFocus()
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            CommandMenu("Go") {
                ForEach(Array(DeskSection.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.rawValue) { model.go(section) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Divider()
                Button("Recent gifts") { model.showActivity(flavor: ActivityKind.donation.flavor) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }
    }
}
