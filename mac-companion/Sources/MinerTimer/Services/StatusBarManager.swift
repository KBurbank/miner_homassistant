import AppKit
import SwiftUI
import Combine

@MainActor
class StatusBarManager: NSObject {
    private let statusItem: NSStatusItem
    private weak var monitor: ProcessMonitor?
    private let timeScheduler = TimeScheduler.shared
    private let relativeDateFormatter = RelativeDateTimeFormatter()
    private var cancellables = Set<AnyCancellable>()
    private var pendingMinutes: TimeInterval?
    
    init(monitor: ProcessMonitor? = nil) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.monitor = monitor
        
        super.init()
        
        if let button = statusItem.button {
            button.title = "Not Running"
            button.font = NSFont.menuBarFont(ofSize: 0)
        }
        
        setupMenu()
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind to played time for remaining time display
        timeScheduler.playedTime.$value
            .sink { [weak self] played in
                guard let self = self else { return }
                if self.monitor?.monitoredProcess != nil {
                    let remainingTime = self.timeScheduler.currentLimit.value - played
                    let title = self.formatTimeRemaining(remainingTime)
                    self.statusItem.button?.title = title
                }
            }
            .store(in: &cancellables)
        
        // Bind directly to current limit value changes
        timeScheduler.currentLimit.$value
            .sink { [weak self] value in
                guard let self = self,
                      let menu = self.statusItem.menu,
                      let timeLimitItem = menu.item(at: 1) else { return }
                
                let current = self.timeScheduler.currentLimit
                var menuTitle = "Current Limit: \(Int(value)) min"
                menuTitle += " (changed \(self.relativeDateFormatter.string(for: current.lastChanged) ?? ""))"
                let remainingTime = value - self.timeScheduler.playedTime.value
                self.updateMenuItemColor(timeLimitItem, title: menuTitle, remainingTime: remainingTime)
            }
            .store(in: &cancellables)
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Status", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Current Limit", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let addTimeMenu = NSMenu()
        [15, 30, 60].forEach { minutes in
            let item = NSMenuItem(
                title: "\(minutes) minutes",
                action: #selector(handleAddTime(_:)),
                keyEquivalent: ""
            )
            item.tag = minutes
            item.target = self
            addTimeMenu.addItem(item)
        }
        
        let addTimeItem = NSMenuItem(title: "Add Time", action: nil, keyEquivalent: "")
        addTimeItem.submenu = addTimeMenu
        menu.addItem(addTimeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func handleAddTime(_ sender: NSMenuItem) {
        pendingMinutes = TimeInterval(sender.tag)
        promptForPassword()
    }
    
    @objc private func showSettings() {
        MinerTimerApp.shared.showSettings()
    }
    
    private func promptForPassword() {
        guard let pendingMinutes = pendingMinutes else { return }
        
        let alert = NSAlert()
        alert.messageText = "Enter Password"
        alert.informativeText = "Please enter the admin password to add time:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = input
        
        alert.beginSheetModal(for: NSApp.mainWindow ?? NSApp.windows.first!) { response in
            if response == .alertFirstButtonReturn {
                Task {
                    if await PasswordManager.shared.validate(input.stringValue) {
                        self.timeScheduler.addTime(pendingMinutes)
                    } else {
                        let errorAlert = NSAlert()
                        errorAlert.messageText = "Invalid Password"
                        errorAlert.informativeText = "The password you entered is incorrect"
                        errorAlert.alertStyle = .critical
                        errorAlert.runModal()
                    }
                    self.pendingMinutes = nil
                }
            }
        }
    }
    
    private func formatTimeRemaining(_ minutes: TimeInterval) -> String {
        return "\(Int(minutes))m"
    }
    
    private func updateMenuItemColor(_ item: NSMenuItem, title: String, remainingTime: TimeInterval) {
        item.title = title
        if remainingTime <= 5 {
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [.foregroundColor: NSColor.systemRed]
            )
        } else {
            item.attributedTitle = nil
        }
    }
}
