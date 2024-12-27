import Foundation
import AppKit
import SwiftUI

@MainActor
class StatusBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var monitor: ProcessMonitor
    private var timer: Timer?
    private var fastTimer: Timer?  // For second-by-second updates
    private var isInWarningState = false
    private var isInFinalWarningState = false
    
    init(monitor: ProcessMonitor) {
        self.monitor = monitor
        super.init()
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenu()
        updateStatusBarTitle()  // Initial update
        
        // Normal timer for regular updates
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkTimerMode()
            }
        }
    }
    
    private func checkTimerMode() {
        let remainingTime = monitor.currentLimit - monitor.playedTime
        
        // Switch to fast updates in last minute
        if remainingTime <= 1 && fastTimer == nil {
            fastTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateStatusBarTitle()
                }
            }
        } else if remainingTime > 1 && fastTimer != nil {
            fastTimer?.invalidate()
            fastTimer = nil
        }
        
        updateStatusBarTitle()
    }
    
    private func formatTimeRemaining(_ remainingTime: TimeInterval) -> String {
        if remainingTime <= 0 {
            return "⏱ 0:00"
        } else if remainingTime <= 1 {
            // Show deciseconds in last minute
            let seconds = Int(remainingTime * 60)
            return String(format: "⏱ 0:%02d", seconds)
        } else if remainingTime <= 5 {
            let minutes = Int(remainingTime)
            let seconds = Int(round((remainingTime - Double(minutes)) * 60))
            
            if seconds == 60 {
                return String(format: "⏱ %d:00", minutes + 1)
            } else {
                return String(format: "⏱ %d:%02d", minutes, seconds)
            }
        } else {
            return "⏱ \(Int(round(remainingTime)))m"
        }
    }
    
    private func updateStatusBarTitle() {
        guard let button = statusItem.button else { return }
        
        if monitor.monitoredProcess != nil {
            let remainingTime = monitor.currentLimit - monitor.playedTime
            let title = formatTimeRemaining(remainingTime)
            
            // Reset warning states if we're above 5 minutes
            if remainingTime > 5 {
                isInWarningState = false
                isInFinalWarningState = false
            }
            
            if remainingTime <= 1 && remainingTime > 0 && !isInFinalWarningState {
                isInFinalWarningState = true
                isInWarningState = false  // Ensure 5-minute warning won't trigger
                NotificationManager.shared.playOneMinuteWarning()
                let attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [.foregroundColor: NSColor.systemRed]
                )
                button.attributedTitle = attributedTitle
            } else if remainingTime <= 5 && remainingTime > 1 && !isInWarningState && !isInFinalWarningState {
                isInWarningState = true
                let roundedMinutes = Int(ceil(remainingTime))
                NotificationManager.shared.playFiveMinuteWarning(remainingMinutes: roundedMinutes)
                let attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [.foregroundColor: NSColor.systemOrange]
                )
                button.attributedTitle = attributedTitle
            } else if remainingTime <= 5 {
                // Keep orange/red color for existing warnings
                let color = remainingTime <= 1 ? NSColor.systemRed : NSColor.systemOrange
                let attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [.foregroundColor: color]
                )
                button.attributedTitle = attributedTitle
            } else {
                button.title = title
            }
        } else {
            button.title = "⏱"
            isInWarningState = false
            isInFinalWarningState = false
        }
        
        // Always update menu to ensure time limit is current
        updateMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // Time played
        let timePlayedItem = NSMenuItem(title: "Time played: 0 min", action: nil, keyEquivalent: "")
        menu.addItem(timePlayedItem)
        
        // Time limit
        let timeLimitItem = NSMenuItem(title: "Time limit: 0 min", action: nil, keyEquivalent: "")
        menu.addItem(timeLimitItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add time options
        let addTimeItem = NSMenuItem(title: "Add Time", action: nil, keyEquivalent: "")
        let addTimeSubmenu = NSMenu()
        
        // Add different time increments
        [15, 30, 60].forEach { minutes in
            let item = NSMenuItem(
                title: "+\(minutes) minutes",
                action: #selector(promptForPassword(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.isEnabled = true
            item.representedObject = minutes
            addTimeSubmenu.addItem(item)
        }
        
        addTimeItem.submenu = addTimeSubmenu
        menu.addItem(addTimeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add test alert button
        let testAlertItem = NSMenuItem(
            title: "Test 5-Minute Alert",
            action: #selector(testFiveMinuteAlert),
            keyEquivalent: ""
        )
        testAlertItem.target = self
        menu.addItem(testAlertItem)
        
        // Add Password Management option
        let passwordItem = NSMenuItem(
            title: KeychainManager.shared.hasPassword() ? "Change Password" : "Set Password...",
            action: #selector(handlePasswordAction),
            keyEquivalent: ""
        )
        passwordItem.target = self
        menu.addItem(passwordItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Quit option
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        // Update menu periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenu()
            }
        }
    }
    
    @objc private func testFiveMinuteAlert() {
        Logger.shared.log("Testing five minute alert...")
        
        // Force sound to play
        NSSound.beep()
        
        // Speak test message
        let process = Process()
        process.launchPath = "/usr/bin/say"
        process.arguments = ["Testing five minute warning"]
        try? process.run()
        
        // Show orange text temporarily
        if let button = statusItem.button {
            let title = button.title
            let attributedTitle = NSAttributedString(
                string: title,
                attributes: [.foregroundColor: NSColor.systemOrange]
            )
            button.attributedTitle = attributedTitle
            
            // Reset after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                Task { @MainActor in
                    button.title = title
                }
            }
        }
        
        Logger.shared.log("Test alert triggered")
    }
    
    private func updateMenu() {
        guard let menu = statusItem.menu else { return }
        
        // Update time played
        if let timePlayedItem = menu.item(at: 0) {
            timePlayedItem.title = "Time played: \(Int(monitor.playedTime)) min"
        }
        
        // Update time limit with warning color if needed
        if let timeLimitItem = menu.item(at: 1) {
            let remainingTime = monitor.currentLimit - monitor.playedTime
            let title = "Time limit: \(Int(monitor.currentLimit)) min"
            
            if remainingTime <= 0 {
                let attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [.foregroundColor: NSColor.systemRed]
                )
                timeLimitItem.attributedTitle = attributedTitle
            } else if remainingTime <= 1 {
                let attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [.foregroundColor: NSColor.systemRed]
                )
                timeLimitItem.attributedTitle = attributedTitle
            } else if remainingTime <= 5 {
                let attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [.foregroundColor: NSColor.systemOrange]
                )
                timeLimitItem.attributedTitle = attributedTitle
            } else {
                timeLimitItem.title = title  // Reset to normal color
            }
        }
    }
    
    @objc private func promptForPassword(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? TimeInterval else { return }
        
        // If no password is set, add time directly
        if !KeychainManager.shared.hasPassword() {
            monitor.addTime(minutes)
            updateMenu()  // Update menu after adding time
            return
        }
        
        // Otherwise prompt for password
        let alert = NSAlert()
        alert.messageText = "Enter Password"
        alert.informativeText = "Please enter the password to add time:"
        
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = input
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        input.target = self
        
        alert.beginSheetModal(for: NSApp.mainWindow ?? NSApp.windows.first!) { response in
            if response == .alertFirstButtonReturn {  // OK button
                let enteredPassword = input.stringValue
                
                if KeychainManager.shared.verifyPassword(enteredPassword) {
                    self.monitor.addTime(minutes)
                    self.updateMenu()  // Update menu after adding time
                } else {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Incorrect Password"
                    errorAlert.informativeText = "The password you entered is incorrect."
                    errorAlert.alertStyle = .critical
                    errorAlert.runModal()
                }
            }
        }
    }
    
    @objc private func resetTime() {
        monitor.resetTime()
    }
    
    @objc private func promptForPasswordChange() {
        let alert = NSAlert()
        alert.messageText = "Change Password"
        alert.informativeText = "Enter current password:"
        
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = input
        alert.addButton(withTitle: "Next")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: NSApp.mainWindow ?? NSApp.windows.first!) { response in
            if response == .alertFirstButtonReturn {
                let currentPassword = input.stringValue
                
                if let correctPassword = KeychainManager.shared.getPassword(),
                   currentPassword == correctPassword {
                    self.promptForNewPassword()
                } else {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Incorrect Password"
                    errorAlert.informativeText = "The current password is incorrect."
                    errorAlert.alertStyle = .critical
                    errorAlert.runModal()
                }
            }
        }
    }
    
    @objc private func handlePasswordAction() {
        if KeychainManager.shared.hasPassword() {
            promptForPasswordChange()
        } else {
            promptForNewPassword()  // Skip current password verification
        }
    }
    
    private func promptForNewPassword() {
        let alert = NSAlert()
        alert.messageText = KeychainManager.shared.hasPassword() ? "Change Password" : "Set Password"
        alert.informativeText = "Enter new password:"
        
        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 200, height: 54))
        stackView.orientation = .vertical
        stackView.spacing = 6
        
        let newPasswordField = NSSecureTextField(frame: NSRect(x: 0, y: 30, width: 200, height: 24))
        let confirmPasswordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        
        stackView.addArrangedSubview(newPasswordField)
        stackView.addArrangedSubview(confirmPasswordField)
        
        alert.accessoryView = stackView
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: NSApp.mainWindow ?? NSApp.windows.first!) { response in
            if response == .alertFirstButtonReturn {
                let newPassword = newPasswordField.stringValue
                let confirmPassword = confirmPasswordField.stringValue
                
                if newPassword.isEmpty {
                    self.showError("Password cannot be empty")
                } else if newPassword != confirmPassword {
                    self.showError("Passwords do not match")
                } else if KeychainManager.shared.setPassword(newPassword) {
                    let successAlert = NSAlert()
                    successAlert.messageText = "Success"
                    successAlert.informativeText = "Password set successfully"
                    successAlert.alertStyle = .informational
                    successAlert.runModal()
                    
                    // Update menu to enable time adding
                    self.setupMenu()
                } else {
                    self.showError("Failed to save password")
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
} 