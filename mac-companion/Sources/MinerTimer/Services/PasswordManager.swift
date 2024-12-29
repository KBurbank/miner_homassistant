import Foundation

@MainActor
class PasswordManager {
    static let shared = PasswordManager()
    private let store = PasswordStore()
    
    private init() {}
    
    func validate(_ password: String) async -> Bool {
        return store.verifyPassword(password)
    }
} 