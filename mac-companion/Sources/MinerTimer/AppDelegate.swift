import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor public private(set) var processMonitor: ProcessMonitor!
    @MainActor private var statusBar: StatusBarManager!
    private var window: NSWindow!
    @MainActor private var haClient: HomeAssistantClient!
    private var settingsWindowController: SettingsWindowController?
    private var isInitialized = false
    
    override init() {
        super.init()
        
        // Save last close time on exit
        atexit {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "last_close_time")
        }
        
        // Set up the main menu
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        
        // Application Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        // About Item
        let aboutItem = NSMenuItem(
            title: "About MinerTimer",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Settings Item
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(AppDelegate.showSettings),
            keyEquivalent: ","
        )
        appMenu.addItem(settingsItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Quit Item
        let quitItem = NSMenuItem(
            title: "Quit MinerTimer",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            // Initialize components
            processMonitor = ProcessMonitor()
            Logger.shared.log("🔨 Created ProcessMonitor")
            
            // Set up TimeScheduler with ProcessMonitor
            Logger.shared.log("🔄 Setting ProcessMonitor in TimeScheduler")
            await TimeScheduler.shared.setProcessMonitor(processMonitor)
            
            // Set up HomeAssistant client
            haClient = HomeAssistantClient.shared
            await haClient.setTimeScheduler()
            
            // Create the status bar
            statusBar = StatusBarManager(monitor: processMonitor)
            
            // Create the window
            let contentView = ContentView(
                processMonitor: processMonitor
            )
            
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.setFrameAutosaveName("Main Window")
            window.contentView = NSHostingView(rootView: contentView)
            window.makeKeyAndOrderFront(nil)
            
            isInitialized = true
        }
    }
    
    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        // Resume process if it was suspended
        if let process = processMonitor?.monitoredProcess,
           process.state == .suspended {
            processMonitor.resumeProcess()
        }
    }
    
    @objc func showSettings() {
        guard isInitialized else { return }
        
        Logger.shared.log("Settings requested")
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
} 