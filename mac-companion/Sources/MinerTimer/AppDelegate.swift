import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    private var processMonitor: ProcessMonitor!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launched!")
        
        // Initialize ProcessMonitor
        let config = ConfigManager.loadConfig()
        let haClient = HomeAssistantClient(config: config)
        processMonitor = ProcessMonitor(haClient: haClient)
        
        // Create window
        let contentView = ContentView()
            .environmentObject(processMonitor)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window?.title = "MinerTimer"
        window?.contentView = NSHostingView(rootView: contentView)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
} 