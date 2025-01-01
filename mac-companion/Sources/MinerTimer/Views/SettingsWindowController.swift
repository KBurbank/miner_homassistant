import Cocoa
import SwiftUI

class SettingsState: ObservableObject {
    @Published var mqttConfig = MQTTConfig.load()
    @Published var showingMQTTConfig = false
    @Published var showingPasswordChange = false
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
}

class SettingsWindowController: NSWindowController {
    private let state = SettingsState()
    private weak var timeScheduler: TimeScheduler?
    private weak var haClient: HomeAssistantClient?
    
    init(timeScheduler: TimeScheduler, haClient: HomeAssistantClient) {
        self.timeScheduler = timeScheduler
        self.haClient = haClient
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        
        super.init(window: window)
        
        let contentView = NSHostingView(rootView: SettingsView(state: state))
        window.contentView = contentView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct SettingsView: View {
    @ObservedObject var state: SettingsState
    @State private var showingMQTTConfig = false
    @State private var weekdayLimit: String = ""
    @State private var weekendLimit: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("Time Limits").font(.headline)) {
                HStack {
                    Text("Weekday Limit:")
                    TextField("", text: $weekdayLimit)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                    Text("minutes")
                }
                
                HStack {
                    Text("Weekend Limit:")
                    TextField("", text: $weekendLimit)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                    Text("minutes")
                }
                
                Button("Save Limits") {
                    let alert = NSAlert()
                    alert.messageText = "Enter Password"
                    alert.informativeText = "Please enter the admin password to save time limits:"
                    alert.addButton(withTitle: "OK")
                    alert.addButton(withTitle: "Cancel")
                    
                    let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                    alert.accessoryView = input
                    
                    if let window = NSApp.windows.first(where: { $0.title == "Settings" }) {
                        alert.beginSheetModal(for: window) { response in
                            if response == .alertFirstButtonReturn {
                                Task { @MainActor in
                                    if await PasswordManager.shared.validate(input.stringValue) {
                                        if let weekdayValue = Double(weekdayLimit),
                                           let weekendValue = Double(weekendLimit) {
                                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                                appDelegate.timeScheduler.weekdayLimit.update(value: weekdayValue)
                                                appDelegate.timeScheduler.weekendLimit.update(value: weekendValue)
                                            }
                                        }
                                    } else {
                                        let errorAlert = NSAlert()
                                        errorAlert.messageText = "Invalid Password"
                                        errorAlert.informativeText = "The password you entered is incorrect"
                                        errorAlert.alertStyle = .critical
                                        errorAlert.beginSheetModal(for: window, completionHandler: nil)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(.bottom)
            
            Section(header: Text("Password Settings").font(.headline)) {
                Button(PasswordStore.shared.hasPassword() ? "Change Password..." : "Set Password...") {
                    state.showingPasswordChange = true
                }
            }
            .padding(.bottom)
            
            Section(header: Text("MQTT Settings").font(.headline)) {
                Toggle("Enable MQTT", isOn: Binding(
                    get: { state.mqttConfig.isEnabled },
                    set: { newValue in
                        state.mqttConfig.isEnabled = newValue
                        state.mqttConfig.save()
                        if let haClient = (NSApp.delegate as? AppDelegate)?.haClient {
                            haClient.updateConfig(state.mqttConfig)
                        }
                    }
                ))
                
                Button("Configure MQTT") {
                    showingMQTTConfig = true
                }
                .disabled(!state.mqttConfig.isEnabled)
            }
        }
        .padding(20)
        .onAppear {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                weekdayLimit = String(Int(appDelegate.timeScheduler.weekdayLimit.value))
                weekendLimit = String(Int(appDelegate.timeScheduler.weekendLimit.value))
            }
        }
        .sheet(isPresented: $showingMQTTConfig) {
            MQTTConfigSheet(config: state.mqttConfig)
        }
        .sheet(isPresented: $state.showingPasswordChange) {
            PasswordChangeView(state: state)
        }
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct PasswordChangeView: View {
    @ObservedObject var state: SettingsState
    @Environment(\.presentationMode) var presentationMode
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(PasswordStore.shared.hasPassword() ? "Change Password" : "Set Password")
                .font(.title)
                .padding(.top)
            
            if PasswordStore.shared.hasPassword() {
                SecureField("Current Password", text: $state.currentPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            SecureField("New Password", text: $state.newPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            SecureField("Confirm Password", text: $state.confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    resetFields()
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Save") {
                    handlePasswordChange()
                }
            }
            .padding()
        }
        .frame(width: 300)
        .padding()
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func resetFields() {
        state.currentPassword = ""
        state.newPassword = ""
        state.confirmPassword = ""
    }
    
    private func handlePasswordChange() {
        if PasswordStore.shared.hasPassword() {
            // Verify current password
            if !PasswordStore.shared.verifyPassword(state.currentPassword) {
                errorMessage = "Current password is incorrect"
                showingError = true
                return
            }
        }
        
        // Validate new password
        if state.newPassword.isEmpty {
            errorMessage = "Password cannot be empty"
            showingError = true
            return
        }
        
        if state.newPassword != state.confirmPassword {
            errorMessage = "Passwords do not match"
            showingError = true
            return
        }
        
        // Save new password
        if PasswordStore.shared.setPassword(state.newPassword) {
            resetFields()
            presentationMode.wrappedValue.dismiss()
        } else {
            errorMessage = "Failed to save password"
            showingError = true
        }
    }
} 