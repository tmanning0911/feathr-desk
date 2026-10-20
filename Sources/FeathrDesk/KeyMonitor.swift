import AppKit

/// Desk-wide keys that SwiftUI menus cannot own: Esc, ↑/↓, and Return outside text fields, plus palette navigation.
@MainActor
final class KeyMonitor {
    static let shared = KeyMonitor()
    private var token: Any?

    private enum Code {
        static let escape: UInt16 = 53
        static let returnKey: UInt16 = 36
        static let enter: UInt16 = 76
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    func install(_ model: DeskModel) {
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak model] event in
            guard let model else { return event }
            let handled = MainActor.assumeIsolated { Self.handle(event, model) }
            return handled ? nil : event
        }
    }

    private static func handle(_ event: NSEvent, _ model: DeskModel) -> Bool {
        guard let window = event.window, !(window is NSPanel), window.sheetParent == nil, window.attachedSheet == nil else { return false }
        guard event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else { return false }
        let editing = window.firstResponder is NSText

        switch event.keyCode {
        case Code.escape:
            if model.paletteOpen { model.closePalette(); return true }
            if editing { window.makeFirstResponder(nil); return true }
            if !model.selected.isEmpty { model.clearSelection(); return true }
            if model.errorText != nil { model.errorText = nil; return true }
            return false
        case Code.down, Code.up:
            let step = event.keyCode == Code.down ? 1 : -1
            if model.paletteOpen { model.movePalette(step); return true }
            if editing {
                guard step == 1, model.section.hasSearch, !model.visibleRows.isEmpty else { return false }
                window.makeFirstResponder(nil)
                model.moveSelection(1)
                return true
            }
            guard !model.visibleRows.isEmpty else { return false }
            model.moveSelection(step)
            return true
        case Code.returnKey, Code.enter:
            if model.paletteOpen { model.runPalette(); return true }
            guard !editing, !model.selected.isEmpty else { return false }
            model.activateSelection()
            return true
        default:
            return false
        }
    }
}
