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
    private var lastMQTTUpdate: Date = Date()
    private let mqttUpdateInterval: TimeInterval = 60  // 1 minute
    private var haClient: HomeAssistantClient?
    
    init(processMonitor: ProcessMonitor? = nil, haClient: HomeAssistantClient? = nil) {
        Logger.shared.log("⏰ TimeScheduler initializing...")
        self.processMonitor = processMonitor
        self.haClient = haClient
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
        
        if processMonitor != nil {
            startTimer()
        }
    }
    
    func setProcessMonitor(_ monitor: ProcessMonitor) {
        Logger.shared.log("🔄 Setting ProcessMonitor in TimeScheduler")
        self.processMonitor = monitor
        startTimer()
    }
    
    func setHomeAssistantClient(_ client: HomeAssistantClient) {
        self.haClient = client
    }
    
    private func startTimer() {
        Logger.shared.log("⏰ Starting timer...")
        timer?.invalidate()
        
        // Create a weak reference to self to avoid retain cycles
        weak var weakSelf = self
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard let self = weakSelf else { return }
                
                // Check and update process state
                if let monitor = self.processMonitor {
                    await monitor.checkAndUpdateProcess()
                    
                    // Update time if process is running
                    if let process = monitor.monitoredProcess, process.state == .running {
                        self.updatePlayedTime()
                        
                        // Update MQTT if needed
                        let now = Date()
                        if now.timeIntervalSince(self.lastMQTTUpdate) >= self.mqttUpdateInterval {
                            self.lastMQTTUpdate = now
                            if let haClient = self.haClient {
                                haClient.publish_to_HA(self.playedTime)
                            }
                        }
                        
                        // Check time limits
                        if Int(self.playedTime.value) >= Int(self.currentLimit.value) {
                            Logger.shared.log("🔄 Time limit reached (\(Int(self.playedTime.value)) >= \(Int(self.currentLimit.value)))")
                            monitor.suspendProcess()
                        }
                    } else if let process = monitor.monitoredProcess, process.state == .suspended {
                        // Check if we can resume
                        if Int(self.playedTime.value) < Int(self.currentLimit.value) {
                            Logger.shared.log("🔄 You now have more time (\(Int(self.playedTime.value)) < \(Int(self.currentLimit.value)))")
                            monitor.resumeProcess()
                        }
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
            resetForNewDay()
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
    
    func resetTime() {
        Logger.shared.log("Resetting played time to 0")
        playedTime.update(value: 0)
    }
    
    func simulateMidnight() {
        Logger.shared.log("Simulating midnight reset")
        resetForNewDay()
    }
    
    private func resetForNewDay() {
        Logger.shared.log("Resetting limits for new day")
        
        // Get base value from current day type
        let baseValue = if Calendar.current.isDateInWeekend(Date()) {
            weekendLimit.value
        } else {
            weekdayLimit.value
        }
        
        Logger.shared.log("Updating current limit to: \(baseValue)")
        currentLimit.update(value: baseValue)
    }
    
    func requestMoreTime() {
        Logger.shared.log("Requesting more time")
        currentLimit.update(value: currentLimit.value + 30)
    }
} 

