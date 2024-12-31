import Foundation


// This is the class that monitors the process (e.g. Minecraft)

@MainActor
public class ProcessMonitor: ObservableObject {
    public struct MonitoredProcess {
        let pid: pid_t
        let name: String
        let startTime: Date
        let state: ProcessState
        
        public enum ProcessState: String {
            case running
            case suspended
        }
    }
    
    @Published private(set) var monitoredProcess: MonitoredProcess?
    @Published public var timeLimit: (current: TimeLimits, weekday: TimeLimits, weekend: TimeLimits)
    private var lastCheck = Date()
    private var currentPlayedTime: TimeValue?
    private var lastMQTTUpdate: Date = Date()
    private let mqttUpdateInterval: TimeInterval = 60  // 1 minute
    
    init() {
        Logger.shared.log("🔨 Creating ProcessMonitor")
        let (current, weekday, weekend) = TimeLimits.create()
        self.timeLimit = (current, weekday, weekend)
        Logger.shared.log("🔨 ProcessMonitor created")
    }
    
    @MainActor
    func updatePlayedTime(playedTime: TimeValue) async {
        Logger.shared.log("⏱️ ProcessMonitor.updatePlayedTime called")
        self.currentPlayedTime = playedTime
        
        // Check for Java process
        checkProcesses()
        
        // Only update time if process is running
        if let process = monitoredProcess, process.state == .running {
            let elapsed = Date().timeIntervalSince(lastCheck)
            playedTime.update(value: playedTime.value + (elapsed / 60))
            
            // Only update MQTT if enough time has passed
            let now = Date()
            if now.timeIntervalSince(lastMQTTUpdate) >= mqttUpdateInterval {
                lastMQTTUpdate = now
                HomeAssistantClient.shared.publish_to_HA(playedTime)
            }
        }
        
        lastCheck = Date()
    }
    
    
    public func addTime(_ minutes: TimeInterval) {
        if case .current(let currentValue) = timeLimit.current {
            Logger.shared.log("Adding \(minutes) minutes to current limit (\(currentValue.value))")
            currentValue.update(value: currentValue.value + minutes)
        }
    }
    
    public func resetTime() {
        Logger.shared.log("Resetting played time to 0")
        currentPlayedTime?.update(value: 0)
    }
    
    public func simulateMidnight() {
        Logger.shared.log("Simulating midnight reset")
        resetForNewDay()
    }
    
    public func resetForNewDay() {
        Logger.shared.log("Resetting limits for new day")
        
        // Get base value from current day type
        let baseValue = if case .weekday(let value) = timeLimit.weekday {
            value.value
        } else if case .weekend(let value) = timeLimit.weekend {
            value.value
        } else {
            60.0 // Default value
        }
        
        if case .current(let currentValue) = timeLimit.current {
            Logger.shared.log("Updating current limit to: \(baseValue)")
            currentValue.update(value: baseValue)
        }
    }
    
    public func requestMoreTime() {
        Logger.shared.log("Requesting more time")
        if case .current(let currentValue) = timeLimit.current {
            currentValue.update(value: currentValue.value + 30)
        }
    }
    
    internal func checkProcesses() {
        Logger.shared.log("🔍 ProcessMonitor: Starting process check...")
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-l", "java"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                Logger.shared.log("🔍 pgrep output: '\(output)'")
                if !output.isEmpty {
                    let lines = output.components(separatedBy: .newlines)
                    Logger.shared.log("🔍 Found \(lines.count) lines")
                    if let firstLine = lines.first {
                        Logger.shared.log("🔍 First line: '\(firstLine)'")
                        let components = firstLine.components(separatedBy: " ")
                        Logger.shared.log("🔍 Line components: \(components)")
                        if let pid = Int32(components[0]) {
                            // Keep existing state if it's the same process
                            if let existing = monitoredProcess, existing.pid == pid {
                                Logger.shared.log("✅ Found existing Java process (PID: \(pid), State: \(existing.state.rawValue))")
                            } else {
                                let process = MonitoredProcess(
                                    pid: pid,
                                    name: "Minecraft",
                                    startTime: Date(),
                                    state: .running
                                )
                                monitoredProcess = process
                                Logger.shared.log("✅ Found new Java process (PID: \(pid))")
                            }
                        } else {
                            Logger.shared.log("⚠️ Could not parse PID from line: '\(firstLine)'")
                        }
                    }
                } else {
                    monitoredProcess = nil
                    Logger.shared.log("❌ No Java processes found")
                }
            }
        } catch {
            Logger.shared.log("❌ Error checking processes: \(error)")
        }
    }
    
    func suspendProcess() {
        guard var process = monitoredProcess else {
            Logger.shared.log("❌ No process to suspend")
            return
        }
        
        Logger.shared.log("🛑 Suspending process \(process.pid)")
        kill(process.pid, SIGSTOP)
        
        // Create new MonitoredProcess with suspended state
        monitoredProcess = MonitoredProcess(
            pid: process.pid,
            name: process.name,
            startTime: process.startTime,
            state: .suspended
        )
        Logger.shared.log("✅ Process suspended")
    }
    
    func resumeProcess() {
        guard var process = monitoredProcess else {
            Logger.shared.log("❌ No process to resume")
            return
        }
        
        Logger.shared.log("▶️ Resuming process \(process.pid)")
        kill(process.pid, SIGCONT)
        
        // Create new MonitoredProcess with running state
        monitoredProcess = MonitoredProcess(
            pid: process.pid,
            name: process.name,
            startTime: process.startTime,
            state: .running
        )
        Logger.shared.log("✅ Process resumed")
    }
} 