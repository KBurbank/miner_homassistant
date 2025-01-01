import SwiftUI
import AppKit

struct MQTTConfigSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State var config: MQTTConfig
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MQTT Configuration")
                .font(.title)
            
            Form {
                TextField("Host", text: $config.host)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Port", value: $config.port, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Toggle("Use Authentication", isOn: $config.useAuthentication)
                if config.useAuthentication {
                    TextField("Username", text: $config.username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    SecureField("Password", text: $config.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Save") {
                    saveConfig()
                }
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func saveConfig() {
        // Validate config
        if config.isEnabled {
            if config.host.isEmpty {
                errorMessage = "Host cannot be empty"
                showingError = true
                return
            }
            
            if config.port <= 0 {
                errorMessage = "Port must be greater than 0"
                showingError = true
                return
            }
            
            if config.useAuthentication {
                if config.username.isEmpty {
                    errorMessage = "Username cannot be empty when authentication is enabled"
                    showingError = true
                    return
                }
                if config.password.isEmpty {
                    errorMessage = "Password cannot be empty when authentication is enabled"
                    showingError = true
                    return
                }
            }
        }
        
        // Save config
        config.save()
        
        // Update HomeAssistantClient
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let haClient = appDelegate.haClient {
            haClient.updateConfig(config)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

class EditableNSTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown {
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "x":
                    if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
                case "c":
                    if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
                case "v":
                    if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
                case "a":
                    if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) { return true }
                case "z":
                    if event.modifierFlags.contains(.shift) {
                        if NSApp.sendAction(Selector(("redo:")), to: nil, from: self) { return true }
                    } else {
                        if NSApp.sendAction(Selector(("undo:")), to: nil, from: self) { return true }
                    }
                default:
                    break
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

class EditableNSSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown {
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "x":
                    if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
                case "c":
                    if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
                case "v":
                    if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
                case "a":
                    if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) { return true }
                case "z":
                    if event.modifierFlags.contains(.shift) {
                        if NSApp.sendAction(Selector(("redo:")), to: nil, from: self) { return true }
                    } else {
                        if NSApp.sendAction(Selector(("undo:")), to: nil, from: self) { return true }
                    }
                default:
                    break
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct MacTextField: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSTextField {
        let field = EditableNSTextField()
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        return field
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        
        init(text: Binding<String>) {
            self.text = text
        }
        
        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
        }
    }
}

struct MacSecureField: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSSecureTextField {
        let field = EditableNSSecureTextField()
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        return field
    }
    
    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        
        init(text: Binding<String>) {
            self.text = text
        }
        
        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
        }
    }
} 