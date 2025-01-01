import Cocoa
import SwiftUI

class SettingsState: ObservableObject {
    @Published var mqttConfig = MQTTConfig.load()
    @Published var showingMQTTConfig = false
}

class SettingsWindowController: NSWindowController {
    private let state = SettingsState()
    private let timeScheduler = TimeScheduler.shared
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        
        super.init(window: window)
        
        window.contentView = NSHostingView(rootView: SettingsView(
            state: state,
            timeScheduler: timeScheduler
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct SettingsView: View {
    @ObservedObject var state: SettingsState
    let timeScheduler: TimeScheduler
    
    @State private var weekdayLimit: String
    @State private var weekendLimit: String
    @State private var showingPasswordPrompt = false
    @State private var showingPasswordChange = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var showingPasswordInput = false
    
    init(state: SettingsState, timeScheduler: TimeScheduler) {
        self.state = state
        self.timeScheduler = timeScheduler
        
        // Initialize time limits
        _weekdayLimit = State(initialValue: String(Int(timeScheduler.weekdayLimit.value)))
        _weekendLimit = State(initialValue: String(Int(timeScheduler.weekendLimit.value)))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Time Limits
                GroupBox(label: Text("Time Limits").font(.headline)) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Weekday Limit:")
                            TextField("", text: Binding(
                                get: { weekdayLimit },
                                set: { newValue in
                                    weekdayLimit = newValue.filter { $0.isNumber }
                                }
                            ))
                            .frame(width: 60)
                            Text("minutes")
                            Spacer()
                        }
                        
                        HStack {
                            Text("Weekend Limit:")
                            TextField("", text: Binding(
                                get: { weekendLimit },
                                set: { newValue in
                                    weekendLimit = newValue.filter { $0.isNumber }
                                }
                            ))
                            .frame(width: 60)
                            Text("minutes")
                            Spacer()
                        }
                        
                        HStack {
                            Spacer()
                            Button("Save Limits") {
                                showingPasswordInput = true
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.horizontal)
                
                // Password Settings
                GroupBox(label: Text("Password Settings").font(.headline)) {
                    HStack {
                        Spacer()
                        Button(PasswordStore.shared.hasPassword() ? "Change Password..." : "Set Password...") {
                            showingPasswordChange = true
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .padding(.horizontal)
                
                // MQTT Settings
                GroupBox(label: Text("MQTT Integration").font(.headline)) {
                    VStack(spacing: 8) {
                        Toggle("Enable MQTT Integration", isOn: Binding(
                            get: { state.mqttConfig.isEnabled },
                            set: { newValue in
                                state.mqttConfig.isEnabled = newValue
                                state.mqttConfig.save()
                                HomeAssistantClient.shared.updateConfig(state.mqttConfig)
                            }
                        ))
                        
                        if state.mqttConfig.isEnabled {
                            HStack {
                                Spacer()
                                Button("Configure MQTT") {
                                    state.showingMQTTConfig = true
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .frame(maxHeight: .infinity)
        .sheet(isPresented: $state.showingMQTTConfig) {
            MQTTConfigSheet(config: Binding(
                get: { state.mqttConfig },
                set: { newValue in
                    state.mqttConfig = newValue
                }
            ))
        }
        .sheet(isPresented: $showingPasswordChange) {
            VStack(spacing: 20) {
                Text(PasswordStore.shared.hasPassword() ? "Change Password" : "Set Password")
                    .font(.title)
                    .padding(.top)
                
                if PasswordStore.shared.hasPassword() {
                    SecureField("Current Password", text: $currentPassword)
                }
                
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm Password", text: $confirmPassword)
                
                HStack {
                    Button("Cancel") {
                        showingPasswordChange = false
                        resetPasswordFields()
                    }
                    
                    Button("Save") {
                        handlePasswordChange()
                    }
                }
                .padding()
            }
            .frame(width: 300, height: 250)
            .padding()
        }
        .sheet(isPresented: $showingPasswordInput) {
            VStack(spacing: 20) {
                Text("Enter Password")
                    .font(.title)
                    .padding(.top)
                
                SecureField("Password", text: $currentPassword)
                
                HStack {
                    Button("Cancel") {
                        showingPasswordInput = false
                        currentPassword = ""
                    }
                    
                    Button("Save") {
                        Task {
                            if await PasswordManager.shared.validate(currentPassword) {
                                saveLimits()
                                showingPasswordInput = false
                                currentPassword = ""
                            } else {
                                showError("Invalid password")
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(width: 300, height: 200)
            .padding()
        }
    }
    
    private func resetPasswordFields() {
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func handlePasswordChange() {
        if PasswordStore.shared.hasPassword() {
            // Verify current password
            if !PasswordStore.shared.verifyPassword(currentPassword) {
                showError("Current password is incorrect")
                return
            }
        }
        
        // Validate new password
        if newPassword.isEmpty {
            showError("Password cannot be empty")
            return
        }
        
        if newPassword != confirmPassword {
            showError("Passwords do not match")
            return
        }
        
        // Save new password
        if PasswordStore.shared.setPassword(newPassword) {
            showingPasswordChange = false
            resetPasswordFields()
        } else {
            showError("Failed to save password")
        }
    }
    
    private func saveLimits() {
        guard let weekdayValue = Double(weekdayLimit),
              let weekendValue = Double(weekendLimit) else {
            showError("Invalid time values")
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
    }
} 