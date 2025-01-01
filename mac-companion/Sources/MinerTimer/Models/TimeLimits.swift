import Foundation

/// Represents different types of time limits in the application
public enum TimeLimits {
    /// The current active time limit
    case current(TimeValue)
    /// The base time limit for weekdays
    case weekday(TimeValue)
    /// The base time limit for weekends
    case weekend(TimeValue)
    
    /// Creates a tuple of all three time limit types
    @MainActor
    static func create() -> (TimeLimits, TimeLimits, TimeLimits) {
        let (current, weekday, weekend) = TimeValue.createTimeLimits()
        return (.current(current), .weekday(weekday), .weekend(weekend))
    }
    
    /// Gets the underlying TimeValue
    var timeValue: TimeValue {
        switch self {
        case .current(let value),
             .weekday(let value),
             .weekend(let value):
            return value
        }
    }
    
    /// Updates the time value
    @MainActor
    func update(value: TimeInterval) {
        timeValue.update(value: value)
    }
} 