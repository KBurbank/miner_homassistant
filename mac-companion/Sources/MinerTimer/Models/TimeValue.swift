import Foundation
import AppKit

private struct TimeValueData: Codable {
    let value: TimeInterval
    let lastUpdated: Date
}

public class TimeValue: ObservableObject {
    @Published private(set) var value: TimeInterval
    private let kind: TimeValueKind
    private var updatingFromMQTT = false
    
    var mqttTopic: String {
        kind.config.baseKey
    }
    
    var stateTopic: String {
        "minertimer/\(mqttTopic)/state"
    }
    
    var setTopic: String {
        "minertimer/\(mqttTopic)/set"
    }
    
    init(kind: TimeValueKind, value: TimeInterval = 0) {
        self.kind = kind
        self.value = value
        
        // Load saved value if available
        if let savedValue = UserDefaults.standard.object(forKey: kind.config.baseKey) as? Double {
            self.value = savedValue
        }
    }
    
    @MainActor
    func update(value: TimeInterval) {
        self.value = value
        
        // Save to UserDefaults
        UserDefaults.standard.set(value, forKey: kind.config.baseKey)
        Logger.shared.log("💾 Saving value: \(value) with key: \(kind.config.baseKey)")
        Logger.shared.log("💾 Save successful")
        
        // Notify HomeAssistant if not updating from MQTT
        if !updatingFromMQTT {
            if let appDelegate = NSApp.delegate as? AppDelegate,
               let haClient = appDelegate.haClient {
                haClient.publish_to_HA(self)
            }
        }
    }
    
    @MainActor
    func updateFromMQTT(value: TimeInterval) {
        updatingFromMQTT = true
        update(value: value)
        updatingFromMQTT = false
    }
    
    static func create(kind: TimeValueKind) -> TimeValue {
        return TimeValue(kind: kind)
    }
    
    static func createTimeLimits() -> (current: TimeValue, weekday: TimeValue, weekend: TimeValue) {
        let weekday = TimeValue(kind: .weekday, value: 120)  // 2 hours default
        let weekend = TimeValue(kind: .weekend, value: 180)  // 3 hours default
        
        // Set current limit based on day type
        let baseValue = Calendar.current.isDateInWeekend(Date()) ? weekend.value : weekday.value
        let current = TimeValue(kind: .current, value: baseValue)
        
        return (current, weekday, weekend)
    }
} 