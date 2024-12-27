import Foundation
import CryptoKit

class KeychainManager {
    static let shared = KeychainManager()
    private let defaults = UserDefaults.standard
    private let passwordKey = "com.minertimer.password"
    private let salt = "MinerTimer2024"
    
    private init() {
        // Check if we're running on Catalina or later
        if #available(macOS 10.15, *) {
            // We're good to use CryptoKit
        } else {
            Logger.shared.log("⚠️ Running on pre-Catalina, using fallback encryption")
        }
    }
    
    func hasPassword() -> Bool {
        return getPassword() != nil
    }
    
    func getPassword() -> String? {
        guard let encodedPassword = defaults.string(forKey: passwordKey) else {
            Logger.shared.log("No password found in defaults")
            return nil
        }
        return decrypt(encodedPassword)
    }
    
    func setPassword(_ password: String) -> Bool {
        let encoded = encrypt(password)
        defaults.set(encoded, forKey: passwordKey)
        return true
    }
    
    private func encrypt(_ string: String) -> String {
        if #available(macOS 10.15, *) {
            let combined = string + salt
            if let data = combined.data(using: .utf8) {
                let hash = SHA256.hash(data: data)
                return hash.compactMap { String(format: "%02x", $0) }.joined()
            }
        } else {
            // Fallback for pre-Catalina: simple XOR with salt
            let combined = string + salt
            var result = ""
            for (index, char) in combined.utf8.enumerated() {
                let saltChar = salt.utf8[salt.utf8.index(salt.utf8.startIndex, offsetBy: index % salt.utf8.count)]
                result += String(format: "%02x", char ^ saltChar)
            }
            return result
        }
        return ""
    }
    
    private func decrypt(_ encoded: String) -> String? {
        // Since we're using a hash, we can't decrypt
        // Instead, we'll store the hash and compare hashes
        return encoded
    }
    
    func verifyPassword(_ input: String) -> Bool {
        guard let stored = getPassword() else { return false }
        return encrypt(input) == stored
    }
} 