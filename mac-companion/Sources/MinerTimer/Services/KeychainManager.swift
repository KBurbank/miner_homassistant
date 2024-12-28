import Foundation
import CryptoKit

class KeychainManager {
    static let shared = KeychainManager()
    private let defaults = UserDefaults.standard
    private let passwordKey = "com.minertimer.password"
    private let salt = "MinerTimer2024"
    
    private init() {}
    
    func hasPassword() -> Bool {
        let has = getPassword() != nil
        Logger.shared.log("🔐 Has password: \(has)")
        return has
    }
    
    func getPassword() -> String? {
        guard let encrypted = defaults.string(forKey: passwordKey) else {
            Logger.shared.log("🔐 No password found in defaults")
            return nil
        }
        Logger.shared.log("🔐 Retrieved stored hash: \(encrypted)")
        return encrypted
    }
    
    func setPassword(_ password: String) -> Bool {
        Logger.shared.log("🔑 === SETTING NEW PASSWORD ===")
        let encrypted = encrypt(password)
        Logger.shared.log("🔑 Generated hash: \(encrypted)")
        defaults.set(encrypted, forKey: passwordKey)
        defaults.synchronize()
        
        // Verify it was saved
        if let saved = defaults.string(forKey: passwordKey) {
            Logger.shared.log("🔑 Verified saved hash: \(saved)")
            return true
        } else {
            Logger.shared.log("❌ Failed to save password!")
            return false
        }
    }
    
    private func encrypt(_ string: String) -> String {
        Logger.shared.log("🔒 === ENCRYPTING ===")
        let combined = string + salt
        if let data = combined.data(using: .utf8) {
            let hash = SHA256.hash(data: data)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
            Logger.shared.log("🔒 Generated hash: \(hashString)")
            return hashString
        }
        Logger.shared.log("❌ Failed to generate hash")
        return ""
    }
    
    func verifyPassword(_ input: String) -> Bool {
        Logger.shared.log("\n🔓 === VERIFYING PASSWORD ===")
        
        guard let storedHash = getPassword() else {
            Logger.shared.log("🔓 No stored password found")
            return false
        }
        Logger.shared.log("🔓 Retrieved stored hash: \(storedHash)")
        
        let inputHash = encrypt(input)
        Logger.shared.log("🔓 Generated hash from input: \(inputHash)")
        
        let matches = inputHash == storedHash
        Logger.shared.log("🔓 === COMPARISON ===")
        Logger.shared.log("🔓 Stored:  \(storedHash)")
        Logger.shared.log("🔓 Input:   \(inputHash)")
        Logger.shared.log("🔓 Match:   \(matches)\n")
        
        return matches
    }
} 