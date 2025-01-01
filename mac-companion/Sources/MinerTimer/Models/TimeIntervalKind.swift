import Foundation

private extension Calendar {
    func isWeekend(_ date: Date) -> Bool {
        let weekday = component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
}

public enum TimeValueKind: CaseIterable {
    case current
    case weekday
    case weekend
    case played
    case timeRequest
    
    var config: TimeValueConfig {
        switch self {
        case .current:
            return TimeValueConfig(baseKey: "current_limit", isBaseLimit: false, name: "Current Limit")
        case .weekday:
            return TimeValueConfig(baseKey: "weekday_limit", isBaseLimit: true, name: "Weekday Limit")
        case .weekend:
            return TimeValueConfig(baseKey: "weekend_limit", isBaseLimit: true, name: "Weekend Limit")
        case .played:
            return TimeValueConfig(baseKey: "played_time", isBaseLimit: false, name: "Played Time")
        case .timeRequest:
            return TimeValueConfig(baseKey: "time_request", isBaseLimit: false, name: "Time Request")
        }
    }
    
    static func create(_ kind: TimeValueKind, value: TimeInterval = 0) -> TimeValue {
        // Try to load saved value first
        if let savedValue = UserDefaults.standard.object(forKey: kind.config.baseKey) as? Double {
            return TimeValue(kind: kind, value: savedValue)
        }
        
        // Create new with default value if no saved value exists
        return TimeValue(kind: kind, value: value)
    }
}

struct TimeValueConfig {
    let baseKey: String
    let isBaseLimit: Bool
    let name: String
} 