import Cocoa

@MainActor
class StatusBarManager: ObservableObject {
    static let shared = StatusBarManager()
    private var statusItem: NSStatusItem!
    private weak var app: MinerTimerApp?
    private var processMonitor: ProcessMonitor?
    private var timer: Timer?
    
    private init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // Add time display item (non-interactive)
        let timeItem = NSMenuItem(title: "Time Remaining", action: nil, keyEquivalent: "")
        timeItem.isEnabled = false
        menu.addItem(timeItem)
        
        // Add time adjustment submenu
        let timeMenu = NSMenu()
        let timeSubmenu = NSMenuItem(title: "Add Time", action: nil, keyEquivalent: "")
        timeSubmenu.submenu = timeMenu
        
        // Add time options
        let timeOptions = [15, 30, 60]
        for minutes in timeOptions {
            let item = NSMenuItem(
                title: "\(minutes) minutes",
                action: #selector(addTime(_:)),
                keyEquivalent: ""
            )
            item.tag = minutes
            item.target = self
            timeMenu.addItem(item)
        }
        
        menu.addItem(timeSubmenu)
        menu.addItem(NSMenuItem.separator())
        
        // Existing menu items
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    func setApp(_ app: MinerTimerApp) {
        self.app = app
    }
    
    func setProcessMonitor(_ monitor: ProcessMonitor) {
        self.processMonitor = monitor
        
        // Update immediately
        updateDisplay()
        
        // Start timer for updates
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDisplay()
            }
        }
    }
    
    private func updateDisplay() {
        guard let monitor = processMonitor else { return }
        
        let remainingTime = monitor.currentLimit - monitor.playedTime
        let hours = Int(remainingTime) / 60
        let minutes = Int(remainingTime) % 60
        
        var title = "⏱ "
        
        if let process = monitor.monitoredProcess {
            switch process.state {
            case .running:
                if hours > 0 {
                    title += "\(hours)h \(minutes)m"
                } else {
                    title += "\(minutes)m"
                }
            case .suspended:
                title += "Paused"
            }
        } else {
            if hours > 0 {
                title += "\(hours)h \(minutes)m"
            } else {
                title += "\(minutes)m"
            }
        }
        
        statusItem.button?.title = title
        
        // Update the time display menu item if it exists
        if let menu = statusItem.menu,
           let timeItem = menu.items.first {
            timeItem.title = "Time Remaining: \(hours)h \(minutes)m"
        }
    }
    
    @objc private func showWindow() {
        app?.window?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func addTime(_ sender: NSMenuItem) {
        guard let monitor = processMonitor else { return }
        let minutes = TimeInterval(sender.tag)
        
        // Create password prompt
        let alert = NSAlert()
        alert.messageText = "Enter Password"
        alert.informativeText = "Password required to add time"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = input
        
        input.becomeFirstResponder()
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let password = input.stringValue
            
            if PasswordManager.shared.checkPassword(password) {
                Task {
                    do {
                        let currentLimit = try await monitor.getCurrentLimit()
                        try await monitor.updateLimit(currentLimit + minutes)
                        Logger.shared.log("Added \(minutes) minutes to time limit")
                        
                        await MainActor.run {
                            monitor.currentLimit = currentLimit + minutes
                            updateDisplay()
                        }
                    } catch {
                        Logger.shared.log("Error adding time: \(error.localizedDescription)")
                    }
                }
            } else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Incorrect Password"
                errorAlert.informativeText = "The password you entered is incorrect"
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
            }
        }
    }
} 