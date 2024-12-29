import SwiftUI

@available(macOS 10.15, *)
struct PasswordSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var password = ""
    
    var body: some View {
        VStack {
            SecureField("Password", text: $password)
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                Button("OK") {
                    if PasswordStore.shared.verifyPassword(password) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .padding()
    }
} 