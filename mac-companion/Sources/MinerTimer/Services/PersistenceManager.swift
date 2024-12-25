import Foundation

struct TimeState: Codable {
    var playedTime: TimeInterval
    var lastUpdated: Date
}

class PersistenceManager {
    static let shared = PersistenceManager()
    private let fileURL: URL
    
    private init() {
        let sharedDir = URL(fileURLWithPath: "/Users/Shared/minertimer")
        fileURL = sharedDir.appendingPathComponent("timestate.json")
    }
    
    func saveTimeState(playedTime: TimeInterval) {
        let state = TimeState(playedTime: playedTime, lastUpdated: Date())
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL)
            Logger.shared.log("Saved time state: \(playedTime) minutes")
        } catch {
            Logger.shared.log("Error saving time state: \(error)")
        }
    }
    
    func loadTimeState() -> TimeState? {
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try JSONDecoder().decode(TimeState.self, from: data)
            
            // If it's a new day, reset the time
            if !Calendar.current.isDateInToday(state.lastUpdated) {
                Logger.shared.log("New day detected, resetting played time")
                return TimeState(playedTime: 0, lastUpdated: Date())
            }
            
            Logger.shared.log("Loaded time state: \(state.playedTime) minutes")
            return state
        } catch {
            Logger.shared.log("Error loading time state (or no state exists yet)")
            return nil
        }
    }
} 