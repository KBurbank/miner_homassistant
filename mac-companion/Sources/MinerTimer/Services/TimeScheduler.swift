import Foundation

@MainActor
class TimeScheduler: ObservableObject {
    private var timer: Timer?
    private var processMonitor: ProcessMonitor?
    @Published var playedTime: TimeValue
    @Published var currentLimit: TimeValue
    @Published var weekdayLimit: TimeValue
    @Published var weekendLimit: TimeValue
    private var lastCheck: Date
    
    static let shared = TimeScheduler()
    
    init() {
        Logger.shared.log("⏰ TimeScheduler initializing...")
        self.playedTime = TimeValue.create(kind: .played)
        self.lastCheck = Date()
        (self.currentLimit, self.weekdayLimit, self.weekendLimit) = TimeValue.createTimeLimits()
        
        // Check if last close was before midnight
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        let defaults = UserDefaults.standard
        let lastCloseTime = defaults.double(forKey: "last_close_time")
        if lastCloseTime > 0 {
            let lastCloseDate = Date(timeIntervalSince1970: lastCloseTime)
            
            // Get today's midnight in local time
            let midnightLocal = calendar.startOfDay(for: Date())
            
            // Get the timezone offset
            let offset = TimeZone.current.secondsFromGMT()
            
            // Convert last close time to local
            let lastCloseLocal = lastCloseDate.addingTimeInterval(TimeInterval(offset))
            
            Logger.shared.log("🕒 Last close date (local): \(lastCloseLocal)")
            Logger.shared.log("🕒 Midnight (local): \(midnightLocal)")
            
            if lastCloseLocal < midnightLocal {
                Logger.shared.log("🔄 Last close was before midnight (local time), resetting played time")
                playedTime.update(value: 0)
            } else {
                Logger.shared.log("🔄 Last close was after midnight, keeping played time")
            }
        }
        
        Logger.shared.log("⏰ TimeScheduler initialized")
    }
    
    func setProcessMonitor(_ monitor: ProcessMonitor) {
        Logger.shared.log("🔄 Setting ProcessMonitor in TimeScheduler")
        self.processMonitor = monitor
        startTimer()
    }
    
    private func startTimer() {
        Logger.shared.log("⏰ Starting timer...")
        timer?.invalidate()
        
        // Create a weak reference to self to avoid retain cycles
        weak var weakSelf = self
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard let self = weakSelf else { return }
                
                // Only need to check processMonitor since playedTime is non-optional
                if let monitor = self.processMonitor {
                    await monitor.updatePlayedTime(playedTime: self.playedTime)
                    let running = monitor.monitoredProcess?.state == .running
                    if Int(self.playedTime.value) >= Int(self.currentLimit.value) && running {
                        Logger.shared.log("🔄 Time limit reached (\(Int(self.playedTime.value)) >= \(Int(self.currentLimit.value)))")
                        monitor.suspendProcess()
                    } else if Int(self.playedTime.value) < Int(self.currentLimit.value) && !running  {
                        Logger.shared.log("🔄 You now have more time (\(Int(self.playedTime.value)) < \(Int(self.currentLimit.value)))")
                        monitor.resumeProcess()
                    } else {
                        Logger.shared.log("🔄 No time limit reached (\(Int(self.playedTime.value)) < \(Int(self.currentLimit.value)))")
                    }
                }
            }
        }
        
        RunLoop.main.add(timer!, forMode: .common)
        Logger.shared.log("⏰ Timer started")
    }
    
    deinit {
        timer?.invalidate()
    }

    @MainActor
    private func updatePlayedTime() {
        // Check if we've crossed midnight since last update
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let midnight = calendar.startOfDay(for: Date())
        
        if lastCheck < midnight {
            Logger.shared.log("🔄 Crossed midnight, resetting played time")
            playedTime.update(value: 0)
            lastCheck = Date()
            return
        }
        
        let elapsed = Date().timeIntervalSince(lastCheck)
        playedTime.update(value: playedTime.value + (elapsed / 60))
        lastCheck = Date()
    }

    func addTime(_ minutes: TimeInterval) {
        Logger.shared.log("Adding \(minutes) minutes to current limit (\(currentLimit.value))")
        currentLimit.update(value: currentLimit.value + minutes)
    }
} 

