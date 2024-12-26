import Foundation
import AppKit

struct ConfigManager {
    static let configPath = "/Users/Shared/minertimer/config.json"
    
    static func loadConfig() -> HAConfig {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            return try JSONDecoder().decode(HAConfig.self, from: data)
        } catch {
            Logger.shared.log("Error loading config: \(error)")
            fatalError("Could not load config.json")
        }
    }
} 