import Foundation

private extension Calendar {
    func isWeekend(_ date: Date) -> Bool {
        let weekday = component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
}

private struct TimeValueData: Codable {
    let value: TimeInterval
    let lastUpdated: Date
}

@available(macOS 10.15, *)
public class TimeValue: Codable, Equatable, @unchecked Sendable, ObservableObject {
    @Published public internal(set) var value: TimeInterval
    var lastChanged: Date
    let baseKey: String?
    let isBaseLimit: Bool
    let name: String
    
    private var updatingFromMQTT = false
    private var lastMQTTUpdate: Date = Date()
    private let mqttUpdateInterval: TimeInterval = 60  // 1 minute
    
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
    
    // MQTT topics derived from baseKey
    var mqttTopic: String { baseKey ?? "" }
    private var topicPrefix: String { "minertimer/\(mqttTopic)" }
    
    var stateTopic: String { "\(topicPrefix)/state" }
    var setTopic: String { "\(topicPrefix)/set" }
    var configTopic: String { "homeassistant/number/minertimer_mac/\(mqttTopic)/config" }
    
    var userDefaultsKey: String? { baseKey }
    
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
        
        // Try to load TimeValueData first
        if let data = UserDefaults.standard.data(forKey: key),
           let savedData = try? JSONDecoder().decode(TimeValueData.self, from: data) {
            Logger.shared.log("📖 Successfully loaded value: \(savedData.value)")
            
            // Create TimeValue with the loaded value
            let kind = TimeValueKind.allCases.first { $0.config.baseKey == key }
            if let kind = kind {
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
    
    public static func == (lhs: TimeValue, rhs: TimeValue) -> Bool {
        lhs.value == rhs.value && 
        lhs.lastChanged == rhs.lastChanged && 
        lhs.baseKey == rhs.baseKey
    }
    
    // Add CodingKeys and coding methods
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
    
    @MainActor
    func update(value: TimeInterval) {
        self.value = value
        self.lastChanged = Date()
        saveToDefaults()
        
        // Only publish to MQTT if enough time has passed and we're not updating from MQTT
        if !updatingFromMQTT {
            let now = Date()
            if now.timeIntervalSince(lastMQTTUpdate) >= mqttUpdateInterval {
                lastMQTTUpdate = now
                HomeAssistantClient.shared.publish_to_HA(self)
            }
        }
    }
    
    @MainActor
    func updateFromMQTT(value: TimeInterval) {
        updatingFromMQTT = true
    //    Logger.shared.log("📝 Updating TimeValue from MQTT")
    //    Logger.shared.log("📝 Old value: \(self.value)")
    //    Logger.shared.log("📝 New value: \(value)")
        update(value: value)
        updatingFromMQTT = false
    }
    
    private func loadSavedValue() -> TimeInterval {
        Logger.shared.log("🔨 Attempting to load saved value")
        if let data = UserDefaults.standard.data(forKey: baseKey ?? ""),
           let savedValue = try? JSONDecoder().decode(TimeValueData.self, from: data) {
            
            // For played_time, check if we crossed midnight
            if baseKey == "played_time" {
                var calendar = Calendar.current
                calendar.timeZone = TimeZone.current
                let midnight = calendar.startOfDay(for: Date())
                
                if savedValue.lastUpdated < midnight {
                    Logger.shared.log("🔄 Saved played_time is from before midnight, resetting to 0")
                    return 0
                }
            }
            
            Logger.shared.log("🔨 Found saved value: \(savedValue.value) from \(savedValue.lastUpdated)")
            return savedValue.value
        }
        
        Logger.shared.log("🔨 No saved value found")
        return 0
    }
}

public enum TimeValueKind: CaseIterable {
    case current
    case weekday
    case weekend
    case played
    case timeRequest
    
    var config: (baseKey: String, isBaseLimit: Bool, name: String) {
        switch self {
            case .current:     return ("time_limit", false, "Current Limit")
            case .weekday:     return ("weekday_limit", true, "Weekday Limit")
            case .weekend:     return ("weekend_limit", true, "Weekend Limit")
            case .played:      return ("played_time", false, "Time Played")
            case .timeRequest: return ("time_request", false, "Time Request")
        }
    }
}

extension TimeValue {
    static func create(kind: TimeValueKind, value: TimeInterval = 0) -> TimeValue {
        let config = kind.config
        
        // Try to load saved value first
        if let savedValue = loadFromDefaults(key: config.baseKey) {
            return savedValue
        }
        
        // Create new with default value if no saved value exists
        return TimeValue(value: value, 
                        baseKey: config.baseKey, 
                        isBaseLimit: config.isBaseLimit, 
                        name: config.name)
    }
}

extension TimeValue {
    @MainActor
    static func createTimeLimits() -> (current: TimeValue, weekday: TimeValue, weekend: TimeValue) {
        let weekday = TimeValue.create(kind: .weekday)
        let weekend = TimeValue.create(kind: .weekend)
        let current = TimeValue.create(kind: .current)
        
        // Check if we need to reset current limit
        let defaults = UserDefaults.standard
        let lastCloseTime = defaults.double(forKey: "last_close_time")
        
        if lastCloseTime > 0 {
            let lastClose = Date(timeIntervalSince1970: lastCloseTime)
            // Get midnight of today in local time zone
            var calendar = Calendar.current
            calendar.timeZone = TimeZone.current
            let midnight = calendar.startOfDay(for: Date())
            
            // Only update current limit if last close was before midnight
            if lastClose < midnight {
                Logger.shared.log("🔄 Last close was before midnight (local time), updating current limit")
                let baseValue = calendar.isWeekend(Date()) ? weekend.value : weekday.value
                current.update(value: baseValue)
            } else {
                Logger.shared.log("✋ Last close was today (after local midnight), keeping current limit")
            }
        } else {
            Logger.shared.log("🆕 No last close time found, setting initial current limit")
            let baseValue = Calendar.current.isWeekend(Date()) ? weekend.value : weekday.value
            current.update(value: baseValue)
        }
        
        return (current, weekday, weekend)
    }
}

@available(macOS 10.15, *)
public enum TimeLimits {
    case current(TimeValue)
    case weekday(TimeValue)
    case weekend(TimeValue)

    
    @MainActor
    static func create() -> (TimeLimits, TimeLimits, TimeLimits) {
        let (current, weekday, weekend) = TimeValue.createTimeLimits()
        return (.current(current), .weekday(weekday), .weekend(weekend))
    }
}



// Add these helper methods to UserDefaults
extension UserDefaults {
    func setCodable<T: Encodable>(_ value: T, forKey key: String) throws {
        set(try JSONEncoder().encode(value), forKey: key)
    }
    
    func getCodable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
} 