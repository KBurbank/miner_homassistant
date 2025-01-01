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

// MARK: - TimeValue Factory Methods

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