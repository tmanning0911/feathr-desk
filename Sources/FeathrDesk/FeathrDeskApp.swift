import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            for window in NSApp.windows where !(window is NSPanel) {
                window.title = "Feathr Desk"
                window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.07, blue: 0.065, alpha: 1)
                window.tabbingMode = .disallowed
                window.setFrameAutosaveName("FeathrDeskMain")
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DeskModel.markCleanExit()
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
        .defaultSize(width: 1240, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Selected Person") { model.activateSelection() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .appInfo) {
                Button("About Feathr Desk") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Feathr Desk",
                        .applicationVersion: DeskInfo.version,
                        .version: "Build \(DeskInfo.build)",
                        .credits: NSAttributedString(
                            string: "The daily operator desk for Mid-Fairfield’s Feathr account. Email still sends from Feathr.",
                            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
                        ),
                    ])
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Feathr Key…") { model.showKeySheet = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .sidebar) {
                Button(model.sidebarCollapsed ? "Show Sidebar Labels" : "Collapse Sidebar") { model.toggleSidebar() }
                    .keyboardShortcut("s", modifiers: [.command, .control])
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
                Button("Clear Selection") { model.clearSelection() }
                    .disabled(model.selected.isEmpty)
            }
            CommandMenu("Go") {
                Button("Command Palette…") { model.openPalette() }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Back") { model.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!model.canGoBack)
                Divider()
                ForEach(Array(DeskSection.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.rawValue) { model.go(section) }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Divider()
                Button("Recent Gifts") { model.showActivity(flavor: ActivityKind.donation.flavor) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Salesforce Sync") { model.go(.webhooks) }
                    .keyboardShortcut("y", modifiers: [.command, .shift])
            }
        }
    }
}
