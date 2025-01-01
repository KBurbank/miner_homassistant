import Foundation

private struct TimeValueData: Codable {
    let value: TimeInterval
    let lastUpdated: Date
}

public class TimeValue: Codable, Equatable, ObservableObject {
    @Published public internal(set) var value: TimeInterval
    var lastChanged: Date
    let baseKey: String?
    let isBaseLimit: Bool
    let name: String
    
    private var updatingFromMQTT = false
    
    init(value: TimeInterval, lastChanged: Date = Date(), baseKey: String?, isBaseLimit: Bool, name: String) {
        Logger.shared.log("🔨 Creating TimeValue")
        Logger.shared.log("🔨 Initial value: \(value)")
        Logger.shared.log("🔨 Base key: \(baseKey ?? "nil")")
        Logger.shared.log("🔨 Is base limit: \(isBaseLimit)")
        Logger.shared.log("🔨 Name: \(name)")
        
        self.value = value
        self.lastChanged = lastChanged
        self.baseKey = baseKey
        self.isBaseLimit = isBaseLimit
        self.name = name
    }
    
    // MARK: - Persistence
    
    @MainActor
    func saveToDefaults() {
        guard let key = baseKey else { return }
        let data = TimeValueData(value: value, lastUpdated: Date())
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
            Logger.shared.log("💾 Saving value: \(value) with key: \(key)")
            Logger.shared.log("💾 Save successful")
        }
    }
    
    static func loadFromDefaults(key: String) -> TimeValue? {
        Logger.shared.log("📖 Attempting to load TimeValue with key: \(key)")
        
        if let data = UserDefaults.standard.data(forKey: key),
           let savedData = try? JSONDecoder().decode(TimeValueData.self, from: data) {
            Logger.shared.log("📖 Successfully loaded value: \(savedData.value)")
            
            if let kind = TimeValueKind.allCases.first(where: { $0.config.baseKey == key }) {
                let config = kind.config
                return TimeValue(value: savedData.value,
                               lastChanged: savedData.lastUpdated,
                               baseKey: config.baseKey,
                               isBaseLimit: config.isBaseLimit,
                               name: config.name)
            }
        }
        
        Logger.shared.log("⚠️ No saved value found for key: \(key)")
        return nil
    }
    
    // MARK: - Value Updates
    
    @MainActor
    func update(value: TimeInterval) {
        self.value = value
        self.lastChanged = Date()
        saveToDefaults()
        
        // Notify HomeAssistant if not updating from MQTT
        if !updatingFromMQTT {
            HomeAssistantClient.shared.publish_to_HA(self)
        }
    }
    
    @MainActor
    func updateFromMQTT(value: TimeInterval) {
        updatingFromMQTT = true
        update(value: value)
        updatingFromMQTT = false
    }
    
    // MARK: - MQTT Support
    
    var mqttTopic: String { baseKey ?? "" }
    var stateTopic: String { "minertimer/\(mqttTopic)/state" }
    var setTopic: String { "minertimer/\(mqttTopic)/set" }
    var configTopic: String { "homeassistant/number/minertimer_mac/\(mqttTopic)/config" }
    
    // MARK: - Equatable
    
    public static func == (lhs: TimeValue, rhs: TimeValue) -> Bool {
        lhs.value == rhs.value && 
        lhs.lastChanged == rhs.lastChanged && 
        lhs.baseKey == rhs.baseKey
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case value, lastChanged, baseKey, isBaseLimit, name
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(lastChanged, forKey: .lastChanged)
        try container.encode(baseKey, forKey: .baseKey)
        try container.encode(isBaseLimit, forKey: .isBaseLimit)
        try container.encode(name, forKey: .name)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(TimeInterval.self, forKey: .value)
        lastChanged = try container.decode(Date.self, forKey: .lastChanged)
        baseKey = try container.decode(String?.self, forKey: .baseKey)
        isBaseLimit = try container.decode(Bool.self, forKey: .isBaseLimit)
        name = try container.decode(String.self, forKey: .name)
    }
} 