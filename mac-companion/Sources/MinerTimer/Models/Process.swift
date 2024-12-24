import Foundation

enum GameProcessState: String {
    case running = "running"
    case suspended = "suspended"
}

struct GameProcess {
    let pid: Int32
    let name: String
    var state: GameProcessState
    let startTime: Date
} 