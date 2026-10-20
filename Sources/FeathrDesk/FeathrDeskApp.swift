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
        }
    }
}
