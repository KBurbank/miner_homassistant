import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var processMonitor: ProcessMonitor!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize ProcessMonitor
        processMonitor = ProcessMonitor(haClient: nil)
        
        // Create window
        let contentView = ContentView(processMonitor: processMonitor)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "MinerTimer"
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        // Start services
        Task {
            await ServiceManager.shared.startServices()
            if let haClient = ServiceManager.shared.getHAClient() {
                processMonitor.setHAClient(haClient)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
} 