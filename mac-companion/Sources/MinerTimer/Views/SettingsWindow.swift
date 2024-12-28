import AppKit

class SettingsWindowController: NSWindowController {
    private var changePasswordButton: NSButton!
    
    init() {
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
        
        super.init(window: window)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    }
    
    @objc private func handlePasswordAction() {
        if KeychainManager.shared.hasPassword() {
            promptForPasswordChange()
        } else {
            promptForNewPassword()  // Skip current password verification
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
                Logger.shared.log("Attempting to verify password...")  // Add logging
                
                // Direct verification
                if KeychainManager.shared.verifyPassword(currentPassword) {
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
        
        alert.beginSheetModal(for: window!) { response in
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