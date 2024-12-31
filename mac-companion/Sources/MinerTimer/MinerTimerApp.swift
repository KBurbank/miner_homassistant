import Cocoa
import SwiftUI

@main
struct MinerTimerApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        
        // Set up the main menu
        let mainMenu = NSMenu()
        app.mainMenu = mainMenu
        
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
        
        app.run()
    }
} 