import AppKit
import SwiftUI

@MainActor
@available(macOS 10.15, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    public private(set) var processMonitor: ProcessMonitor!
    private var timeScheduler: TimeScheduler!
    private var haClient: HomeAssistantClient!
    private var statusBar: StatusBarManager!
    private var settingsWindowController: SettingsWindowController?
    
    override init() {
        super.init()
        Logger.shared.log("🚀 AppDelegate initializing...")
        
        processMonitor = ProcessMonitor()
        Logger.shared.log("🔨 Created ProcessMonitor")
        
        timeScheduler = TimeScheduler.shared
        
        Logger.shared.log("🔄 Setting ProcessMonitor in TimeScheduler")
        TimeScheduler.shared.setProcessMonitor(processMonitor)
        
        haClient = HomeAssistantClient.shared
        haClient.setMonitor(processMonitor)
        haClient.setTimeScheduler()
        
        Logger.shared.log("🚀 AppDelegate initialization complete")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("🚀 AppDelegate initializing...")
        
        // Check last close time
        let defaults = UserDefaults.standard
        let lastCloseTime = defaults.double(forKey: "last_close_time")
        if lastCloseTime > 0 {
            Logger.shared.log("📖 Last close time: \(lastCloseTime)")
        } else {
            Logger.shared.log("⚠️ No last close time found")
        }
        
        Logger.shared.log("Application did finish launching")
        
        // Initialize status bar after app is launched
        statusBar = StatusBarManager(monitor: processMonitor)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "MinerTimer"
        window.center()
        window.isReleasedWhenClosed = false
        
        window.contentView = NSHostingView(rootView: ContentView(
            processMonitor: processMonitor
        ))
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    @objc public func showSettings() {
        Logger.shared.log("Settings requested")
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.log("🔄 Application terminating...")
        
        // Save last close time
        let closeTime = Date().timeIntervalSince1970
        let defaults = UserDefaults.standard
        defaults.set(closeTime, forKey: "last_close_time")
        defaults.synchronize()
        
        Logger.shared.log("💾 Saved last close time: \(closeTime)")
        
        // Give logger time to write
        Thread.sleep(forTimeInterval: 0.1)
    }
} 