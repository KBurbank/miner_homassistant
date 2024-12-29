import Foundation

@MainActor
class TimeScheduler: ObservableObject {
    private var timer: Timer?
    private weak var processMonitor: ProcessMonitor?
    @Published var playedTime: TimeValue
    @Published var currentLimit: TimeValue
    @Published var weekdayLimit: TimeValue
    @Published var weekendLimit: TimeValue
    private var lastCheck: Date
    
    static let shared = TimeScheduler()
    
    private init() {
        self.playedTime = TimeValue.create(kind: .played)
        self.lastCheck = Date()
        (self.currentLimit, self.weekdayLimit, self.weekendLimit) = TimeValue.createTimeLimits()
        startTimer()
    }
    
    func setProcessMonitor(_ monitor: ProcessMonitor) {
        self.processMonitor = monitor
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.updatePlayedTime()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }

    @MainActor
    private func updatePlayedTime() {
        let elapsed = Date().timeIntervalSince(lastCheck)
        playedTime.update(value: playedTime.value + (elapsed / 60))
        lastCheck = Date()
    }
    
    func addTime(_ minutes: TimeInterval) {
        Logger.shared.log("Adding \(minutes) minutes to current limit (\(currentLimit.value))")
        currentLimit.update(value: currentLimit.value + minutes)
    }
} 