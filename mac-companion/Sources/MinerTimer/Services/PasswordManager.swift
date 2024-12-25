import Foundation

class PasswordManager {
    static let shared = PasswordManager()
    private let passwordFile = "/Users/Shared/minertimer/password.txt"
    
    private init() {}
    
    func checkPassword(_ input: String) -> Bool {
        guard let storedPassword = try? String(contentsOfFile: passwordFile, encoding: .utf8) else {
            Logger.shared.log("Error: Password file not found")
            return false
        }
        
        // Trim whitespace and newlines
        let cleanPassword = storedPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        return input == cleanPassword
    }
} 