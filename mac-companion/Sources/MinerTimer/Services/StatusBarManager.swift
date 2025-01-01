import AppKit
import SwiftUI
import Combine

@MainActor
class StatusBarManager: NSObject {
    private let statusItem: NSStatusItem
    private weak var monitor: ProcessMonitor?
    private weak var timeScheduler: TimeScheduler?
    private let relativeDateFormatter = RelativeDateTimeFormatter()
    private var cancellables = Set<AnyCancellable>()
    
    private var timeRemaining: Int {
        guard let timeScheduler = timeScheduler else { return 0 }
        return Int(timeScheduler.currentLimit.value - timeScheduler.playedTime.value)
    }
    
    init(monitor: ProcessMonitor?, timeScheduler: TimeScheduler) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.monitor = monitor
        self.timeScheduler = timeScheduler
        
        super.init()
        
        // Set initial button title
        if let button = statusItem.button {
            button.title = "MinerTimer"
        }
        
        // Set up the menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Set up bindings after super.init
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind to played time for remaining time display
        timeScheduler?.playedTime.$value
            .sink { [weak self] played in
                guard let self = self else { return }
                if self.monitor?.monitoredProcess != nil {
                    self.updateStatusText()
                }
            }
            .store(in: &cancellables)
        
        // Bind directly to current limit value changes
        timeScheduler?.currentLimit.$value
            .sink { [weak self] value in
                guard let self = self,
                      let menu = self.statusItem.menu,
                      let button = self.statusItem.button else { return }
                
                // Update menu
                menu.removeAllItems()
                
                // Add time limit info
                let timeLeftItem = NSMenuItem(title: "Time left: \(self.timeRemaining) minutes", action: nil, keyEquivalent: "")
                timeLeftItem.isEnabled = false
                menu.addItem(timeLeftItem)
                
                menu.addItem(NSMenuItem.separator())
                
                // Add Time submenu
                let addTimeMenu = NSMenu()
                [15, 30, 60].forEach { minutes in
                    let item = NSMenuItem(
                        title: "\(minutes) minutes",
                        action: #selector(NSApplication.addTime(_:)),
                        keyEquivalent: ""
                    )
                    item.tag = minutes
                    addTimeMenu.addItem(item)
                }
                
                let addTimeItem = NSMenuItem(title: "Add Time", action: nil, keyEquivalent: "")
                addTimeItem.submenu = addTimeMenu
                menu.addItem(addTimeItem)
                
                // Add request more time item
                menu.addItem(NSMenuItem(title: "Request more time", action: #selector(NSApplication.requestMoreTime(_:)), keyEquivalent: ""))
                
                menu.addItem(NSMenuItem.separator())
                
                // Add quit item
                menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
                
                // Update button text
                if self.monitor?.monitoredProcess != nil {
                    self.updateStatusText()
                } else {
                    button.title = "MinerTimer"
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusText() {
        guard let button = statusItem.button else { return }
        button.title = "⏰ \(timeRemaining)m"
    }
}

extension NSApplication {
    @objc func requestMoreTime(_ sender: Any?) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            Task { @MainActor in
                appDelegate.timeScheduler?.requestMoreTime()
            }
        }
    }
    
    @objc func addTime(_ sender: NSMenuItem) {
        let minutes = TimeInterval(sender.tag)
        
        let alert = NSAlert()
        alert.messageText = "Enter Password"
        alert.informativeText = "Please enter the admin password to add time:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = input
        
        alert.beginSheetModal(for: NSApp.mainWindow ?? NSApp.windows.first!) { response in
            if response == .alertFirstButtonReturn {
                Task { @MainActor in
                    if await PasswordManager.shared.validate(input.stringValue) {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.timeScheduler?.addTime(minutes)
                        }
                    } else {
                        let errorAlert = NSAlert()
                        errorAlert.messageText = "Invalid Password"
                        errorAlert.informativeText = "The password you entered is incorrect"
                        errorAlert.alertStyle = .critical
                        errorAlert.runModal()
                    }
                }
            }
        }
    }
}
