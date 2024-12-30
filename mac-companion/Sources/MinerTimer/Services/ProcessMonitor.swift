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
    @Published private(set) var playedTime: TimeValue
    @Published public var timeLimit: (current: TimeLimits, weekday: TimeLimits, weekend: TimeLimits)
    @Published private(set) var timeScheduler: TimeScheduler
    

    private var lastCheck = Date()
    
    init() {
        self.playedTime = TimeValue.create(kind: .played)
        let (current, weekday, weekend) = TimeLimits.create()
        self.timeLimit = (current, weekday, weekend)
        self.timeScheduler = TimeScheduler.shared
    }
    
    func updatePlayedTime(playedTime: TimeValue) {
        // Update played time
        let now = Date()
        if let process = monitoredProcess, process.state == .running {
            let elapsed = now.timeIntervalSince(lastCheck)
            playedTime.value += elapsed
            
            // Update Home Assistant

        }
        lastCheck = now
 
        // Check if we need to suspend
        checkLimits()
    }
    
    private func checkLimits() {
        if let process = monitoredProcess {
            if case .current(let currentValue) = timeLimit.current,
               playedTime.value >= currentValue.value && process.state == .running {
                Logger.shared.log("Time limit reached (\(Int(playedTime.value)) >= \(Int(currentValue.value)))")
                suspendProcess(process.pid)
                NotificationManager.shared.playTimeUpSound()
            }
        }
    }
    
    public func addTime(_ minutes: TimeInterval) {
        if case .current(let currentValue) = timeLimit.current {
            Logger.shared.log("Adding \(minutes) minutes to current limit (\(currentValue.value))")
            currentValue.update(value: currentValue.value + minutes)
        }
    }
    
    public func resetTime() {
        Logger.shared.log("Resetting played time to 0")
        playedTime.update(value: 0)
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
    
    private func checkProcesses() {
        Logger.shared.log("ProcessMonitor: Checking processes...")
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-l", "java"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                Logger.shared.log("ProcessMonitor: Found processes: \(output)")
                if !output.isEmpty {
                    let lines = output.components(separatedBy: .newlines)
                    if let firstLine = lines.first,
                       let pid = Int32(firstLine.components(separatedBy: " ")[0]) {
                        
                        // Keep existing state if it's the same process
                        if let existing = monitoredProcess, existing.pid == pid {
                            Logger.shared.log("ProcessMonitor: Found existing process (PID: \(pid), State: \(existing.state.rawValue))")
                        } else {
                            // Only create new process if it's a different one
                            let process = MonitoredProcess(
                                pid: pid,
                                name: "Minecraft",
                                startTime: Date(),
                                state: .running
                            )
                            monitoredProcess = process
                            Logger.shared.log("ProcessMonitor: Found new Minecraft process (PID: \(pid))")
                        }
                    }
                } else {
                    monitoredProcess = nil
                    Logger.shared.log("ProcessMonitor: No Java processes found")
                }
            }
        } catch {
            Logger.shared.log("ProcessMonitor: Error checking processes: \(error)")
        }
    }
    
    func suspendProcess(_ pid: Int32) {
        kill(pid, SIGSTOP)
        
        // Update process state
        if let process = monitoredProcess {
            monitoredProcess = MonitoredProcess(
                pid: process.pid,
                name: process.name,
                startTime: process.startTime,
                state: .suspended
            )
        }
    }
    
    func resumeProcess(_ pid: Int32) {
        kill(pid, SIGCONT)
        
        // Update process state
        if let process = monitoredProcess {
            monitoredProcess = MonitoredProcess(
                pid: process.pid,
                name: process.name,
                startTime: process.startTime,
                state: .running
            )
        }
    }
} 