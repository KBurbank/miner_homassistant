import SwiftUI
import AppKit

struct MQTTConfigSheet: View {
    @Binding var config: MQTTConfig
    @Environment(\.presentationMode) var presentationMode
    
    // Local state for form
    @State private var host: String
    @State private var port: String
    @State private var useAuthentication: Bool
    @State private var username: String
    @State private var password: String
    
    init(config: Binding<MQTTConfig>) {
        self._config = config
        
        // Initialize local state from config
        _host = State(initialValue: config.wrappedValue.host)
        _port = State(initialValue: String(config.wrappedValue.port))
        _useAuthentication = State(initialValue: config.wrappedValue.useAuthentication)
        _username = State(initialValue: config.wrappedValue.username)
        _password = State(initialValue: config.wrappedValue.password)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MQTT Configuration")
                .font(.title)
                .padding(.top)
            
            Form {
                Section(header: Text("Connection Settings")) {
                    TextField("Host (e.g. homeassistant)", text: $host)
                    TextField("Port", text: Binding(
                        get: { port },
                        set: { newValue in
                            // Only allow numbers
                            port = newValue.filter { $0.isNumber }
                        }
                    ))
                }
                
                Section(header: Text("Authentication")) {
                    Toggle("Use Authentication", isOn: $useAuthentication)
                    
                    if useAuthentication {
                        HStack {
                            Text("Username:")
                            MacTextField(text: $username)
                        }
                        HStack {
                            Text("Password:")
                            MacSecureField(text: $password)
                        }
                    }
                }
            }
            .padding()
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Save") {
                    saveConfig()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding(.bottom)
        }
        .frame(width: 400, height: 400)
    }
    
    private func saveConfig() {
        // Update config with form values
        config.host = host
        config.port = Int(port) ?? 1883
        config.useAuthentication = useAuthentication
        config.username = username
        config.password = password
        
        // Save to disk
        config.save()
        
        // Update HomeAssistantClient
        HomeAssistantClient.shared.updateConfig(config)
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