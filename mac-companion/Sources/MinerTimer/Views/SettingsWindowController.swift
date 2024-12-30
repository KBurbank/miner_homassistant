import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController {
    private var changePasswordButton: NSButton!
    private var weekdayField: NSTextField!
    private var weekendField: NSTextField!
    private var saveButton: NSButton!
    private let timeScheduler = TimeScheduler.shared
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        window.contentView = contentView
        
        self.init(window: window)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(window: NSWindow?) {
        super.init(window: window)
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        // Add Change Password button
        changePasswordButton = NSButton(frame: NSRect(x: 20, y: 260, width: 150, height: 24))
        changePasswordButton.title = "Change Password..."
        changePasswordButton.bezelStyle = .rounded
        changePasswordButton.target = self
        changePasswordButton.action = #selector(handlePasswordAction)
        contentView.addSubview(changePasswordButton)
        
        // Add Weekday Limit field
        let weekdayLabel = NSTextField(frame: NSRect(x: 20, y: 220, width: 100, height: 24))
        weekdayLabel.stringValue = "Weekday Limit:"
        weekdayLabel.isEditable = false
        weekdayLabel.isBordered = false
        weekdayLabel.backgroundColor = .clear
        contentView.addSubview(weekdayLabel)
        
        weekdayField = NSTextField(frame: NSRect(x: 130, y: 220, width: 60, height: 24))
        weekdayField.stringValue = "\(Int(timeScheduler.weekdayLimit.value))"
        contentView.addSubview(weekdayField)
        
        let weekdayMinLabel = NSTextField(frame: NSRect(x: 195, y: 220, width: 60, height: 24))
        weekdayMinLabel.stringValue = "minutes"
        weekdayMinLabel.isEditable = false
        weekdayMinLabel.isBordered = false
        weekdayMinLabel.backgroundColor = .clear
        contentView.addSubview(weekdayMinLabel)
        
        // Add Weekend Limit field
        let weekendLabel = NSTextField(frame: NSRect(x: 20, y: 180, width: 100, height: 24))
        weekendLabel.stringValue = "Weekend Limit:"
        weekendLabel.isEditable = false
        weekendLabel.isBordered = false
        weekendLabel.backgroundColor = .clear
        contentView.addSubview(weekendLabel)
        
        weekendField = NSTextField(frame: NSRect(x: 130, y: 180, width: 60, height: 24))
        weekendField.stringValue = "\(Int(timeScheduler.weekendLimit.value))"
        contentView.addSubview(weekendField)
        
        let weekendMinLabel = NSTextField(frame: NSRect(x: 195, y: 180, width: 60, height: 24))
        weekendMinLabel.stringValue = "minutes"
        weekendMinLabel.isEditable = false
        weekendMinLabel.isBordered = false
        weekendMinLabel.backgroundColor = .clear
        contentView.addSubview(weekendMinLabel)
        
        // Add Save button
        saveButton = NSButton(frame: NSRect(x: 20, y: 140, width: 100, height: 24))
        saveButton.title = "Save Limits"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(handleSaveAction)
        contentView.addSubview(saveButton)
    }
    
    @objc private func handlePasswordAction() {
        if PasswordStore.shared.hasPassword() {
            promptForPasswordChange()
        } else {
            promptForNewPassword()
        }
    }
    
    private func promptForPasswordChange() {
        let alert = NSAlert()
        alert.messageText = "Enter Current Password"
        alert.informativeText = "Please enter your current password:"
        
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = input
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: window!) { response in
            if response == .alertFirstButtonReturn {
                let currentPassword = input.stringValue
                Logger.shared.log("Attempting to verify password...")
                
                if PasswordStore.shared.verifyPassword(currentPassword) {
                    Logger.shared.log("Password verified successfully")
                    self.promptForNewPassword()
                } else {
                    Logger.shared.log("Password verification failed")
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Incorrect Password"
                    errorAlert.informativeText = "The current password is incorrect."
                    errorAlert.alertStyle = .critical
                    errorAlert.runModal()
                }
            }
        }
    }
    
    private func promptForNewPassword() {
        let alert = NSAlert()
        alert.messageText = PasswordStore.shared.hasPassword() ? "Change Password" : "Set Password"
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
        
        alert.beginSheetModal(for: window!) { response in
            if response == .alertFirstButtonReturn {
                let newPassword = newPasswordField.stringValue
                let confirmPassword = confirmPasswordField.stringValue
                
                if newPassword.isEmpty {
                    self.showError("Password cannot be empty")
                } else if newPassword != confirmPassword {
                    self.showError("Passwords do not match")
                } else if PasswordStore.shared.setPassword(newPassword) {
                    let successAlert = NSAlert()
                    successAlert.messageText = "Success"
                    successAlert.informativeText = "Password set successfully"
                    successAlert.alertStyle = .informational
                    successAlert.runModal()
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
    
    @objc private func handleSaveAction() {
        let alert = NSAlert()
        alert.messageText = "Enter Password"
        alert.informativeText = "Please enter the admin password to save changes:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = input
        
        alert.beginSheetModal(for: window!) { response in
            if response == .alertFirstButtonReturn {
                Task {
                    if await PasswordManager.shared.validate(input.stringValue) {
                        self.saveChanges()
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
    
    private func saveChanges() {
        guard let weekdayValue = Double(weekdayField.stringValue),
              let weekendValue = Double(weekendField.stringValue) else {
            showError("Please enter valid numbers")
            return
        }
        
        if weekdayValue < 0 || weekendValue < 0 {
            showError("Time limits cannot be negative")
            return
        }
        
        if weekdayValue > 1440 || weekendValue > 1440 {
            showError("Time limits cannot exceed 24 hours (1440 minutes)")
            return
        }
        
        timeScheduler.weekdayLimit.update(value: weekdayValue)
        timeScheduler.weekendLimit.update(value: weekendValue)
        
        let successAlert = NSAlert()
        successAlert.messageText = "Success"
        successAlert.informativeText = "Time limits saved successfully"
        successAlert.alertStyle = .informational
        successAlert.runModal()
    }
} 