import Cocoa
import SwiftUI

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        
        let contentView = NSHostingView(rootView: SettingsWindow())
        window.contentView = contentView
        
        self.init(window: window)
    }
} 