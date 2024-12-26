import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private var processMonitor: ProcessMonitor!
    private let haClient = HomeAssistantClient()  // Create MQTT client
    
    override init() {
        super.init()
        Task {
            self.processMonitor = ProcessMonitor(haClient: haClient)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("Application did finish launching")
        
        // Create and show main window immediately
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "MinerTimer"
        window.center()
        
        // Create content view with process monitor
        window.contentView = NSHostingView(rootView: ContentView(processMonitor: processMonitor))
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
} 