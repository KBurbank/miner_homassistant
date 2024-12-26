import SwiftUI
import Cocoa

@main
class MinerTimerApp: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarManager!
    private var haClient: HomeAssistantClient!
    private var processMonitor: ProcessMonitor!
    private var window: NSWindow?
    
    static func main() {
        let app = NSApplication.shared
        let delegate = MinerTimerApp()
        app.delegate = delegate
        
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        
        // Initialize MQTT client
        haClient = HomeAssistantClient()
        processMonitor = ProcessMonitor(haClient: haClient)
        
        // Initialize status bar
        statusBar = StatusBarManager(monitor: processMonitor)
        
        setupWindow()
        showWindow()
    }
    
    private func setupMenu() {
        let mainMenu = NSMenu()
        
        // Application Menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(NSMenuItem(title: "About MinerTimer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showWindow), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide MinerTimer", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit MinerTimer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // Add menus to the main menu
        mainMenu.addItem(appMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    private func setupWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window?.title = "MinerTimer"
        window?.center()
        
        // Create content view with process monitor
        window?.contentView = NSHostingView(rootView: ContentView(processMonitor: processMonitor))
    }
    
    @objc func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Keep running when window is closed
    }
} 