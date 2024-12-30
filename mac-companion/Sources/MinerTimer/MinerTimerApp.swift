import SwiftUI
import Cocoa

@main
class MinerTimerApp: NSObject, NSApplicationDelegate {
    static var shared: MinerTimerApp!
    private var statusBar: StatusBarManager!
    private var haClient: HomeAssistantClient!
    public private(set) var processMonitor: ProcessMonitor!
    private var window: NSWindow?
    private var settingsWindowController: SettingsWindowController?
    private var timeScheduler: TimeScheduler!
    private let defaults = UserDefaults.standard
    private let lastCloseKey = "com.minertimer.lastCloseTime"
    
    static func main() {
        let app = NSApplication.shared
        let delegate = MinerTimerApp()
        shared = delegate  // Set shared instance
        app.delegate = delegate
        
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Log last close time if available
        if let lastClose = defaults.object(forKey: lastCloseKey) as? Date {
            Logger.shared.log("💡 Last app close: \(lastClose)")
        } else {
            Logger.shared.log("💡 No previous close time found")
        }
        
        // Initialize in correct order
        processMonitor = ProcessMonitor()
        timeScheduler = TimeScheduler.shared
        haClient = HomeAssistantClient.shared
        
        // Setup connections after initialization
        haClient.setMonitor(processMonitor)
        haClient.setTimeScheduler()
        
        // Setup main menu
        setupMainMenu()
        
        // Initialize status bar
        statusBar = StatusBarManager(monitor: processMonitor)
        
        setupWindow()
        showWindow()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Save close time
        defaults.set(Date(), forKey: lastCloseKey)
        defaults.synchronize()
        Logger.shared.log("👋 Saving app close time")
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
        window?.contentView = NSHostingView(rootView: ContentView(
            processMonitor: processMonitor
        ))
    }
    
    @objc func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc public func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Keep running when window is closed
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // Application Menu
        let appMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(NSMenuItem(title: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showSettings), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        
        // Create Hide Others item with modifiers
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Window Menu
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(NSMenuItem(title: "Show Main Window", action: #selector(showWindow), keyEquivalent: "1"))
        
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
} 