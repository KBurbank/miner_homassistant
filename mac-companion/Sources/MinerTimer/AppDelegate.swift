import AppKit
import SwiftUI

@MainActor
@available(macOS 10.15, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private var processMonitor: ProcessMonitor!
    private var timeScheduler: TimeScheduler!
    private let haClient = HomeAssistantClient.shared
    private var statusBar: StatusBarManager!
    
    override init() {
        super.init()
        processMonitor = ProcessMonitor()
        timeScheduler = TimeScheduler.shared
        haClient.setMonitor(processMonitor)
        haClient.setTimeScheduler()
        statusBar = StatusBarManager()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("Application did finish launching")
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "MinerTimer"
        window.center()
        
        window.contentView = NSHostingView(rootView: ContentView(
            processMonitor: processMonitor
        ))
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
} 