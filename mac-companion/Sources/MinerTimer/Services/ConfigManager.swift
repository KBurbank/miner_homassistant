import Foundation
import AppKit

class ConfigManager {
    static let shared = ConfigManager()
    private let configURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MinerTimer/config.json")
    
    static func loadConfig() -> HAConfig {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("MinerTimer")
        let configFile = configDir.appendingPathComponent("config.json")
        
        Logger.shared.log("Loading config from: \(configFile.path)")
        
        do {
            let data = try Data(contentsOf: configFile)
            let config = try JSONDecoder().decode(HAConfig.self, from: data)
            Logger.shared.log("Loaded config successfully:")
            Logger.shared.log("- Base URL: \(config.baseURL)")
            Logger.shared.log("- Entity ID: \(config.entityID)")
            Logger.shared.log("- Token length: \(config.token.count) chars")
            return config
        } catch {
            Logger.shared.log("Error loading config: \(error)")
            Logger.shared.log("Using default config")
            
            // Create default config
            let config = HAConfig(
                baseURL: URL(string: "http://homeassistant:8123")!,
                token: "",
                entityID: "input_number.usage_limit"
            )
            
            // Try to save it
            try? fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
            try? JSONEncoder().encode(config).write(to: configFile)
            
            return config
        }
    }
    
    private func readConfig() -> HAConfig? {
        guard let data = try? Data(contentsOf: configURL) else { return nil }
        return try? JSONDecoder().decode(HAConfig.self, from: data)
    }
    
    private func createDefaultConfig() throws -> HAConfig {
        // First try environment variables
        if let url = ProcessInfo.processInfo.environment["HASS_URL"],
           let token = ProcessInfo.processInfo.environment["HASS_TOKEN"],
           let entity = ProcessInfo.processInfo.environment["HASS_ENTITY"] {
            return HAConfig(
                baseURL: URL(string: url)!,
                token: token,
                entityID: entity
            )
        }
        
        // If no environment variables, show settings window
        DispatchQueue.main.async(execute: DispatchWorkItem {
            NSApplication.shared.sendAction(
                Selector(("showSettingsWindow:")),
                to: nil,
                from: nil
            )
        })
        
        // Return temporary config that will be updated in settings
        return HAConfig(
            baseURL: URL(string: "http://homeassistant:8123")!,
            token: "",
            entityID: "input_number.usage_limit"
        )
    }
    
    func saveConfig(_ config: HAConfig) throws {
        let data = try JSONEncoder().encode(config)
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: configURL)
    }
} 